/// Performance benchmarks for the simplified tunnel system
/// Establishes baseline performance metrics and compares against expected thresholds
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
import 'tunnel_performance_benchmark_test.mocks.dart';

/// Performance metrics container
class PerformanceMetrics {
  final String testName;
  final int operationsCount;
  final int totalTimeMs;
  final double operationsPerSecond;
  final double averageLatencyMs;
  final int memoryUsageBytes;

  PerformanceMetrics({
    required this.testName,
    required this.operationsCount,
    required this.totalTimeMs,
    required this.operationsPerSecond,
    required this.averageLatencyMs,
    required this.memoryUsageBytes,
  });

  @override
  String toString() {
    return '''
Performance Metrics for $testName:
  Operations: $operationsCount
  Total Time: ${totalTimeMs}ms
  Ops/Second: ${operationsPerSecond.toStringAsFixed(2)}
  Avg Latency: ${averageLatencyMs.toStringAsFixed(2)}ms
  Memory Usage: ${(memoryUsageBytes / 1024).toStringAsFixed(2)}KB
''';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestConfig.initialize();

  group('Tunnel Performance Benchmarks', () {
    late MockAuthService mockAuthService;
    late MockClient mockHttpClient;
    final performanceResults = <PerformanceMetrics>[];

    setUp(() {
      mockAuthService = MockAuthService();
      mockHttpClient = MockClient();

      // Setup auth service mock
      when(mockAuthService.getAccessToken()).thenReturn('test-token');
      when(mockAuthService.currentUser).thenReturn(null);
    });

    tearDownAll(() {
      // Print all performance results
      print('\n=== TUNNEL PERFORMANCE BENCHMARK RESULTS ===');
      for (final result in performanceResults) {
        print(result);
      }
      print('=== END BENCHMARK RESULTS ===\n');
    });

    group('Message Protocol Benchmarks', () {
      test('Message Serialization Performance Benchmark', () async {
        const operationsCount = 10000;
        final stopwatch = Stopwatch()..start();

        // Generate test messages
        final messages = <TunnelMessage>[];
        for (int i = 0; i < operationsCount; i++) {
          messages.add(
            TunnelRequestMessage(
              id: 'perf-test-$i',
              method: 'POST',
              path: '/api/chat',
              headers: {'content-type': 'application/json'},
              body: jsonEncode({
                'model': 'llama2',
                'prompt': 'Performance test message $i',
                'options': {'temperature': 0.7, 'max_tokens': 100},
              }),
            ),
          );
        }

        // Benchmark serialization
        final serialized = <String>[];
        for (final message in messages) {
          serialized.add(TunnelMessageProtocol.serialize(message));
        }

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final opsPerSecond = (operationsCount * 1000) / totalTime;
        final avgLatency = totalTime / operationsCount;

        final metrics = PerformanceMetrics(
          testName: 'Message Serialization',
          operationsCount: operationsCount,
          totalTimeMs: totalTime,
          operationsPerSecond: opsPerSecond,
          averageLatencyMs: avgLatency,
          memoryUsageBytes: _estimateMemoryUsage(serialized),
        );

        performanceResults.add(metrics);

        // Performance assertions (baseline expectations)
        expect(
          opsPerSecond,
          greaterThan(5000),
          reason: 'Serialization should handle >5K ops/sec',
        );
        expect(
          avgLatency,
          lessThan(1.0),
          reason: 'Average latency should be <1ms',
        );
      });

      test('Message Deserialization Performance Benchmark', () async {
        const operationsCount = 10000;

        // Pre-generate serialized messages
        final serializedMessages = <String>[];
        for (int i = 0; i < operationsCount; i++) {
          final message = TunnelResponseMessage(
            id: 'perf-response-$i',
            status: 200,
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'response': 'This is a performance test response $i',
              'model': 'llama2',
              'done': true,
            }),
          );
          serializedMessages.add(TunnelMessageProtocol.serialize(message));
        }

        final stopwatch = Stopwatch()..start();

        // Benchmark deserialization
        final deserialized = <TunnelMessage>[];
        for (final json in serializedMessages) {
          deserialized.add(TunnelMessageProtocol.deserialize(json));
        }

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final opsPerSecond = (operationsCount * 1000) / totalTime;
        final avgLatency = totalTime / operationsCount;

        final metrics = PerformanceMetrics(
          testName: 'Message Deserialization',
          operationsCount: operationsCount,
          totalTimeMs: totalTime,
          operationsPerSecond: opsPerSecond,
          averageLatencyMs: avgLatency,
          memoryUsageBytes: _estimateMemoryUsage(
            deserialized.map((m) => m.toString()).toList(),
          ),
        );

        performanceResults.add(metrics);

        // Performance assertions
        expect(
          opsPerSecond,
          greaterThan(4000),
          reason: 'Deserialization should handle >4K ops/sec',
        );
        expect(
          avgLatency,
          lessThan(1.5),
          reason: 'Average latency should be <1.5ms',
        );
      });

      test('Round-trip Message Processing Benchmark', () async {
        const operationsCount = 5000;
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < operationsCount; i++) {
          // Create message
          final original = TunnelRequestMessage(
            id: 'roundtrip-$i',
            method: 'GET',
            path: '/api/models',
            headers: {'accept': 'application/json'},
          );

          // Serialize
          final serialized = TunnelMessageProtocol.serialize(original);

          // Deserialize
          final deserialized = TunnelMessageProtocol.deserialize(serialized);

          // Verify integrity
          expect(deserialized.id, equals(original.id));
        }

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final opsPerSecond = (operationsCount * 1000) / totalTime;
        final avgLatency = totalTime / operationsCount;

        final metrics = PerformanceMetrics(
          testName: 'Round-trip Processing',
          operationsCount: operationsCount,
          totalTimeMs: totalTime,
          operationsPerSecond: opsPerSecond,
          averageLatencyMs: avgLatency,
          memoryUsageBytes: operationsCount * 500, // Estimated
        );

        performanceResults.add(metrics);

        // Performance assertions
        expect(
          opsPerSecond,
          greaterThan(2000),
          reason: 'Round-trip should handle >2K ops/sec',
        );
        expect(
          avgLatency,
          lessThan(2.0),
          reason: 'Round-trip latency should be <2ms',
        );
      });
    });

