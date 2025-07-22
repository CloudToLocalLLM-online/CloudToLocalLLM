/// End-to-end tests for tunnel system
///
/// Tests complete request/response flow through the tunnel system
// ignore_for_file: argument_type_not_assignable, undefined_getter, undefined_named_parameter, avoid_print
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:cloudtolocalllm/services/simple_tunnel_client.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/services/tunnel_message_protocol.dart';
import '../test_config.dart';

// Generate mocks
@GenerateMocks([AuthService, http.Client])
import 'tunnel_e2e_test.mocks.dart';

/// Mock WebSocket server for testing
class MockWebSocketServer {
  late HttpServer _server;
  final List<WebSocket> _clients = [];
  final StreamController<TunnelMessage> _messageController =
      StreamController.broadcast();

  Stream<TunnelMessage> get messages => _messageController.stream;
  List<WebSocket> get clients => List.unmodifiable(_clients);

  Future<void> start({int port = 0}) async {
    _server = await HttpServer.bind('localhost', port);

    _server.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final webSocket = await WebSocketTransformer.upgrade(request);
        _clients.add(webSocket);

        webSocket.listen(
          (data) {
            try {
              final message = TunnelMessageProtocol.deserialize(data);
              _messageController.add(message);
            } catch (e) {
              print('Failed to parse message: $e');
            }
          },
          onDone: () => _clients.remove(webSocket),
          onError: (error) => print('WebSocket error: $error'),
        );
      }
    });
  }

  Future<void> sendMessage(TunnelMessage message) async {
    final serialized = TunnelMessageProtocol.serialize(message);
    for (final client in _clients) {
      client.add(serialized);
    }
  }

  Future<void> stop() async {
    _messageController.close();
    for (final client in _clients) {
      await client.close();
    }
    await _server.close();
  }

  String get url => 'ws://localhost:${_server.port}';
}

/// Mock Ollama server for testing
class MockOllamaServer {
  late HttpServer _server;
  final Map<String, dynamic> _responses = {};
  final List<HttpRequest> _requests = [];

  List<HttpRequest> get requests => List.unmodifiable(_requests);

  Future<void> start({int port = 11434}) async {
    _server = await HttpServer.bind('localhost', port);

    _server.listen((HttpRequest request) async {
      _requests.add(request);

      final path = request.uri.path;
      final method = request.method;
      final key = '$method $path';

      if (_responses.containsKey(key)) {
        final response = _responses[key];
        request.response.statusCode = response['status'] ?? 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response['body'] ?? {}));
      } else {
        request.response.statusCode = 404;
        request.response.write('Not found');
      }

      await request.response.close();
    });
  }

  void setResponse(
    String method,
    String path, {
    int status = 200,
    dynamic body,
  }) {
    _responses['$method $path'] = {'status': status, 'body': body};
  }

  Future<void> stop() async {
    await _server.close();
  }

  String get url => 'http://localhost:${_server.port}';
}

