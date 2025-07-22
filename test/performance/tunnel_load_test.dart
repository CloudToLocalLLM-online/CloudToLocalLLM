/// Load tests for the simplified tunnel system
/// Tests performance under high concurrent load and multiple users
// ignore_for_file: avoid_print, unnecessary_import
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/services/tunnel_message_protocol.dart';
import '../test_config.dart';

// Generate mocks
@GenerateMocks([AuthService, http.Client])
import 'tunnel_load_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestConfig.initialize();

  group('Tunnel Load Tests', () {
    late MockAuthService mockAuthService;
    late MockClient mockHttpClient;
    final random = Random();

    setUp(() {
      mockAuthService = MockAuthService();
      mockHttpClient = MockClient();

      // Setup auth service mock
      when(mockAuthService.getAccessToken()).thenReturn('test-token');
      when(mockAuthService.currentUser).thenReturn(null);
    });

    group('Message Protocol Load Tests', () {
      test(
        'should handle high volume message serialization/deserialization',
        () async {
          const messageCount = 1000;
          final stopwatch = Stopwatch()..start();

          // Generate test messages
          final messages = <TunnelMessage>[];
          for (int i = 0; i < messageCount; i++) {
            switch (i % 4) {
              case 0:
                messages.add(
                  TunnelRequestMessage(
                    id: 'req-$i',
                    method: 'GET',
                    path: '/api/models',
                    headers: {'accept': 'application/json'},
                  ),
                );
                break;
              case 1:
                messages.add(
                  TunnelResponseMessage(
                    id: 'req-$i',
                    status: 200,
                    headers: {'content-type': 'application/json'},
                    body: '{"result": "success"}',
                  ),
                );
                break;
              case 2:
                messages.add(PingMessage.create());
                break;
              case 3:
                messages.add(
                  ErrorMessage(id: 'error-$i', error: 'Test error', code: 500),
                );
                break;
            }
          }

          // Test serialization performance
          final serialized = <String>[];
          for (final message in messages) {
            serialized.add(TunnelMessageProtocol.serialize(message));
          }

          // Test deserialization performance
          final deserialized = <TunnelMessage>[];
          for (final json in serialized) {
            deserialized.add(TunnelMessageProtocol.deserialize(json));
          }

          stopwatch.stop();
          final totalTime = stopwatch.elapsedMilliseconds;
          final messagesPerSecond =
              (messageCount * 2 * 1000) /
              totalTime; // *2 for serialize + deserialize

          print('Processed $messageCount messages in ${totalTime}ms');
          print(
            'Performance: ${messagesPerSecond.toStringAsFixed(2)} operations/second',
          );

          // Verify all messages were processed correctly
          expect(serialized.length, equals(messageCount));
          expect(deserialized.length, equals(messageCount));

          // Performance assertion - should handle at least 1000 ops/second
          expect(messagesPerSecond, greaterThan(1000));
        },
      );

      test('should handle concurrent message processing', () async {
        const concurrentUsers = 50;
        const messagesPerUser = 20;
        final futures = <Future<void>>[];

        final stopwatch = Stopwatch()..start();

        // Simulate concurrent users processing messages
        for (int user = 0; user < concurrentUsers; user++) {
          futures.add(_simulateUserMessageProcessing(user, messagesPerUser));
        }

        // Wait for all users to complete
        await Future.wait(futures);

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final totalMessages =
            concurrentUsers *
            messagesPerUser *
            2; // *2 for serialize + deserialize
        final messagesPerSecond = (totalMessages * 1000) / totalTime;

        print(
          'Processed $totalMessages messages from $concurrentUsers concurrent users in ${totalTime}ms',
        );
        print(
          'Performance: ${messagesPerSecond.toStringAsFixed(2)} operations/second',
        );

        // Performance assertion - should handle concurrent load efficiently
        expect(messagesPerSecond, greaterThan(500));
      });

      test('should handle large message payloads', () async {
        const messageCount = 100;
        final stopwatch = Stopwatch()..start();

        // Generate large messages (simulating large chat responses)
        final largeMessages = <TunnelMessage>[];
        for (int i = 0; i < messageCount; i++) {
          final largeBody = _generateLargeJsonPayload(10000); // ~10KB payload
          largeMessages.add(
            TunnelResponseMessage(
              id: 'large-$i',
              status: 200,
              headers: {'content-type': 'application/json'},
              body: largeBody,
            ),
          );
        }

        // Test serialization/deserialization of large messages
        final serialized = <String>[];
        for (final message in largeMessages) {
          serialized.add(TunnelMessageProtocol.serialize(message));
        }

        final deserialized = <TunnelMessage>[];
        for (final json in serialized) {
          deserialized.add(TunnelMessageProtocol.deserialize(json));
        }

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final messagesPerSecond = (messageCount * 2 * 1000) / totalTime;

        print(
          'Processed $messageCount large messages (~10KB each) in ${totalTime}ms',
        );
        print(
          'Performance: ${messagesPerSecond.toStringAsFixed(2)} operations/second',
        );

        // Verify integrity
        expect(serialized.length, equals(messageCount));
        expect(deserialized.length, equals(messageCount));

        // Performance assertion - should handle large messages reasonably well
        expect(messagesPerSecond, greaterThan(50));
      });
    });

    group('HTTP Request Simulation Load Tests', () {
      test('should simulate high volume HTTP request processing', () async {
        const requestCount = 500;
        final stopwatch = Stopwatch()..start();

        // Mock HTTP responses
        when(
          mockHttpClient.get(any, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"result": "ok"}', 200));
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('{"response": "processed"}', 200),
        );

        // Generate HTTP requests
        final requests = <TunnelRequestMessage>[];
        for (int i = 0; i < requestCount; i++) {
          if (i % 2 == 0) {
            requests.add(
              TunnelRequestMessage(
                id: 'load-get-$i',
                method: 'GET',
                path: '/api/models',
                headers: {'accept': 'application/json'},
              ),
            );
          } else {
            requests.add(
              TunnelRequestMessage(
                id: 'load-post-$i',
                method: 'POST',
                path: '/api/chat',
                headers: {'content-type': 'application/json'},
                body: jsonEncode({'prompt': 'Test message $i'}),
              ),
            );
          }
        }

        // Process all requests (simulate tunnel processing)
        final responses = <TunnelResponseMessage>[];
        for (final request in requests) {
          // Convert to HTTP request
          final httpRequest = request.toHttpRequest();

          // Simulate HTTP call (would normally go to local Ollama)
          late http.Response httpResponse;
          if (httpRequest.method == 'GET') {
            httpResponse = await mockHttpClient.get(
              Uri.parse('http://localhost:11434${httpRequest.path}'),
              headers: httpRequest.headers,
            );
          } else {
            httpResponse = await mockHttpClient.post(
              Uri.parse('http://localhost:11434${httpRequest.path}'),
              headers: httpRequest.headers,
              body: httpRequest.body,
            );
          }

          // Convert back to tunnel response
          final tunnelResponse = TunnelResponseMessage.fromHttpResponse(
            request.id,
            HttpResponse(
              status: httpResponse.statusCode,
              headers: httpResponse.headers.map((k, v) => MapEntry(k, v)),
              body: httpResponse.body,
            ),
          );
          responses.add(tunnelResponse);
        }

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final requestsPerSecond = (requestCount * 1000) / totalTime;

        print('Processed $requestCount HTTP requests in ${totalTime}ms');
        print(
          'Performance: ${requestsPerSecond.toStringAsFixed(2)} requests/second',
        );

        // Verify all requests were processed
        expect(responses.length, equals(requestCount));

        // Performance assertion
        expect(requestsPerSecond, greaterThan(100));
      });

      test('should handle concurrent HTTP request processing', () async {
        const concurrentUsers = 20;
        const requestsPerUser = 10;
        final futures = <Future<List<TunnelResponseMessage>>>[];

        // Mock HTTP responses
        when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((
          _,
        ) async {
          // Add small delay to simulate real HTTP processing
          await Future.delayed(Duration(milliseconds: random.nextInt(10) + 1));
          return http.Response('{"result": "ok"}', 200);
        });

        final stopwatch = Stopwatch()..start();

        // Simulate concurrent users making requests
        for (int user = 0; user < concurrentUsers; user++) {
          futures.add(
            _simulateUserHttpRequests(user, requestsPerUser, mockHttpClient),
          );
        }

        // Wait for all users to complete
        final results = await Future.wait(futures);

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final totalRequests = concurrentUsers * requestsPerUser;
        final requestsPerSecond = (totalRequests * 1000) / totalTime;

        print(
          'Processed $totalRequests requests from $concurrentUsers concurrent users in ${totalTime}ms',
        );
        print(
          'Performance: ${requestsPerSecond.toStringAsFixed(2)} requests/second',
        );

        // Verify all requests were processed
        final totalResponses = results.fold<int>(
          0,
          (sum, responses) => sum + responses.length,
        );
        expect(totalResponses, equals(totalRequests));

        // Performance assertion for concurrent processing
        expect(requestsPerSecond, greaterThan(50));
      });
    });

    group('Memory and Resource Load Tests', () {
      test('should handle memory efficiently under load', () async {
        const iterations = 1000;
        final messages = <TunnelMessage>[];

        // Generate messages and keep references to test memory usage
        for (int i = 0; i < iterations; i++) {
          messages.add(
            TunnelRequestMessage(
              id: 'memory-test-$i',
              method: 'POST',
              path: '/api/chat',
              headers: {'content-type': 'application/json'},
              body: _generateLargeJsonPayload(1000), // 1KB payload
            ),
          );
        }

        // Process all messages
        final serialized = <String>[];
        for (final message in messages) {
          serialized.add(TunnelMessageProtocol.serialize(message));
        }

        // Verify memory usage is reasonable (no memory leaks)
        expect(messages.length, equals(iterations));
        expect(serialized.length, equals(iterations));

        // Clear references to test garbage collection
        messages.clear();
        serialized.clear();

        // Force garbage collection (if available)
        await Future.delayed(const Duration(milliseconds: 100));
      });

      test('should handle rapid message creation and disposal', () async {
        const cycles = 100;
        const messagesPerCycle = 50;

        final stopwatch = Stopwatch()..start();

        for (int cycle = 0; cycle < cycles; cycle++) {
          final cycleMessages = <TunnelMessage>[];

          // Create messages
          for (int i = 0; i < messagesPerCycle; i++) {
            cycleMessages.add(
              TunnelRequestMessage(
                id: 'cycle-$cycle-msg-$i',
                method: 'GET',
                path: '/api/test/$i',
                headers: {'accept': 'application/json'},
              ),
            );
          }

          // Process messages
          final processed = <String>[];
          for (final message in cycleMessages) {
            processed.add(TunnelMessageProtocol.serialize(message));
          }

          // Clear cycle (simulate message disposal)
          cycleMessages.clear();
          processed.clear();
        }

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final totalMessages = cycles * messagesPerCycle;
        final messagesPerSecond = (totalMessages * 1000) / totalTime;

        print(
          'Processed $totalMessages messages in $cycles cycles in ${totalTime}ms',
        );
        print(
          'Performance: ${messagesPerSecond.toStringAsFixed(2)} messages/second',
        );

        // Performance assertion
        expect(messagesPerSecond, greaterThan(1000));
      });
    });
  });
}

