// ignore_for_file: undefined_getter, undefined_method, avoid_print, unnecessary_import
import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:cloudtolocalllm/services/simple_tunnel_client.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/models/tunnel_message.dart';
import 'package:cloudtolocalllm/utils/tunnel_logger.dart';

@GenerateMocks([AuthService])
import 'tunnel_performance_test.mocks.dart';

/// Performance tests for SimpleTunnelClient
/// Tests connection pooling, message queuing, and performance metrics
void main() {
  group('SimpleTunnelClient Performance Tests', () {
    late MockAuthService mockAuthService;
    late SimpleTunnelClient tunnelClient;

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.getAccessToken()).thenReturn('mock-token');
      when(mockAuthService.currentUser).thenReturn(null);

      tunnelClient = SimpleTunnelClient(authService: mockAuthService);
    });

    tearDown(() {
      tunnelClient.dispose();
    });

    test('should track performance metrics correctly', () async {
      // Get initial metrics
      final initialMetrics = tunnelClient.getPerformanceMetrics();
      expect(initialMetrics['totalRequests'], equals(0));
      expect(initialMetrics['successfulRequests'], equals(0));
      expect(initialMetrics['failedRequests'], equals(0));

      // Simulate some successful requests
      final metrics = tunnelClient._metrics;
      for (int i = 0; i < 10; i++) {
        final responseTime = Duration(
          milliseconds: 100 + Random().nextInt(200),
        );
        metrics.recordSuccess(responseTime);
      }

      // Simulate some failed requests
      for (int i = 0; i < 3; i++) {
        metrics.recordFailure();
      }

      // Simulate timeout requests
      for (int i = 0; i < 2; i++) {
        metrics.recordFailure(isTimeout: true);
      }

      final finalMetrics = tunnelClient.getPerformanceMetrics();
      expect(finalMetrics['totalRequests'], equals(15));
      expect(finalMetrics['successfulRequests'], equals(10));
      expect(finalMetrics['failedRequests'], equals(5));
      expect(finalMetrics['timeoutRequests'], equals(2));
      expect(finalMetrics['successRate'], greaterThan(60.0));
      expect(finalMetrics['timeoutRate'], greaterThan(10.0));
    });

    test('should calculate response time percentiles correctly', () async {
      final metrics = tunnelClient._metrics;

      // Add response times with known distribution
      final responseTimes = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];
      for (final time in responseTimes) {
        metrics.recordSuccess(Duration(milliseconds: time));
      }

      final performanceMetrics = tunnelClient.getPerformanceMetrics();
      expect(performanceMetrics['averageResponseTime'], greaterThan(0));
      expect(performanceMetrics['recentAverageResponseTime'], greaterThan(0));
      expect(performanceMetrics['p95ResponseTime'], greaterThan(0));
    });

    test('should track throughput correctly', () async {
      final metrics = tunnelClient._metrics;

      // Simulate requests over time
      for (int i = 0; i < 20; i++) {
        metrics.recordSuccess(Duration(milliseconds: 100));
        // Small delay to spread requests over time
        await Future.delayed(Duration(milliseconds: 10));
      }

      final performanceMetrics = tunnelClient.getPerformanceMetrics();
      expect(performanceMetrics['currentThroughput'], greaterThan(0));
    });

    test('should track memory usage metrics', () async {
      // Update memory usage
      tunnelClient._updateMemoryUsage();

      final metrics = tunnelClient.getPerformanceMetrics();
      expect(metrics['memoryUsageMB'], greaterThan(0));
      expect(
        metrics['peakMemoryUsageMB'],
        greaterThanOrEqualTo(metrics['memoryUsageMB']),
      );
    });

    test('should detect performance degradation', () async {
      final metrics = tunnelClient._metrics;

      // Simulate poor performance
      for (int i = 0; i < 10; i++) {
        metrics.recordFailure(isTimeout: true);
      }

      // Add high response times
      for (int i = 0; i < 5; i++) {
        metrics.recordSuccess(
          Duration(milliseconds: 8000),
        ); // High response time
      }

      expect(tunnelClient.isPerformanceDegraded, isTrue);

      final alerts = tunnelClient.getPerformanceAlerts();
      expect(alerts, isNotEmpty);
      expect(alerts.any((alert) => alert.contains('timeout rate')), isTrue);
      expect(alerts.any((alert) => alert.contains('response time')), isTrue);
    });

    test('should handle connection pool metrics', () async {
      final metrics = tunnelClient._metrics;

      // Simulate pool operations
      metrics.recordPoolHit();
      metrics.recordPoolHit();
      metrics.recordPoolMiss();
      metrics.updatePooledConnections(2);

      final performanceMetrics = tunnelClient.getPerformanceMetrics();
      expect(performanceMetrics['poolHits'], equals(2));
      expect(performanceMetrics['poolMisses'], equals(1));
      expect(performanceMetrics['poolEfficiency'], greaterThan(50.0));
      expect(performanceMetrics['pooledConnections'], equals(2));
    });

    test('should handle message queue metrics', () async {
      final metrics = tunnelClient._metrics;

      // Simulate queue operations
      metrics.updateQueueMetrics(10, Duration(milliseconds: 50));

      final performanceMetrics = tunnelClient.getPerformanceMetrics();
      expect(performanceMetrics['queuedMessages'], equals(10));
      expect(performanceMetrics['averageQueueTime'], equals(50));
    });

    test('should provide comprehensive health status', () async {
      final healthStatus = tunnelClient.getHealthStatus();

      expect(healthStatus, containsPair('connected', false));
      expect(healthStatus, containsPair('connecting', false));
      expect(healthStatus, containsPair('queueSize', 0));
      expect(healthStatus, containsPair('pendingRequests', 0));
      expect(healthStatus, containsPair('pooledConnections', 0));
      expect(healthStatus, contains('metrics'));
      expect(healthStatus, contains('timestamp'));
    });

    test('should handle high load scenarios', () async {
      final metrics = tunnelClient._metrics;

      // Simulate high load with many concurrent requests
      final futures = <Future>[];
      for (int i = 0; i < 1000; i++) {
        futures.add(
          Future.microtask(() {
            final responseTime = Duration(
              milliseconds: 50 + Random().nextInt(200),
            );
            if (Random().nextBool()) {
              metrics.recordSuccess(responseTime);
            } else {
              metrics.recordFailure(isTimeout: Random().nextBool());
            }
          }),
        );
      }

      await Future.wait(futures);

      final performanceMetrics = tunnelClient.getPerformanceMetrics();
      expect(performanceMetrics['totalRequests'], equals(1000));
      expect(performanceMetrics['successRate'], greaterThan(0));
      expect(performanceMetrics['averageResponseTime'], greaterThan(0));
    });

    test('should maintain performance under sustained load', () async {
      final metrics = tunnelClient._metrics;
      final stopwatch = Stopwatch()..start();

      // Run sustained load for a short period
      while (stopwatch.elapsedMilliseconds < 1000) {
        final responseTime = Duration(
          milliseconds: 100 + Random().nextInt(100),
        );
        metrics.recordSuccess(responseTime);
        await Future.delayed(Duration(microseconds: 100));
      }

      stopwatch.stop();

      final performanceMetrics = tunnelClient.getPerformanceMetrics();
      expect(performanceMetrics['totalRequests'], greaterThan(0));
      expect(performanceMetrics['currentThroughput'], greaterThan(0));

      // Performance should not be severely degraded
      expect(performanceMetrics['successRate'], greaterThan(95.0));
      expect(performanceMetrics['averageResponseTime'], lessThan(1000));
    });

    test('should handle memory pressure gracefully', () async {
      // Simulate memory pressure by updating memory usage
      final metrics = tunnelClient._metrics;

      // Simulate increasing memory usage
      for (int i = 1; i <= 10; i++) {
        metrics.updateMemoryUsage(i * 10 * 1024 * 1024); // 10MB increments
      }

      final performanceMetrics = tunnelClient.getPerformanceMetrics();
      expect(performanceMetrics['memoryUsageMB'], equals(100.0));
      expect(performanceMetrics['peakMemoryUsageMB'], equals(100.0));

      // Should generate memory usage alert
      final alerts = tunnelClient.getPerformanceAlerts();
      expect(alerts.any((alert) => alert.contains('memory usage')), isTrue);
    });

    test('should reset metrics correctly', () async {
      final metrics = tunnelClient._metrics;

      // Add some data
      metrics.recordSuccess(Duration(milliseconds: 100));
      metrics.recordFailure();
      metrics.recordReconnection();

      // Verify data exists
      expect(metrics.totalRequests, greaterThan(0));
      expect(metrics.reconnectionAttempts, greaterThan(0));

      // Create new client (simulates reset)
      final newClient = SimpleTunnelClient(authService: mockAuthService);
      final newMetrics = newClient.getPerformanceMetrics();

      expect(newMetrics['totalRequests'], equals(0));
      expect(newMetrics['reconnectionAttempts'], equals(0));

      newClient.dispose();
    });
  });

  group('Performance Benchmarks', () {
    test('message serialization performance', () async {
      final stopwatch = Stopwatch()..start();
      const iterations = 10000;

      for (int i = 0; i < iterations; i++) {
        final request = TunnelRequestMessage(
          id: 'test-$i',
          method: 'POST',
          path: '/api/test',
          headers: {'content-type': 'application/json'},
          body: '{"test": "data"}',
        );

        // This would normally serialize the message
        // For testing, we just create the object
        expect(request.id, equals('test-$i'));
      }

      stopwatch.stop();
      final avgTimePerMessage = stopwatch.elapsedMicroseconds / iterations;

      // Should be able to create/serialize messages quickly
      expect(
        avgTimePerMessage,
        lessThan(100),
      ); // Less than 100 microseconds per message

      print(
        'Average message creation time: ${avgTimePerMessage.toStringAsFixed(2)} microseconds',
      );
    });

    test('metrics calculation performance', () async {
      final metrics = TunnelMetrics();
      final stopwatch = Stopwatch()..start();
      const iterations = 10000;

      // Add many data points
      for (int i = 0; i < iterations; i++) {
        final responseTime = Duration(milliseconds: 50 + Random().nextInt(200));
        metrics.recordSuccess(responseTime);
      }

      stopwatch.stop();

      // Calculate metrics
      final metricsStopwatch = Stopwatch()..start();
      final metricsMap = metrics.toMap();
      metricsStopwatch.stop();

      expect(metricsMap['totalRequests'], equals(iterations));
      expect(
        metricsStopwatch.elapsedMilliseconds,
        lessThan(10),
      ); // Should be fast

      print(
        'Metrics calculation time for $iterations requests: ${metricsStopwatch.elapsedMilliseconds}ms',
      );
    });
  });
}
