import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/connection_manager_service.dart';

void main() {
  group('ConnectionManagerService - Connection Pool Monitoring', () {
    test('ConnectionPoolMetrics should calculate utilization correctly', () {
      final metrics = ConnectionPoolMetrics(
        poolId: 'test_pool',
        connectionCount: 10,
        activeConnections: 7,
        idleConnections: 3,
        activeRequests: 5,
        lastActivity: DateTime.now(),
        responseTime: 1500.0,
        isHealthy: true,
        additionalMetrics: {},
      );

      expect(metrics.utilizationPercentage, equals(70.0));
      expect(metrics.isHealthy, isTrue);
      expect(metrics.statusDescription, equals('moderate_load'));
    });

    test('ConnectionPoolMetrics should handle empty pool correctly', () {
      final metrics = ConnectionPoolMetrics.empty('empty_pool');

      expect(metrics.poolId, equals('empty_pool'));
      expect(metrics.connectionCount, equals(0));
      expect(metrics.activeConnections, equals(0));
      expect(metrics.utilizationPercentage, equals(0.0));
      expect(metrics.statusDescription, equals('idle'));
    });

    test('ConnectionPoolMetrics copyWith should work correctly', () {
      final original = ConnectionPoolMetrics.empty('test_pool');
      final updated = original.copyWith(
        activeConnections: 5,
        responseTime: 2000.0,
      );

      expect(updated.poolId, equals('test_pool'));
      expect(updated.activeConnections, equals(5));
      expect(updated.responseTime, equals(2000.0));
      expect(updated.connectionCount, equals(0)); // Should remain unchanged
    });

    test('ConnectionPoolMetrics should determine health status correctly', () {
      final now = DateTime.now();
      
      // Healthy pool
      final healthyMetrics = ConnectionPoolMetrics(
        poolId: 'healthy_pool',
        connectionCount: 5,
        activeConnections: 3,
        idleConnections: 2,
        activeRequests: 2,
        lastActivity: now,
        responseTime: 1000.0,
        isHealthy: true,
        additionalMetrics: {},
      );
      expect(healthyMetrics.isHealthy, isTrue);

      // Unhealthy pool (high response time)
      final unhealthyMetrics = ConnectionPoolMetrics(
        poolId: 'unhealthy_pool',
        connectionCount: 5,
        activeConnections: 3,
        idleConnections: 2,
        activeRequests: 2,
        lastActivity: now,
        responseTime: 35000.0, // 35 seconds
        isHealthy: false,
        additionalMetrics: {},
      );
      expect(unhealthyMetrics.isHealthy, isFalse);

      // Stale pool (no recent activity)
      final staleMetrics = ConnectionPoolMetrics(
        poolId: 'stale_pool',
        connectionCount: 5,
        activeConnections: 0,
        idleConnections: 5,
        activeRequests: 0,
        lastActivity: now.subtract(const Duration(minutes: 10)),
        responseTime: 1000.0,
        isHealthy: false,
        additionalMetrics: {},
      );
      expect(staleMetrics.isHealthy, isFalse);
    });

    test('ConnectionPoolMetrics should provide correct status descriptions', () {
      final now = DateTime.now();
      
      // Idle pool
      final idleMetrics = ConnectionPoolMetrics(
        poolId: 'idle_pool',
        connectionCount: 5,
        activeConnections: 0,
        idleConnections: 5,
        activeRequests: 0,
        lastActivity: now,
        responseTime: 1000.0,
        isHealthy: true,
        additionalMetrics: {},
      );
      expect(idleMetrics.statusDescription, equals('idle'));

      // Low load pool
      final lowLoadMetrics = ConnectionPoolMetrics(
        poolId: 'low_load_pool',
        connectionCount: 10,
        activeConnections: 3, // 30%
        idleConnections: 7,
        activeRequests: 2,
        lastActivity: now,
        responseTime: 1000.0,
        isHealthy: true,
        additionalMetrics: {},
      );
      expect(lowLoadMetrics.statusDescription, equals('low_load'));

      // Moderate load pool
      final moderateLoadMetrics = ConnectionPoolMetrics(
        poolId: 'moderate_load_pool',
        connectionCount: 10,
        activeConnections: 6, // 60%
        idleConnections: 4,
        activeRequests: 4,
        lastActivity: now,
        responseTime: 1000.0,
        isHealthy: true,
        additionalMetrics: {},
      );
      expect(moderateLoadMetrics.statusDescription, equals('moderate_load'));

      // High load pool
      final highLoadMetrics = ConnectionPoolMetrics(
        poolId: 'high_load_pool',
        connectionCount: 10,
        activeConnections: 9, // 90%
        idleConnections: 1,
        activeRequests: 8,
        lastActivity: now,
        responseTime: 1000.0,
        isHealthy: true,
        additionalMetrics: {},
      );
      expect(highLoadMetrics.statusDescription, equals('high_load'));
    });
  });
}