void main() {
  TestConfig.initialize();

  group('Tunnel End-to-End Tests', () {
    late MockWebSocketServer mockServer;
    late MockOllamaServer mockOllama;
    late SimpleTunnelClient tunnelClient;
    late MockAuthService mockAuthService;

    setUpAll(() async {
      mockServer = MockWebSocketServer();
      mockOllama = MockOllamaServer();

      await mockServer.start();
      await mockOllama.start();
    });

    tearDownAll(() async {
      await mockServer.stop();
      await mockOllama.stop();
    });

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.getAccessToken()).thenReturn('test-token');
      when(mockAuthService.currentUser).thenReturn(null);

      tunnelClient = SimpleTunnelClient(authService: mockAuthService);
    });

    tearDown(() {
      tunnelClient.dispose();
    });

    group('Complete Request Flow', () {
      test('should handle GET request end-to-end', () async {
        // Setup Ollama response
        mockOllama.setResponse(
          'GET',
          '/api/models',
          body: {
            'models': [
              {'name': 'llama2', 'size': 3800000000},
              {'name': 'codellama', 'size': 3800000000},
            ],
          },
        );

        // Connect tunnel client
        await tunnelClient.connect();
        expect(tunnelClient.isConnected, true);

        // Wait for client to connect to mock server
        await Future.delayed(const Duration(milliseconds: 100));
        expect(mockServer.clients.length, 1);

        // Send HTTP request through tunnel
        final request = TunnelRequestMessage(
          id: 'test-request-1',
          method: 'GET',
          path: '/api/models',
          headers: {'accept': 'application/json'},
        );

        final responseCompleter = Completer<TunnelResponseMessage>();

        // Listen for response
        mockServer.messages.listen((message) {
          if (message is TunnelResponseMessage && message.id == request.id) {
            responseCompleter.complete(message);
          }
        });

        // Send request
        await mockServer.sendMessage(request);

        // Wait for response
        final response = await responseCompleter.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('No response received'),
        );

        // Verify response
        expect(response.status, 200);
        expect(response.headers['content-type'], contains('json'));

        final responseBody = jsonDecode(response.body);
        expect(responseBody['models'], hasLength(2));
        expect(responseBody['models'][0]['name'], 'llama2');

        // Verify Ollama received the request
        expect(mockOllama.requests, hasLength(1));
        expect(mockOllama.requests.first.method, 'GET');
        expect(mockOllama.requests.first.uri.path, '/api/models');
      });

      test('should handle POST request with body end-to-end', () async {
        // Setup Ollama response
        mockOllama.setResponse(
          'POST',
          '/api/chat',
          body: {'response': 'Hello! How can I help you today?', 'done': true},
        );

        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));

        // Send HTTP request through tunnel
        final requestBody = {
          'model': 'llama2',
          'prompt': 'Hello',
          'stream': false,
        };

        final request = TunnelRequestMessage(
          id: 'test-request-2',
          method: 'POST',
          path: '/api/chat',
          headers: {'content-type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        final responseCompleter = Completer<TunnelResponseMessage>();

        // Listen for response
        mockServer.messages.listen((message) {
          if (message is TunnelResponseMessage && message.id == request.id) {
            responseCompleter.complete(message);
          }
        });

        // Send request
        await mockServer.sendMessage(request);

        // Wait for response
        final response = await responseCompleter.future.timeout(
          const Duration(seconds: 5),
        );

        // Verify response
        expect(response.status, 200);

        final responseBody = jsonDecode(response.body);
        expect(responseBody['response'], contains('Hello'));
        expect(responseBody['done'], true);

        // Verify Ollama received the request with body
        expect(mockOllama.requests, hasLength(1));
        expect(mockOllama.requests.first.method, 'POST');
        expect(mockOllama.requests.first.uri.path, '/api/chat');
      });

      test('should handle multiple concurrent requests', () async {
        // Setup Ollama responses
        mockOllama.setResponse('GET', '/api/models', body: {'models': []});
        mockOllama.setResponse(
          'GET',
          '/api/version',
          body: {'version': '0.1.0'},
        );
        mockOllama.setResponse('GET', '/api/tags', body: {'models': []});

        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));

        // Create multiple requests
        final requests = [
          TunnelRequestMessage(
            id: 'req-1',
            method: 'GET',
            path: '/api/models',
            headers: {'accept': 'application/json'},
          ),
          TunnelRequestMessage(
            id: 'req-2',
            method: 'GET',
            path: '/api/version',
            headers: {'accept': 'application/json'},
          ),
          TunnelRequestMessage(
            id: 'req-3',
            method: 'GET',
            path: '/api/tags',
            headers: {'accept': 'application/json'},
          ),
        ];

        final responseCompleters = <String, Completer<TunnelResponseMessage>>{};
        for (final req in requests) {
          responseCompleters[req.id] = Completer<TunnelResponseMessage>();
        }

        // Listen for responses
        mockServer.messages.listen((message) {
          if (message is TunnelResponseMessage &&
              responseCompleters.containsKey(message.id)) {
            responseCompleters[message.id]!.complete(message);
          }
        });

        // Send all requests concurrently
        await Future.wait(requests.map((req) => mockServer.sendMessage(req)));

        // Wait for all responses
        final responses = await Future.wait(
          responseCompleters.values.map((c) => c.future),
          timeout: const Duration(seconds: 10),
        );

        // Verify all responses received
        expect(responses, hasLength(3));
        for (final response in responses) {
          expect(response.status, 200);
        }

        // Verify all requests reached Ollama
        expect(mockOllama.requests, hasLength(3));
      });

      test('should handle request timeout', () async {
        // Don't setup any Ollama response (will cause timeout)

        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));

        // Send request that will timeout
        final request = TunnelRequestMessage(
          id: 'timeout-request',
          method: 'GET',
          path: '/api/slow-endpoint',
          headers: {'accept': 'application/json'},
        );

        final responseCompleter = Completer<TunnelResponseMessage>();

        // Listen for response
        mockServer.messages.listen((message) {
          if (message is TunnelResponseMessage && message.id == request.id) {
            responseCompleter.complete(message);
          }
        });

        // Send request
        await mockServer.sendMessage(request);

        // Wait for timeout response
        final response = await responseCompleter.future.timeout(
          const Duration(seconds: 35), // Longer than tunnel timeout
        );

        // Should receive timeout error response
        expect(response.status, 504); // Gateway timeout

        final responseBody = jsonDecode(response.body);
        expect(responseBody['error'], contains('timeout'));
      });

      test('should handle Ollama connection failure', () async {
        // Stop Ollama server to simulate connection failure
        await mockOllama.stop();

        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));

        // Send request
        final request = TunnelRequestMessage(
          id: 'connection-fail-request',
          method: 'GET',
          path: '/api/models',
          headers: {'accept': 'application/json'},
        );

        final responseCompleter = Completer<TunnelResponseMessage>();

        // Listen for response
        mockServer.messages.listen((message) {
          if (message is TunnelResponseMessage && message.id == request.id) {
            responseCompleter.complete(message);
          }
        });

        // Send request
        await mockServer.sendMessage(request);

        // Wait for error response
        final response = await responseCompleter.future.timeout(
          const Duration(seconds: 5),
        );

        // Should receive service unavailable error
        expect(response.status, 503); // Service unavailable

        final responseBody = jsonDecode(response.body);
        expect(responseBody['error'], contains('unavailable'));

        // Restart Ollama for other tests
        await mockOllama.start();
      });
    });

    group('Health Check Flow', () {
      test('should handle ping-pong health check', () async {
        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));

        // Send ping
        final ping = PingMessage.create();
        final pongCompleter = Completer<PongMessage>();

        // Listen for pong
        mockServer.messages.listen((message) {
          if (message is PongMessage && message.id == ping.id) {
            pongCompleter.complete(message);
          }
        });

        // Send ping
        await mockServer.sendMessage(ping);

        // Wait for pong
        final pong = await pongCompleter.future.timeout(
          const Duration(seconds: 2),
        );

        expect(pong.id, ping.id);
        expect(pong.timestamp, isNotNull);
      });

      test('should detect connection loss via ping timeout', () async {
        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(tunnelClient.isConnected, true);

        // Disconnect mock server to simulate connection loss
        await mockServer.stop();

        // Wait for ping timeout detection
        await Future.delayed(const Duration(seconds: 35));

        // Connection should be detected as lost
        expect(tunnelClient.isConnected, false);
        expect(tunnelClient.lastError, isNotNull);

        // Restart server for cleanup
        await mockServer.start();
      });
    });

    group('Error Recovery Flow', () {
      test('should recover from temporary connection loss', () async {
        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(tunnelClient.isConnected, true);

        // Simulate temporary connection loss
        await mockServer.stop();
        await Future.delayed(const Duration(milliseconds: 500));

        expect(tunnelClient.isConnected, false);

        // Restart server
        await mockServer.start();

        // Wait for reconnection
        await Future.delayed(const Duration(seconds: 5));

        // Should reconnect automatically
        expect(tunnelClient.isConnected, true);
      });

      test(
        'should handle authentication failure during reconnection',
        () async {
          // Connect tunnel client
          await tunnelClient.connect();
          await Future.delayed(const Duration(milliseconds: 100));
          expect(tunnelClient.isConnected, true);

          // Simulate auth token expiration
          when(mockAuthService.getAccessToken()).thenReturn(null);

          // Trigger reconnection
          await tunnelClient.reconnect();

          // Should fail to reconnect due to auth failure
          expect(tunnelClient.isConnected, false);
          expect(tunnelClient.lastError, contains('authentication'));
        },
      );
    });

    group('Performance and Load', () {
      test('should handle high request volume', () async {
        // Setup Ollama response
        mockOllama.setResponse('GET', '/api/test', body: {'result': 'ok'});

        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));

        // Send many requests rapidly
        const requestCount = 50;
        final requests = <TunnelRequestMessage>[];
        final responseCompleters = <String, Completer<TunnelResponseMessage>>{};

        for (int i = 0; i < requestCount; i++) {
          final request = TunnelRequestMessage(
            id: 'load-test-$i',
            method: 'GET',
            path: '/api/test',
            headers: {'accept': 'application/json'},
          );
          requests.add(request);
          responseCompleters[request.id] = Completer<TunnelResponseMessage>();
        }

        // Listen for responses
        mockServer.messages.listen((message) {
          if (message is TunnelResponseMessage &&
              responseCompleters.containsKey(message.id)) {
            responseCompleters[message.id]!.complete(message);
          }
        });

        // Send all requests
        final startTime = DateTime.now();
        await Future.wait(requests.map((req) => mockServer.sendMessage(req)));

        // Wait for all responses
        final responses = await Future.wait(
          responseCompleters.values.map((c) => c.future),
          timeout: const Duration(seconds: 30),
        );
        final endTime = DateTime.now();

        // Verify all responses received
        expect(responses, hasLength(requestCount));
        for (final response in responses) {
          expect(response.status, 200);
        }

        // Verify performance (should handle 50 requests in reasonable time)
        final duration = endTime.difference(startTime);
        expect(duration.inSeconds, lessThan(30));

        print(
          'Processed $requestCount requests in ${duration.inMilliseconds}ms',
        );
      });

      test('should maintain connection stability under load', () async {
        // Setup Ollama response
        mockOllama.setResponse('POST', '/api/chat', body: {'response': 'test'});

        // Connect tunnel client
        await tunnelClient.connect();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(tunnelClient.isConnected, true);

        // Send requests continuously for a period
        const duration = Duration(seconds: 10);
        final endTime = DateTime.now().add(duration);
        int requestCount = 0;
        int responseCount = 0;

        final responseCompleter = Completer<void>();

        // Listen for responses
        mockServer.messages.listen((message) {
          if (message is TunnelResponseMessage) {
            responseCount++;
          }
        });

        // Send requests continuously
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          if (DateTime.now().isAfter(endTime)) {
            timer.cancel();
            // Wait a bit more for final responses
            await Future.delayed(const Duration(seconds: 2));
            responseCompleter.complete();
            return;
          }

          final request = TunnelRequestMessage(
            id: 'stability-test-${requestCount++}',
            method: 'POST',
            path: '/api/chat',
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'prompt': 'test $requestCount'}),
          );

          try {
            await mockServer.sendMessage(request);
          } catch (e) {
            print('Failed to send request $requestCount: $e');
          }
        });

        await responseCompleter.future;

        // Verify connection remained stable
        expect(tunnelClient.isConnected, true);
        expect(requestCount, greaterThan(50)); // Should have sent many requests
        expect(
          responseCount,
          greaterThan(requestCount * 0.8),
        ); // Most should succeed

        print(
          'Stability test: $requestCount requests, $responseCount responses',
        );
      });
    });
  });
}