    group('HTTP Processing Benchmarks', () {
      test('HTTP Request Processing Performance Benchmark', () async {
        const operationsCount = 1000;

        // Setup HTTP client mock with realistic delay
        when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((
          _,
        ) async {
          // Simulate realistic HTTP processing time (1-5ms)
          await Future.delayed(
            Duration(microseconds: Random().nextInt(5000) + 1000),
          );
          return http.Response('{"result": "ok"}', 200);
        });

        final stopwatch = Stopwatch()..start();

        // Process HTTP requests
        final futures = <Future<http.Response>>[];
        for (int i = 0; i < operationsCount; i++) {
          futures.add(
            mockHttpClient.get(
              Uri.parse('http://localhost:11434/api/test/$i'),
              headers: {'accept': 'application/json'},
            ),
          );
        }

        final responses = await Future.wait(futures);

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final opsPerSecond = (operationsCount * 1000) / totalTime;
        final avgLatency = totalTime / operationsCount;

        final metrics = PerformanceMetrics(
          testName: 'HTTP Request Processing',
          operationsCount: operationsCount,
          totalTimeMs: totalTime,
          operationsPerSecond: opsPerSecond,
          averageLatencyMs: avgLatency,
          memoryUsageBytes: responses.length * 100, // Estimated
        );

        performanceResults.add(metrics);

        // Verify all requests completed
        expect(responses.length, equals(operationsCount));

        // Performance assertions (accounting for simulated HTTP delay)
        expect(
          opsPerSecond,
          greaterThan(50),
          reason: 'HTTP processing should handle >50 ops/sec',
        );
      });

      test('Concurrent HTTP Request Benchmark', () async {
        const concurrentUsers = 50;
        const requestsPerUser = 10;

        // Setup HTTP client mock
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(
            Duration(milliseconds: Random().nextInt(10) + 5),
          );
          return http.Response('{"response": "processed"}', 200);
        });

        final stopwatch = Stopwatch()..start();

        // Simulate concurrent users
        final userFutures = <Future<List<http.Response>>>[];
        for (int user = 0; user < concurrentUsers; user++) {
          userFutures.add(
            _processUserRequests(user, requestsPerUser, mockHttpClient),
          );
        }

        final userResults = await Future.wait(userFutures);

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final totalRequests = concurrentUsers * requestsPerUser;
        final opsPerSecond = (totalRequests * 1000) / totalTime;
        final avgLatency = totalTime / totalRequests;

        final metrics = PerformanceMetrics(
          testName: 'Concurrent HTTP Processing',
          operationsCount: totalRequests,
          totalTimeMs: totalTime,
          operationsPerSecond: opsPerSecond,
          averageLatencyMs: avgLatency,
          memoryUsageBytes: totalRequests * 150, // Estimated
        );

        performanceResults.add(metrics);

        // Verify all requests completed
        final totalResponses = userResults.fold<int>(
          0,
          (sum, responses) => sum + responses.length,
        );
        expect(totalResponses, equals(totalRequests));

        // Performance assertions for concurrent processing
        expect(
          opsPerSecond,
          greaterThan(20),
          reason: 'Concurrent processing should handle >20 ops/sec',
        );
      });
    });

    group('Memory Efficiency Benchmarks', () {
      test('Memory Usage Under Load Benchmark', () async {
        const messageCount = 5000;
        final messages = <TunnelMessage>[];
        final serialized = <String>[];

        final stopwatch = Stopwatch()..start();

        // Create and process messages
        for (int i = 0; i < messageCount; i++) {
          final message = TunnelRequestMessage(
            id: 'memory-test-$i',
            method: 'POST',
            path: '/api/chat',
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'prompt':
                  'Memory test prompt $i with some additional data to test memory usage patterns',
              'model': 'llama2',
              'options': {'temperature': 0.7},
            }),
          );

          messages.add(message);
          serialized.add(TunnelMessageProtocol.serialize(message));
        }

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMilliseconds;
        final memoryUsage =
            _estimateMemoryUsage(serialized) +
            _estimateMemoryUsage(messages.map((m) => m.toString()).toList());

        final metrics = PerformanceMetrics(
          testName: 'Memory Usage Under Load',
          operationsCount: messageCount,
          totalTimeMs: totalTime,
          operationsPerSecond: (messageCount * 1000) / totalTime,
          averageLatencyMs: totalTime / messageCount,
          memoryUsageBytes: memoryUsage,
        );

        performanceResults.add(metrics);

        // Memory efficiency assertions
        final avgMemoryPerMessage = memoryUsage / messageCount;
        expect(
          avgMemoryPerMessage,
          lessThan(2048),
          reason: 'Average memory per message should be <2KB',
        );

        print(
          'Average memory per message: ${avgMemoryPerMessage.toStringAsFixed(2)} bytes',
        );
      });

      test('Garbage Collection Efficiency Benchmark', () async {
        const cycles = 100;
        const messagesPerCycle = 100;
        final gcTimes = <int>[];

        for (int cycle = 0; cycle < cycles; cycle++) {
          final cycleStopwatch = Stopwatch()..start();

          // Create temporary messages
          final tempMessages = <TunnelMessage>[];
          for (int i = 0; i < messagesPerCycle; i++) {
            tempMessages.add(
              TunnelRequestMessage(
                id: 'gc-test-$cycle-$i',
                method: 'GET',
                path: '/api/test',
                headers: {},
              ),
            );
          }

          // Process and clear (simulate GC)
          final processed = tempMessages
              .map((m) => TunnelMessageProtocol.serialize(m))
              .toList();
          tempMessages.clear();
          processed.clear();

          cycleStopwatch.stop();
          gcTimes.add(cycleStopwatch.elapsedMicroseconds);
        }

        final avgGcTime = gcTimes.reduce((a, b) => a + b) / gcTimes.length;
        final totalOperations = cycles * messagesPerCycle;

        final metrics = PerformanceMetrics(
          testName: 'Garbage Collection Efficiency',
          operationsCount: totalOperations,
          totalTimeMs: (avgGcTime * cycles / 1000).round(),
          operationsPerSecond:
              (totalOperations * 1000000) / (avgGcTime * cycles),
          averageLatencyMs: avgGcTime / 1000,
          memoryUsageBytes: 0, // Temporary usage
        );

        performanceResults.add(metrics);

        print(
          'Average GC cycle time: ${avgGcTime.toStringAsFixed(2)} microseconds',
        );
        expect(avgGcTime, lessThan(10000), reason: 'GC cycle should be <10ms');
      });
    });

    group('Scalability Benchmarks', () {
      test('Message Volume Scalability Benchmark', () async {
        final volumeTests = [100, 500, 1000, 5000, 10000];
        final scalabilityResults = <int, double>{};

        for (final volume in volumeTests) {
          final stopwatch = Stopwatch()..start();

          // Process messages at this volume
          for (int i = 0; i < volume; i++) {
            final message = TunnelRequestMessage(
              id: 'scale-$volume-$i',
              method: 'GET',
              path: '/api/test',
              headers: {},
            );

            final serialized = TunnelMessageProtocol.serialize(message);
            TunnelMessageProtocol.deserialize(serialized);
          }

          stopwatch.stop();
          final opsPerSecond = (volume * 1000) / stopwatch.elapsedMilliseconds;
          scalabilityResults[volume] = opsPerSecond;

          print('Volume $volume: ${opsPerSecond.toStringAsFixed(2)} ops/sec');
        }

        // Verify scalability (performance shouldn't degrade significantly)
        final baselinePerf = scalabilityResults[100]!;
        final highVolumePerf = scalabilityResults[10000]!;

        // Handle cases where performance is too fast to measure accurately
        if (baselinePerf.isFinite &&
            highVolumePerf.isFinite &&
            baselinePerf > 0) {
          final performanceDegradation =
              (baselinePerf - highVolumePerf) / baselinePerf;

          if (performanceDegradation.isFinite) {
            expect(
              performanceDegradation,
              lessThan(0.8),
              reason: 'Performance degradation should be <80% at high volume',
            );
            print(
              'Performance degradation at 10K volume: ${(performanceDegradation * 100).toStringAsFixed(2)}%',
            );
          } else {
            print('Performance too fast to measure degradation accurately');
          }
        } else {
          print('Performance measurements too fast for accurate comparison');
        }
      });
    });
  });
}

/// Process HTTP requests for a user
Future<List<http.Response>> _processUserRequests(
  int userId,
  int requestCount,
  MockClient httpClient,
) async {
  final responses = <http.Response>[];

  for (int i = 0; i < requestCount; i++) {
    final response = await httpClient.post(
      Uri.parse('http://localhost:11434/api/chat'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'user': userId, 'request': i}),
    );
    responses.add(response);
  }

  return responses;
}

/// Estimate memory usage of a list of strings
int _estimateMemoryUsage(List<String> strings) {
  return strings.fold<int>(
    0,
    (sum, str) => sum + (str.length * 2),
  ); // Rough estimate: 2 bytes per char
}