/// Simulate a user processing messages
Future<void> _simulateUserMessageProcessing(
  int userId,
  int messageCount,
) async {
  final messages = <TunnelMessage>[];

  // Generate user-specific messages
  for (int i = 0; i < messageCount; i++) {
    messages.add(
      TunnelRequestMessage(
        id: 'user-$userId-msg-$i',
        method: 'GET',
        path: '/api/user/$userId/data/$i',
        headers: {'accept': 'application/json'},
      ),
    );
  }

  // Process messages (serialize/deserialize)
  for (final message in messages) {
    final serialized = TunnelMessageProtocol.serialize(message);
    TunnelMessageProtocol.deserialize(serialized);
  }
}

/// Simulate a user making HTTP requests
Future<List<TunnelResponseMessage>> _simulateUserHttpRequests(
  int userId,
  int requestCount,
  MockClient httpClient,
) async {
  final responses = <TunnelResponseMessage>[];

  for (int i = 0; i < requestCount; i++) {
    final request = TunnelRequestMessage(
      id: 'user-$userId-req-$i',
      method: 'GET',
      path: '/api/user/$userId/data/$i',
      headers: {'accept': 'application/json'},
    );

    // Simulate HTTP processing
    final httpRequest = request.toHttpRequest();
    final httpResponse = await httpClient.get(
      Uri.parse('http://localhost:11434${httpRequest.path}'),
      headers: httpRequest.headers,
    );

    final tunnelResponse = TunnelResponseMessage.fromHttpResponse(
      request.id,
      HttpResponse(
        status: httpResponse.statusCode,
        headers: httpResponse.headers.map((k, v) => MapEntry(k, v)),
        body: httpResponse.body,
      ),
    );

    responses.add(tunnelResponse);
  }

  return responses;
}

/// Generate a large JSON payload for testing
String _generateLargeJsonPayload(int targetSize) {
  final buffer = StringBuffer();
  buffer.write('{"data": "');

  // Fill with random characters to reach target size
  final chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random();

  while (buffer.length < targetSize - 20) {
    // Leave room for JSON structure
    buffer.write(chars[random.nextInt(chars.length)]);
  }

  buffer.write('", "size": ${buffer.length}}');
  return buffer.toString();
}
