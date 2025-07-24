/**
 * Performance tests for TunnelProxy
 * Tests connection pooling, message queuing, and performance monitoring
 */

import { describe, it, beforeEach, afterEach, expect } from '@jest/globals';
import { WebSocket } from 'ws';
import { TunnelProxy } from '../tunnel/tunnel-proxy.js';
import { TunnelLogger } from '../utils/logger.js';

// Mock WebSocket for testing
class MockWebSocket {
  constructor() {
    this.readyState = WebSocket.OPEN;
    this.messages = [];
    this.closeCode = null;
  }

  send(data) {
    this.messages.push(data);
  }

  close(code) {
    this.readyState = WebSocket.CLOSED;
    this.closeCode = code;
  }
}

describe('TunnelProxy Performance Tests', () => {
  let tunnelProxy;
  let logger;

  beforeEach(() => {
    logger = new TunnelLogger('test');
    tunnelProxy = new TunnelProxy(logger);
  });

  afterEach(() => {
    tunnelProxy.cleanup();
  });

  describe('Performance Metrics', () => {
    it('should track basic performance metrics', async() => {
      const stats = tunnelProxy.getStats();

      expect(stats.connections.total).toBe(0);
      expect(stats.requests.total).toBe(0);
      expect(stats.requests.successful).toBe(0);
      expect(stats.requests.failed).toBe(0);
      expect(stats.performance.averageResponseTime).toBe(0);
    });

    it('should calculate response time percentiles', async() => {
      // Simulate response times
      const responseTimes = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

      for (const time of responseTimes) {
        tunnelProxy.updateAverageResponseTime(time);
        tunnelProxy.metrics.successfulRequests++;
      }

      const performanceMetrics = tunnelProxy.getPerformanceMetrics();

      expect(performanceMetrics.enhanced.p95ResponseTime).toBeGreaterThan(0);
      expect(performanceMetrics.enhanced.p99ResponseTime).toBeGreaterThan(0);
      expect(performanceMetrics.performance.averageResponseTime).toBeGreaterThan(0);
    });

    it('should track throughput correctly', async() => {
      // Simulate requests over time
      for (let i = 0; i < 20; i++) {
        tunnelProxy.metrics.requestTimestamps.push(new Date());
        tunnelProxy.updateAverageResponseTime(100);
        tunnelProxy.metrics.successfulRequests++;
      }

      const performanceMetrics = tunnelProxy.getPerformanceMetrics();
      expect(performanceMetrics.enhanced.throughputPerMinute).toBeGreaterThan(0);
    });

    it('should track memory usage', async() => {
      tunnelProxy.updateMemoryUsage();

      const performanceMetrics = tunnelProxy.getPerformanceMetrics();
      expect(performanceMetrics.enhanced.memoryUsageMB).toBeGreaterThan(0);
      expect(performanceMetrics.enhanced.peakMemoryUsageMB).toBeGreaterThanOrEqual(
        performanceMetrics.enhanced.memoryUsageMB,
      );
    });
  });

  describe('Performance Alerts', () => {
    it('should detect low success rate', async() => {
      // Simulate low success rate
      tunnelProxy.metrics.totalRequests = 100;
      tunnelProxy.metrics.successfulRequests = 70; // 70% success rate
      tunnelProxy.metrics.failedRequests = 30;

      tunnelProxy.checkPerformanceAlerts();

      expect(tunnelProxy.performanceAlerts.length).toBeGreaterThan(0);
      expect(tunnelProxy.performanceAlerts.some(alert =>
        alert.type === 'LOW_SUCCESS_RATE',
      )).toBe(true);
    });

    it('should detect high timeout rate', async() => {
      // Simulate high timeout rate
      tunnelProxy.metrics.totalRequests = 100;
      tunnelProxy.metrics.timeoutRequests = 25; // 25% timeout rate
      tunnelProxy.metrics.failedRequests = 25;

      tunnelProxy.checkPerformanceAlerts();

      expect(tunnelProxy.performanceAlerts.some(alert =>
        alert.type === 'HIGH_TIMEOUT_RATE',
      )).toBe(true);
    });

    it('should detect high response time', async() => {
      // Simulate high response time
      tunnelProxy.metrics.averageResponseTime = 6000; // 6 seconds

      tunnelProxy.checkPerformanceAlerts();

      expect(tunnelProxy.performanceAlerts.some(alert =>
        alert.type === 'HIGH_RESPONSE_TIME',
      )).toBe(true);
    });

    it('should detect high memory usage', async() => {
      // Simulate high memory usage
      tunnelProxy.metrics.memoryUsage = 150 * 1024 * 1024; // 150MB

      tunnelProxy.checkPerformanceAlerts();

      expect(tunnelProxy.performanceAlerts.some(alert =>
        alert.type === 'HIGH_MEMORY_USAGE',
      )).toBe(true);
    });

    it('should clear alerts when performance improves', async() => {
      // First, create alerts
      tunnelProxy.metrics.totalRequests = 100;
      tunnelProxy.metrics.successfulRequests = 70;
      tunnelProxy.metrics.failedRequests = 30;
      tunnelProxy.checkPerformanceAlerts();

      expect(tunnelProxy.performanceAlerts.length).toBeGreaterThan(0);

      // Then improve performance
      tunnelProxy.metrics.successfulRequests = 95;
      tunnelProxy.metrics.failedRequests = 5;
      tunnelProxy.checkPerformanceAlerts();

      expect(tunnelProxy.performanceAlerts.length).toBe(0);
    });
  });

  describe('Connection Pool Performance', () => {
    it('should track connection pool efficiency', async() => {
      // Simulate pool operations
      tunnelProxy.metrics.connectionPoolHits = 80;
      tunnelProxy.metrics.connectionPoolMisses = 20;

      const performanceMetrics = tunnelProxy.getPerformanceMetrics();
      expect(performanceMetrics.enhanced.connectionPoolStats.poolEfficiency).toBe(80);
    });

    it('should clean up stale connections from pool', async() => {
      const userId = 'test-user';
      const staleConnection = new MockWebSocket();
      staleConnection.readyState = WebSocket.CLOSED;

      const activeConnection = new MockWebSocket();

      tunnelProxy.connectionPool.set(userId, [staleConnection, activeConnection]);

      tunnelProxy.cleanupConnectionPool();

      const remainingConnections = tunnelProxy.connectionPool.get(userId);
      expect(remainingConnections.length).toBe(1);
      expect(remainingConnections[0]).toBe(activeConnection);
    });
  });

  describe('Load Testing', () => {
    it('should handle high connection count', async() => {
      const connectionCount = 100;
      const connections = [];

      // Create many connections
      for (let i = 0; i < connectionCount; i++) {
        const ws = new MockWebSocket();
        const userId = `user-${i}`;
        const connectionId = tunnelProxy.handleConnection(ws, userId);
        connections.push({ connectionId, userId, ws });
      }

      expect(tunnelProxy.connections.size).toBe(connectionCount);
      expect(tunnelProxy.userConnections.size).toBe(connectionCount);

      // Clean up
      for (const { connectionId } of connections) {
        tunnelProxy.handleDisconnection(connectionId);
      }
    });

    it('should handle high request volume', async() => {
      const ws = new MockWebSocket();
      const userId = 'test-user';
      const connectionId = tunnelProxy.handleConnection(ws, userId);

      const requestCount = 1000;
      const requests = [];

      // Create many concurrent requests
      for (let i = 0; i < requestCount; i++) {
        const request = tunnelProxy.forwardRequest(userId, {
          method: 'GET',
          path: `/test/${i}`,
          headers: { 'content-type': 'application/json' },
        }).catch(() => {}); // Ignore timeout errors for this test

        requests.push(request);
      }

      const connection = tunnelProxy.connections.get(connectionId);
      expect(connection.pendingRequests.size).toBe(requestCount);

      // Clean up
      tunnelProxy.handleDisconnection(connectionId);
      await Promise.allSettled(requests);
    });

    it('should maintain performance under sustained load', async() => {
      const ws = new MockWebSocket();
      const userId = 'test-user';
      const connectionId = tunnelProxy.handleConnection(ws, userId);

      const startTime = Date.now();
      const duration = 1000; // 1 second
      let requestCount = 0;

      // Sustained load test
      while (Date.now() - startTime < duration) {
        try {
          tunnelProxy.forwardRequest(userId, {
            method: 'GET',
            path: `/test/${requestCount}`,
            headers: { 'content-type': 'application/json' },
          }).catch(() => {}); // Ignore timeout errors

          requestCount++;

          // Small delay to prevent overwhelming
          await new Promise(resolve => setTimeout(resolve, 1));
        } catch (error) {
          // Continue on errors
        }
      }

      expect(requestCount).toBeGreaterThan(0);

      const stats = tunnelProxy.getStats();
      expect(stats.requests.total).toBeGreaterThan(0);

      // Clean up
      tunnelProxy.handleDisconnection(connectionId);
    });
  });

  describe('Memory Management', () => {
    it('should track memory usage accurately', async() => {
      // Create connections and requests to increase memory usage
      const connections = [];
      for (let i = 0; i < 10; i++) {
        const ws = new MockWebSocket();
        const userId = `user-${i}`;
        const connectionId = tunnelProxy.handleConnection(ws, userId);
        connections.push({ connectionId, userId });

        // Add pending requests
        for (let j = 0; j < 5; j++) {
          tunnelProxy.forwardRequest(userId, {
            method: 'GET',
            path: `/test/${j}`,
            headers: {},
          }).catch(() => {});
        }
      }

      tunnelProxy.updateMemoryUsage();

      const performanceMetrics = tunnelProxy.getPerformanceMetrics();
      expect(performanceMetrics.enhanced.memoryUsageMB).toBeGreaterThan(5); // Should have some memory usage

      // Clean up
      for (const { connectionId } of connections) {
        tunnelProxy.handleDisconnection(connectionId);
      }
    });

    it('should handle memory pressure gracefully', async() => {
      // Simulate high memory usage
      tunnelProxy.metrics.memoryUsage = 200 * 1024 * 1024; // 200MB

      tunnelProxy.checkPerformanceAlerts();

      expect(tunnelProxy.performanceAlerts.some(alert =>
        alert.type === 'HIGH_MEMORY_USAGE',
      )).toBe(true);
    });
  });

  describe('Health Status', () => {
    it('should report healthy status with good performance', async() => {
      // Set up good performance metrics
      tunnelProxy.metrics.totalRequests = 100;
      tunnelProxy.metrics.successfulRequests = 95;
      tunnelProxy.metrics.failedRequests = 5;
      tunnelProxy.metrics.averageResponseTime = 200;

      // Add a connection
      const ws = new MockWebSocket();
      tunnelProxy.handleConnection(ws, 'test-user');

      const healthStatus = tunnelProxy.getHealthStatus();

      expect(healthStatus.status).toBe('healthy');
      expect(healthStatus.checks.hasConnections).toBe(true);
      expect(healthStatus.checks.successRateOk).toBe(true);
      expect(healthStatus.checks.averageResponseTimeOk).toBe(true);
    });

    it('should report degraded status with poor performance', async() => {
      // Set up poor performance metrics
      tunnelProxy.metrics.totalRequests = 100;
      tunnelProxy.metrics.successfulRequests = 70; // 70% success rate
      tunnelProxy.metrics.failedRequests = 30;
      tunnelProxy.metrics.averageResponseTime = 6000; // 6 seconds

      const healthStatus = tunnelProxy.getHealthStatus();

      expect(healthStatus.status).toBe('degraded');
      expect(healthStatus.checks.successRateOk).toBe(false);
      expect(healthStatus.checks.averageResponseTimeOk).toBe(false);
    });
  });

  describe('Benchmarks', () => {
    it('should handle message processing efficiently', async() => {
      const messageCount = 10000;
      const startTime = Date.now();

      // Process many messages
      for (let i = 0; i < messageCount; i++) {
        tunnelProxy.updateAverageResponseTime(100 + Math.random() * 200);
        tunnelProxy.metrics.successfulRequests++;
      }

      const endTime = Date.now();
      const processingTime = endTime - startTime;
      const messagesPerSecond = messageCount / (processingTime / 1000);

      expect(messagesPerSecond).toBeGreaterThan(1000); // Should process at least 1000 messages/second

      console.log(`Processed ${messageCount} messages in ${processingTime}ms (${messagesPerSecond.toFixed(0)} msg/sec)`);
    });

    it('should calculate statistics efficiently', async() => {
      // Add many data points
      for (let i = 0; i < 10000; i++) {
        tunnelProxy.updateAverageResponseTime(50 + Math.random() * 200);
        tunnelProxy.metrics.successfulRequests++;
      }

      const startTime = Date.now();
      const stats = tunnelProxy.getPerformanceMetrics();
      const endTime = Date.now();

      const calculationTime = endTime - startTime;
      expect(calculationTime).toBeLessThan(100); // Should calculate stats in less than 100ms
      expect(stats.requests.total).toBe(10000);

      console.log(`Statistics calculation time: ${calculationTime}ms`);
    });
  });
});
