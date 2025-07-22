/// Unit tests for SimpleTunnelClient
///
/// Tests connection, reconnection, request handling, and error scenarios
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:cloudtolocalllm/services/simple_tunnel_client.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/services/tunnel_message_protocol.dart';
import 'package:cloudtolocalllm/utils/tunnel_logger.dart';
import '../test_config.dart';

// Generate mocks
@GenerateMocks([AuthService, WebSocketChannel, WebSocketSink, http.Client])
import 'simple_tunnel_client_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestConfig.initialize();

  group('SimpleTunnelClient', () {
    late SimpleTunnelClient tunnelClient;
    late MockAuthService mockAuthService;
    late MockWebSocketChannel mockWebSocket;
    late MockWebSocketSink mockWebSocketSink;
    late MockClient mockHttpClient;
    late StreamController<dynamic> webSocketStreamController;

    setUp(() {
      mockAuthService = MockAuthService();
      mockWebSocket = MockWebSocketChannel();
      mockWebSocketSink = MockWebSocketSink();
      mockHttpClient = MockClient();
      webSocketStreamController = StreamController<dynamic>.broadcast();

      // Setup auth service mock
      when(mockAuthService.getAccessToken()).thenReturn('test-token');
      when(mockAuthService.currentUser).thenReturn(null);

      // Setup WebSocket mocks
      when(mockWebSocket.sink).thenReturn(mockWebSocketSink);
      when(
        mockWebSocket.stream,
      ).thenAnswer((_) => webSocketStreamController.stream);
      when(mockWebSocket.closeCode).thenReturn(null);

      tunnelClient = SimpleTunnelClient(authService: mockAuthService);
    });

    tearDown(() {
      webSocketStreamController.close();
      tunnelClient.dispose();
    });

    group('Connection Management', () {
      test('should initialize with disconnected state', () {
        expect(tunnelClient.isConnected, false);
        expect(tunnelClient.isConnecting, false);
        expect(tunnelClient.lastError, null);
        expect(tunnelClient.reconnectAttempts, 0);
      });

      test('should connect successfully with valid token', () async {
        // Mock successful connection
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        // Start connection attempt
        final connectFuture = tunnelClient.connect();

        // Simulate connection establishment
        await Future.delayed(const Duration(milliseconds: 100));

        expect(tunnelClient.isConnecting, true);

        // Wait for connection to complete
        await connectFuture;

        expect(tunnelClient.isConnected, true);
        expect(tunnelClient.isConnecting, false);
        expect(tunnelClient.lastError, null);
        expect(tunnelClient.reconnectAttempts, 0);
      });

      test('should fail to connect without authentication token', () async {
        when(mockAuthService.getAccessToken()).thenReturn(null);

        expect(() => tunnelClient.connect(), throwsA(isA<TunnelException>()));

        expect(tunnelClient.isConnected, false);
        expect(tunnelClient.lastError, isNotNull);
      });

      test('should handle WebSocket connection failure', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        when(mockWebSocket.closeCode).thenReturn(1006); // Connection failed

        expect(() => tunnelClient.connect(), throwsA(isA<Exception>()));

        expect(tunnelClient.isConnected, false);
        expect(tunnelClient.lastError, isNotNull);
      });

      test('should disconnect cleanly', () async {
        // First connect
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        await tunnelClient.connect();

        expect(tunnelClient.isConnected, true);

        // Then disconnect
        await tunnelClient.disconnect();

        expect(tunnelClient.isConnected, false);
        expect(tunnelClient.isConnecting, false);
        verify(mockWebSocketSink.close()).called(1);
      });

      test('should not connect if already connecting', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        // Start first connection
        final connect1 = tunnelClient.connect();

        // Try to connect again while connecting
        final connect2 = tunnelClient.connect();

        await connect1;
        await connect2;

        // Should only attempt connection once
        expect(tunnelClient.isConnected, true);
      });

      test('should not connect if already connected', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        // Connect first time
        await tunnelClient.connect();
        expect(tunnelClient.isConnected, true);

        // Try to connect again
        await tunnelClient.connect();

        // Should remain connected without additional attempts
        expect(tunnelClient.isConnected, true);
      });
    });

    group('Reconnection Logic', () {
      test('should schedule reconnection after connection loss', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        // Connect first
        await tunnelClient.connect();
        expect(tunnelClient.isConnected, true);

        // Simulate connection loss
        webSocketStreamController.addError(
          const SocketException('Connection lost'),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(tunnelClient.isConnected, false);
        expect(tunnelClient.lastError, contains('Connection lost'));
      });

      test('should use exponential backoff for reconnection', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        // Simulate multiple failed connection attempts
        when(mockWebSocket.closeCode).thenReturn(1006);

        // First attempt
        try {
          await tunnelClient.connect();
        } catch (e) {
          // Expected to fail
        }

        expect(tunnelClient.reconnectAttempts, 0);

        // Simulate reconnection attempts
        for (int i = 0; i < 3; i++) {
          try {
            await tunnelClient.connect();
          } catch (e) {
            // Expected to fail
          }
        }

        // Should track reconnection attempts
        expect(tunnelClient.reconnectAttempts, greaterThan(0));
      });

      test(
        'should reset reconnection attempts after successful connection',
        () async {
          when(mockAuthService.getAccessToken()).thenReturn('valid-token');

          // Simulate failed connection
          when(mockWebSocket.closeCode).thenReturn(1006);
          try {
            await tunnelClient.connect();
          } catch (e) {
            // Expected to fail
          }

          // Now simulate successful connection
          when(mockWebSocket.closeCode).thenReturn(null);
          await tunnelClient.connect();

          expect(tunnelClient.isConnected, true);
          expect(tunnelClient.reconnectAttempts, 0);
        },
      );
    });

    group('Message Handling', () {
      setUp(() async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        await tunnelClient.connect();
      });

      test('should handle ping message and respond with pong', () async {
        final ping = PingMessage.create();
        final pingJson = TunnelMessageProtocol.serialize(ping);

        // Send ping message
        webSocketStreamController.add(pingJson);

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify pong was sent
        verify(mockWebSocketSink.add(any)).called(greaterThan(0));
      });

      test('should handle pong message', () async {
        final pong = PongMessage(
          id: 'test-ping',
          timestamp: DateTime.now().toIso8601String(),
        );
        final pongJson = TunnelMessageProtocol.serialize(pong);

        // Send pong message
        webSocketStreamController.add(pongJson);

        await Future.delayed(const Duration(milliseconds: 50));

        // Should not throw error
        expect(tunnelClient.isConnected, true);
      });

      test('should handle error message', () async {
        final error = ErrorMessage(
          id: 'test-error',
          error: 'Test error message',
          code: 500,
        );
        final errorJson = TunnelMessageProtocol.serialize(error);

        // Send error message
        webSocketStreamController.add(errorJson);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(tunnelClient.lastError, 'Test error message');
      });

      test('should handle invalid JSON message gracefully', () async {
        // Send invalid JSON
        webSocketStreamController.add('invalid json');

        await Future.delayed(const Duration(milliseconds: 50));

        // Should not crash, connection should remain active
        expect(tunnelClient.isConnected, true);
      });

      test('should handle empty message gracefully', () async {
        // Send empty message
        webSocketStreamController.add('');

        await Future.delayed(const Duration(milliseconds: 50));

        // Should not crash, connection should remain active
        expect(tunnelClient.isConnected, true);
      });

      test('should handle unknown message type gracefully', () async {
        final unknownMessage = {'type': 'unknown_type', 'id': 'test-123'};

        webSocketStreamController.add(jsonEncode(unknownMessage));

        await Future.delayed(const Duration(milliseconds: 50));

        // Should not crash, connection should remain active
        expect(tunnelClient.isConnected, true);
      });
    });

    group('HTTP Request Forwarding', () {
      setUp(() async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        await tunnelClient.connect();
      });

      test('should forward GET request to local Ollama', () async {
        // Mock HTTP client response
        final mockResponse = http.Response(
          jsonEncode({'models': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
        when(
          mockHttpClient.get(any, headers: anyNamed('headers')),
        ).thenAnswer((_) async => mockResponse);

        // Create HTTP request message
        final request = TunnelRequestMessage(
          id: 'test-request',
          method: 'GET',
          path: '/api/models',
          headers: {'accept': 'application/json'},
        );

        // Send request message
        final requestJson = TunnelMessageProtocol.serialize(request);
        webSocketStreamController.add(requestJson);

        await Future.delayed(const Duration(milliseconds: 100));

        // Verify response was sent back
        verify(mockWebSocketSink.add(any)).called(greaterThan(0));
      });

      test('should forward POST request with body to local Ollama', () async {
        // Mock HTTP client response
        final mockResponse = http.Response(
          jsonEncode({'response': 'Hello!'}),
          200,
          headers: {'content-type': 'application/json'},
        );
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Create HTTP request message with body
        final request = TunnelRequestMessage(
          id: 'test-request',
          method: 'POST',
          path: '/api/chat',
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'model': 'llama2', 'prompt': 'Hello'}),
        );

        // Send request message
        final requestJson = TunnelMessageProtocol.serialize(request);
        webSocketStreamController.add(requestJson);

        await Future.delayed(const Duration(milliseconds: 100));

        // Verify response was sent back
        verify(mockWebSocketSink.add(any)).called(greaterThan(0));
      });

      test('should handle Ollama connection timeout', () async {
        // Mock timeout exception
        when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenThrow(
          TimeoutException('Request timeout', const Duration(seconds: 30)),
        );

        // Create HTTP request message
        final request = TunnelRequestMessage(
          id: 'test-request',
          method: 'GET',
          path: '/api/models',
          headers: {'accept': 'application/json'},
        );

        // Send request message
        final requestJson = TunnelMessageProtocol.serialize(request);
        webSocketStreamController.add(requestJson);

        await Future.delayed(const Duration(milliseconds: 100));

        // Verify error response was sent back
        verify(mockWebSocketSink.add(any)).called(greaterThan(0));
      });

      test('should handle Ollama connection failure', () async {
        // Mock socket exception
        when(
          mockHttpClient.get(any, headers: anyNamed('headers')),
        ).thenThrow(const SocketException('Connection refused'));

        // Create HTTP request message
        final request = TunnelRequestMessage(
          id: 'test-request',
          method: 'GET',
          path: '/api/models',
          headers: {'accept': 'application/json'},
        );

        // Send request message
        final requestJson = TunnelMessageProtocol.serialize(request);
        webSocketStreamController.add(requestJson);

        await Future.delayed(const Duration(milliseconds: 100));

        // Verify error response was sent back
        verify(mockWebSocketSink.add(any)).called(greaterThan(0));
      });

      test('should handle unsupported HTTP method', () async {
        // Create HTTP request with unsupported method
        final request = TunnelRequestMessage(
          id: 'test-request',
          method: 'TRACE',
          path: '/api/models',
          headers: {'accept': 'application/json'},
        );

        // Send request message
        final requestJson = TunnelMessageProtocol.serialize(request);
        webSocketStreamController.add(requestJson);

        await Future.delayed(const Duration(milliseconds: 100));

        // Verify error response was sent back
        verify(mockWebSocketSink.add(any)).called(greaterThan(0));
      });
    });

    group('Health Monitoring', () {
      setUp(() async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        await tunnelClient.connect();
      });

      test('should send periodic ping messages', () async {
        // Wait for ping interval
        await Future.delayed(const Duration(seconds: 31));

        // Verify ping was sent
        verify(mockWebSocketSink.add(any)).called(greaterThan(1));
      });

      test('should handle pong timeout', () async {
        // Send ping but don't respond with pong
        await Future.delayed(const Duration(seconds: 31));

        // Wait for pong timeout
        await Future.delayed(const Duration(seconds: 11));

        // Connection should be marked as lost
        expect(tunnelClient.isConnected, false);
      });
    });

    group('Error Scenarios', () {
      test('should handle WebSocket error', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        await tunnelClient.connect();

        // Simulate WebSocket error
        webSocketStreamController.addError(
          const SocketException('Network error'),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(tunnelClient.isConnected, false);
        expect(tunnelClient.lastError, contains('WebSocket error'));
      });

      test('should handle WebSocket close', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        await tunnelClient.connect();

        // Simulate WebSocket close
        webSocketStreamController.close();

        await Future.delayed(const Duration(milliseconds: 100));

        expect(tunnelClient.isConnected, false);
        expect(tunnelClient.lastError, contains('Connection closed'));
      });

      test(
        'should complete pending requests with error on disconnect',
        () async {
          when(mockAuthService.getAccessToken()).thenReturn('valid-token');
          await tunnelClient.connect();

          // Disconnect while request is pending
          await tunnelClient.disconnect();

          // Pending requests should be completed with error
          expect(tunnelClient.isConnected, false);
        },
      );
    });

    group('Configuration and Compatibility', () {
      test('should provide configuration', () {
        final config = tunnelClient.config;

        expect(config.cloudProxyUrl, isNotEmpty);
        expect(config.localOllamaUrl, equals('http://localhost:11434'));
      });

      test('should provide connection status', () {
        final status = tunnelClient.connectionStatus;

        expect(status, containsPair('connected', false));
        expect(status, containsPair('connecting', false));
        expect(status, containsPair('reconnectAttempts', 0));
      });

      test('should initialize without error', () async {
        expect(() => tunnelClient.initialize(), returnsNormally);
      });

      test('should reconnect on demand', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        await tunnelClient.connect();
        expect(tunnelClient.isConnected, true);

        await tunnelClient.reconnect();
        expect(tunnelClient.isConnected, true);
      });
    });

    group('Disposal', () {
      test('should dispose cleanly', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        await tunnelClient.connect();

        expect(tunnelClient.isConnected, true);

        tunnelClient.dispose();

        expect(tunnelClient.isConnected, false);
      });

      test('should not notify listeners after disposal', () async {
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');
        await tunnelClient.connect();

        tunnelClient.dispose();

        // Simulate error after disposal
        webSocketStreamController.addError(
          const SocketException('Error after disposal'),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Should not throw error
      });
    });
  });
}
