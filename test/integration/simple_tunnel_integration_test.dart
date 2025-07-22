/// Integration tests for SimpleTunnelClient
///
/// Tests the complete message flow and protocol handling
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/simple_tunnel_client.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/services/tunnel_message_protocol.dart';

// Mock AuthService for testing
class MockAuthService extends AuthService {
  String? _accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  @override
  String? getAccessToken() => _accessToken;
}

void main() {
  group('SimpleTunnelClient Integration', () {
    late MockAuthService mockAuthService;
    late SimpleTunnelClient client;

    setUp(() {
      mockAuthService = MockAuthService();
      client = SimpleTunnelClient(authService: mockAuthService);
    });

    tearDown(() {
      client.dispose();
    });

    test('should initialize with correct default state', () {
      expect(client.isConnected, false);
      expect(client.isConnecting, false);
      expect(client.lastError, null);
      expect(client.reconnectAttempts, 0);
    });

    test('should handle complete message protocol flow', () {
      // Test creating a complete request/response cycle
      final httpRequest = HttpRequest(
        method: 'POST',
        path: '/api/generate',
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'model': 'llama2',
          'prompt': 'Hello, how are you?',
          'stream': false,
        }),
      );

      // Convert to tunnel request
      final tunnelRequest = TunnelMessageProtocol.createRequestMessage(
        httpRequest,
      );

      // Verify tunnel request
      expect(tunnelRequest.method, 'POST');
      expect(tunnelRequest.path, '/api/generate');
      expect(tunnelRequest.body, contains('llama2'));
      expect(tunnelRequest.id, isNotEmpty);

      // Simulate response
      final httpResponse = HttpResponse(
        status: 200,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'model': 'llama2',
          'created_at': '2025-01-15T10:30:00Z',
          'response': 'Hello! I\'m doing well, thank you for asking.',
          'done': true,
        }),
      );

      // Convert to tunnel response
      final tunnelResponse = TunnelResponseMessage.fromHttpResponse(
        tunnelRequest.id,
        httpResponse,
      );

      // Verify tunnel response
      expect(tunnelResponse.id, tunnelRequest.id);
      expect(tunnelResponse.status, 200);
      expect(tunnelResponse.body, contains('Hello! I\'m doing well'));

      // Test serialization round-trip
      final serializedRequest = TunnelMessageProtocol.serialize(tunnelRequest);
      final deserializedRequest = TunnelMessageProtocol.deserialize(
        serializedRequest,
      );

      expect(deserializedRequest, isA<TunnelRequestMessage>());
      final reqMsg = deserializedRequest as TunnelRequestMessage;
      expect(reqMsg.id, tunnelRequest.id);
      expect(reqMsg.method, tunnelRequest.method);
      expect(reqMsg.path, tunnelRequest.path);
    });

    test('should handle ping/pong health check cycle', () {
      // Create ping message
      final ping = PingMessage.create();
      expect(ping.type, TunnelMessageTypes.ping);
      expect(ping.id, isNotEmpty);
      expect(ping.timestamp, isNotEmpty);

      // Create pong response
      final pong = PongMessage.fromPing(ping);
      expect(pong.type, TunnelMessageTypes.pong);
      expect(pong.id, ping.id);
      expect(pong.timestamp, isNotEmpty);

      // Test serialization
      final serializedPing = TunnelMessageProtocol.serialize(ping);
      final deserializedPing = TunnelMessageProtocol.deserialize(
        serializedPing,
      );

      expect(deserializedPing, isA<PingMessage>());
      final pingMsg = deserializedPing as PingMessage;
      expect(pingMsg.id, ping.id);
      expect(pingMsg.timestamp, ping.timestamp);
    });

    test('should handle error scenarios gracefully', () {
      // Test error message creation
      final error = ErrorMessage.create('req-123', 'Connection timeout', 504);
      expect(error.type, TunnelMessageTypes.error);
      expect(error.error, 'Connection timeout');
      expect(error.code, 504);

      // Test serialization
      final serialized = TunnelMessageProtocol.serialize(error);
      final deserialized = TunnelMessageProtocol.deserialize(serialized);

      expect(deserialized, isA<ErrorMessage>());
      final errorMsg = deserialized as ErrorMessage;
      expect(errorMsg.error, 'Connection timeout');
      expect(errorMsg.code, 504);
    });

    test('should validate message protocol constraints', () {
      // Test valid HTTP methods
      for (final method in HttpMethods.all) {
        final request = HttpRequest(
          method: method,
          path: '/api/test',
          headers: {},
        );
        expect(TunnelMessageProtocol.validateHttpRequest(request), true);
      }

      // Test invalid HTTP method
      final invalidRequest = HttpRequest(
        method: 'INVALID',
        path: '/api/test',
        headers: {},
      );
      expect(TunnelMessageProtocol.validateHttpRequest(invalidRequest), false);

      // Test valid HTTP status codes
      final validStatuses = [200, 201, 400, 401, 404, 500, 502, 503, 504];
      for (final status in validStatuses) {
        final response = HttpResponse(status: status, headers: {}, body: '');
        expect(TunnelMessageProtocol.validateHttpResponse(response), true);
      }

      // Test invalid HTTP status code
      final invalidResponse = HttpResponse(status: 999, headers: {}, body: '');
      expect(
        TunnelMessageProtocol.validateHttpResponse(invalidResponse),
        false,
      );
    });

    test('should handle authentication token scenarios', () {
      // Test missing token
      mockAuthService.setAccessToken(null);
      expect(mockAuthService.getAccessToken(), null);

      // Test valid token
      mockAuthService.setAccessToken(
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.test',
      );
      expect(mockAuthService.getAccessToken(), isNotNull);
      expect(mockAuthService.getAccessToken(), contains('eyJ0eXAiOiJKV1Q'));
    });

    test('should handle various HTTP request types', () {
      final testCases = [
        {'method': 'GET', 'path': '/api/models', 'body': null},
        {
          'method': 'POST',
          'path': '/api/generate',
          'body': jsonEncode({'model': 'llama2', 'prompt': 'test'}),
        },
        {'method': 'DELETE', 'path': '/api/models/test-model', 'body': null},
      ];

      for (final testCase in testCases) {
        final request = HttpRequest(
          method: testCase['method'] as String,
          path: testCase['path'] as String,
          headers: {'content-type': 'application/json'},
          // ignore: unnecessary_cast
          body: testCase['body'] as String?,
        );

        final tunnelRequest = TunnelMessageProtocol.createRequestMessage(
          request,
        );
        expect(tunnelRequest.method, testCase['method']);
        expect(tunnelRequest.path, testCase['path']);
        expect(tunnelRequest.body, testCase['body']);

        // Test round-trip conversion
        final extractedRequest = TunnelMessageProtocol.extractHttpRequest(
          tunnelRequest,
        );
        expect(extractedRequest.method, request.method);
        expect(extractedRequest.path, request.path);
        expect(extractedRequest.body, request.body);
      }
    });
  });
}
