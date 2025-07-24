/**
 * @fileoverview Load tests for tunnel system
 * Tests multiple concurrent users and high request volumes
 */

import { jest } from '@jest/globals';
import { WebSocket } from 'ws';
import winston from 'winston';
import { TunnelProxy } from '../tunnel/tunnel-proxy.js';
import { MessageProtocol, MESSAGE_TYPES } from '../tunnel/message-protocol.js';

// Mock WebSocket
jest.mock('ws');

describe('Tunnel Load Tests', () => {
  let tunnelProxy;
  let mockLogger;

  beforeEach(() => {
    // Create mock logger
    mockLogger = {
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
      debug: jest.fn(),
    };

    tunnelProxy = new TunnelProxy(mockLogger);
  });

  afterEach(() => {
    tunnelProxy.cleanup();
    jest.clearAllMocks();
  });

  describe('Multiple Concurrent Users', () => {
    it('should handle 100 concurrent user connections', () => {
      const userCount = 100;
      const connections = [];

      // Create connections for multiple users
      for (let i = 0; i < userCount; i++) {
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);

        connections.push({ connectionId, userId, mockWebSocket });
      }

      // Verify all connections are established
      expect(tunnelProxy.connections.size).toBe(userCount);
      expect(tunnelProxy.userConnections.size).toBe(userCount);

      // Verify stats
      const stats = tunnelProxy.getStats();
      expect(stats.totalConnections).toBe(userCount);
      expect(stats.connectedUsers).toBe(userCount);

      // Verify each user is connected
      for (const { userId } of connections) {
        expect(tunnelProxy.isUserConnected(userId)).toBe(true);
        const status = tunnelProxy.getUserConnectionStatus(userId);
        expect(status.connected).toBe(true);
      }
    });

    it('should handle user disconnections without affecting others', () => {
      const userCount = 50;
      const connections = [];

      // Create connections
      for (let i = 0; i < userCount; i++) {
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
        connections.push({ connectionId, userId, mockWebSocket });
      }

      expect(tunnelProxy.connections.size).toBe(userCount);

      // Disconnect every other user
      const disconnectedUsers = [];
      for (let i = 0; i < userCount; i += 2) {
        const { connectionId, userId } = connections[i];
        tunnelProxy.handleDisconnection(connectionId);
        disconnectedUsers.push(userId);
      }

      // Verify disconnected users are removed
      const remainingCount = userCount - disconnectedUsers.length;
      expect(tunnelProxy.connections.size).toBe(remainingCount);
      expect(tunnelProxy.userConnections.size).toBe(remainingCount);

      // Verify disconnected users are not connected
      for (const userId of disconnectedUsers) {
        expect(tunnelProxy.isUserConnected(userId)).toBe(false);
      }

      // Verify remaining users are still connected
      for (let i = 1; i < userCount; i += 2) {
        const { userId } = connections[i];
        expect(tunnelProxy.isUserConnected(userId)).toBe(true);
      }
    });

    it('should isolate requests between users', async() => {
      const userCount = 10;
      const connections = [];

      // Create connections for multiple users
      for (let i = 0; i < userCount; i++) {
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
        connections.push({ connectionId, userId, mockWebSocket });
      }

      // Send requests for each user
      const requestPromises = [];
      for (let i = 0; i < userCount; i++) {
        const { userId, mockWebSocket } = connections[i];

        const httpRequest = {
          method: 'GET',
          path: `/api/user-${i}/data`,
          headers: { 'user-id': userId },
        };

        // Mock response for this user
        const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);

        // Simulate response from desktop client
        setTimeout(() => {
          const connection = tunnelProxy.userConnections.get(userId);
          if (connection) {
            const pendingRequest = Array.from(connection.pendingRequests.values())[0];
            if (pendingRequest) {
              const httpResponse = {
                status: 200,
                headers: { 'content-type': 'application/json' },
                body: JSON.stringify({ userId, data: `user-${i}-data` }),
              };
              pendingRequest.resolve(httpResponse);
            }
          }
        }, 10 + i); // Stagger responses

        requestPromises.push(responsePromise);
      }

      // Wait for all responses
      const responses = await Promise.all(requestPromises);

      // Verify each user got their own response
      for (let i = 0; i < userCount; i++) {
        const response = responses[i];
        expect(response.status).toBe(200);

        const responseBody = JSON.parse(response.body);
        expect(responseBody.userId).toBe(`user-${i}`);
        expect(responseBody.data).toBe(`user-${i}-data`);
      }

      // Verify each user's WebSocket received exactly one message
      for (const { mockWebSocket } of connections) {
        expect(mockWebSocket.send).toHaveBeenCalledTimes(2); // Welcome ping + request
      }
    });
  });

  describe('High Request Volume', () => {
    it('should handle 1000 requests per user', async() => {
      const userCount = 5;
      const requestsPerUser = 1000;
      const connections = [];

      // Create connections
      for (let i = 0; i < userCount; i++) {
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `load-user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
        connections.push({ connectionId, userId, mockWebSocket });
      }

      // Send many requests for each user
      const allRequestPromises = [];

      for (let userIndex = 0; userIndex < userCount; userIndex++) {
        const { userId } = connections[userIndex];

        for (let reqIndex = 0; reqIndex < requestsPerUser; reqIndex++) {
          const httpRequest = {
            method: 'GET',
            path: `/api/request-${reqIndex}`,
            headers: { 'request-id': `${userId}-${reqIndex}` },
          };

          const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);
          allRequestPromises.push({ userId, reqIndex, promise: responsePromise });
        }
      }

      // Simulate responses for all requests
      setTimeout(() => {
        for (const { userId } of connections) {
          const connection = tunnelProxy.userConnections.get(userId);
          if (connection) {
            // Resolve all pending requests for this user
            for (const [requestId, pendingRequest] of connection.pendingRequests) {
              const httpResponse = {
                status: 200,
                headers: { 'content-type': 'application/json' },
                body: JSON.stringify({ requestId, result: 'success' }),
              };
              pendingRequest.resolve(httpResponse);
            }
          }
        }
      }, 100);

      // Wait for all responses
      const startTime = Date.now();
      const responses = await Promise.all(
        allRequestPromises.map(({ promise }) => promise),
      );
      const endTime = Date.now();

      // Verify all requests succeeded
      expect(responses).toHaveLength(userCount * requestsPerUser);
      for (const response of responses) {
        expect(response.status).toBe(200);
      }

      const totalRequests = userCount * requestsPerUser;
      const duration = endTime - startTime;
      const requestsPerSecond = (totalRequests / duration) * 1000;

      console.log(`Processed ${totalRequests} requests in ${duration}ms (${requestsPerSecond.toFixed(2)} req/s)`);

      // Should handle at least 100 requests per second
      expect(requestsPerSecond).toBeGreaterThan(100);
    });

    it('should handle rapid connection/disconnection cycles', () => {
      const cycleCount = 100;
      let totalConnections = 0;

      for (let i = 0; i < cycleCount; i++) {
        // Connect user
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `cycle-user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
        totalConnections++;

        expect(tunnelProxy.isUserConnected(userId)).toBe(true);

        // Immediately disconnect
        tunnelProxy.handleDisconnection(connectionId);
        expect(tunnelProxy.isUserConnected(userId)).toBe(false);
      }

      // Verify no connections remain
      expect(tunnelProxy.connections.size).toBe(0);
      expect(tunnelProxy.userConnections.size).toBe(0);

      // Verify stats
      const stats = tunnelProxy.getStats();
      expect(stats.totalConnections).toBe(0);
      expect(stats.connectedUsers).toBe(0);
    });

    it('should handle mixed request types under load', async() => {
      const userCount = 10;
      const requestsPerUser = 100;
      const connections = [];

      // Create connections
      for (let i = 0; i < userCount; i++) {
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `mixed-user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
        connections.push({ connectionId, userId, mockWebSocket });
      }

      // Send mixed request types
      const allRequestPromises = [];
      const methods = ['GET', 'POST', 'PUT', 'DELETE'];

      for (let userIndex = 0; userIndex < userCount; userIndex++) {
        const { userId } = connections[userIndex];

        for (let reqIndex = 0; reqIndex < requestsPerUser; reqIndex++) {
          const method = methods[reqIndex % methods.length];
          const httpRequest = {
            method,
            path: `/api/${method.toLowerCase()}-endpoint`,
            headers: { 'content-type': 'application/json' },
            body: method === 'POST' || method === 'PUT' ?
              JSON.stringify({ data: `request-${reqIndex}` }) : undefined,
          };

          const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);
          allRequestPromises.push({ userId, method, promise: responsePromise });
        }
      }

      // Simulate responses
      setTimeout(() => {
        for (const { userId } of connections) {
          const connection = tunnelProxy.userConnections.get(userId);
          if (connection) {
            for (const [requestId, pendingRequest] of connection.pendingRequests) {
              const httpResponse = {
                status: 200,
                headers: { 'content-type': 'application/json' },
                body: JSON.stringify({ requestId, method: 'processed' }),
              };
              pendingRequest.resolve(httpResponse);
            }
          }
        }
      }, 50);

      // Wait for all responses
      const responses = await Promise.all(
        allRequestPromises.map(({ promise }) => promise),
      );

      // Verify all requests succeeded
      expect(responses).toHaveLength(userCount * requestsPerUser);

      // Count requests by method
      const methodCounts = {};
      for (const { method } of allRequestPromises) {
        methodCounts[method] = (methodCounts[method] || 0) + 1;
      }

      // Verify even distribution of methods
      for (const method of methods) {
        expect(methodCounts[method]).toBe(userCount * (requestsPerUser / methods.length));
      }
    });
  });

  describe('Memory and Resource Management', () => {
    it('should clean up resources after user disconnection', () => {
      const userCount = 50;
      const connections = [];

      // Create connections with pending requests
      for (let i = 0; i < userCount; i++) {
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `cleanup-user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
        connections.push({ connectionId, userId, mockWebSocket });

        // Add pending requests
        const connection = tunnelProxy.connections.get(connectionId);
        for (let j = 0; j < 10; j++) {
          const requestId = `req-${i}-${j}`;
          const mockTimeout = setTimeout(() => {}, 30000);
          connection.pendingRequests.set(requestId, {
            id: requestId,
            timestamp: new Date(),
            timeout: mockTimeout,
            resolve: jest.fn(),
            reject: jest.fn(),
          });
        }
      }

      // Verify resources are allocated
      expect(tunnelProxy.connections.size).toBe(userCount);
      expect(tunnelProxy.userConnections.size).toBe(userCount);

      let totalPendingRequests = 0;
      for (const connection of tunnelProxy.connections.values()) {
        totalPendingRequests += connection.pendingRequests.size;
      }
      expect(totalPendingRequests).toBe(userCount * 10);

      // Disconnect all users
      for (const { connectionId } of connections) {
        tunnelProxy.handleDisconnection(connectionId);
      }

      // Verify all resources are cleaned up
      expect(tunnelProxy.connections.size).toBe(0);
      expect(tunnelProxy.userConnections.size).toBe(0);

      const stats = tunnelProxy.getStats();
      expect(stats.totalPendingRequests).toBe(0);
    });

    it('should handle memory pressure gracefully', () => {
      // Simulate memory pressure by creating many connections with large pending request maps
      const connectionCount = 1000;
      const pendingRequestsPerConnection = 100;

      for (let i = 0; i < connectionCount; i++) {
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `memory-user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);

        // Add many pending requests
        const connection = tunnelProxy.connections.get(connectionId);
        for (let j = 0; j < pendingRequestsPerConnection; j++) {
          const requestId = `memory-req-${i}-${j}`;
          const mockTimeout = setTimeout(() => {}, 30000);
          connection.pendingRequests.set(requestId, {
            id: requestId,
            timestamp: new Date(),
            timeout: mockTimeout,
            resolve: jest.fn(),
            reject: jest.fn(),
          });
        }
      }

      // Verify system can handle the load
      expect(tunnelProxy.connections.size).toBe(connectionCount);

      const stats = tunnelProxy.getStats();
      expect(stats.totalConnections).toBe(connectionCount);
      expect(stats.totalPendingRequests).toBe(connectionCount * pendingRequestsPerConnection);

      // System should still be responsive
      const newUserId = 'test-responsive-user';
      const newMockWebSocket = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn(),
      };

      const newConnectionId = tunnelProxy.handleConnection(newMockWebSocket, newUserId);
      expect(tunnelProxy.isUserConnected(newUserId)).toBe(true);

      // Clean up
      tunnelProxy.cleanup();
      expect(tunnelProxy.connections.size).toBe(0);
    });
  });

  describe('Performance Benchmarks', () => {
    it('should maintain low latency under load', async() => {
      const userCount = 20;
      const requestsPerUser = 50;
      const connections = [];
      const latencies = [];

      // Create connections
      for (let i = 0; i < userCount; i++) {
        const mockWebSocket = {
          readyState: WebSocket.OPEN,
          send: jest.fn(),
          on: jest.fn(),
          close: jest.fn(),
        };

        const userId = `perf-user-${i}`;
        const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
        connections.push({ connectionId, userId, mockWebSocket });
      }

      // Send requests and measure latency
      for (let userIndex = 0; userIndex < userCount; userIndex++) {
        const { userId } = connections[userIndex];

        for (let reqIndex = 0; reqIndex < requestsPerUser; reqIndex++) {
          const startTime = Date.now();

          const httpRequest = {
            method: 'GET',
            path: '/api/perf-test',
            headers: { 'request-index': reqIndex.toString() },
          };

          const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);

          // Simulate immediate response
          setTimeout(() => {
            const connection = tunnelProxy.userConnections.get(userId);
            if (connection && connection.pendingRequests.size > 0) {
              const pendingRequest = Array.from(connection.pendingRequests.values())[0];
              const httpResponse = {
                status: 200,
                headers: { 'content-type': 'application/json' },
                body: JSON.stringify({ result: 'ok' }),
              };
              pendingRequest.resolve(httpResponse);
            }
          }, 1);

          try {
            await responsePromise;
            const endTime = Date.now();
            latencies.push(endTime - startTime);
          } catch (error) {
            // Skip failed requests for latency calculation
          }
        }
      }

      // Analyze latencies
      const avgLatency = latencies.reduce((sum, lat) => sum + lat, 0) / latencies.length;
      const maxLatency = Math.max(...latencies);
      const minLatency = Math.min(...latencies);

      console.log(`Latency stats: avg=${avgLatency.toFixed(2)}ms, min=${minLatency}ms, max=${maxLatency}ms`);

      // Performance expectations
      expect(avgLatency).toBeLessThan(50); // Average latency under 50ms
      expect(maxLatency).toBeLessThan(200); // Max latency under 200ms
      expect(latencies.length).toBe(userCount * requestsPerUser); // All requests completed
    });

    it('should scale linearly with user count', async() => {
      const userCounts = [10, 50, 100];
      const requestsPerUser = 20;
      const results = [];

      for (const userCount of userCounts) {
        const connections = [];

        // Create connections
        for (let i = 0; i < userCount; i++) {
          const mockWebSocket = {
            readyState: WebSocket.OPEN,
            send: jest.fn(),
            on: jest.fn(),
            close: jest.fn(),
          };

          const userId = `scale-user-${i}`;
          const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
          connections.push({ connectionId, userId, mockWebSocket });
        }

        // Send requests and measure time
        const startTime = Date.now();
        const requestPromises = [];

        for (let userIndex = 0; userIndex < userCount; userIndex++) {
          const { userId } = connections[userIndex];

          for (let reqIndex = 0; reqIndex < requestsPerUser; reqIndex++) {
            const httpRequest = {
              method: 'GET',
              path: '/api/scale-test',
              headers: {},
            };

            const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);
            requestPromises.push(responsePromise);
          }
        }

        // Simulate responses
        setTimeout(() => {
          for (const { userId } of connections) {
            const connection = tunnelProxy.userConnections.get(userId);
            if (connection) {
              for (const [requestId, pendingRequest] of connection.pendingRequests) {
                const httpResponse = {
                  status: 200,
                  headers: { 'content-type': 'application/json' },
                  body: JSON.stringify({ result: 'ok' }),
                };
                pendingRequest.resolve(httpResponse);
              }
            }
          }
        }, 10);

        await Promise.all(requestPromises);
        const endTime = Date.now();

        const totalRequests = userCount * requestsPerUser;
        const duration = endTime - startTime;
        const throughput = (totalRequests / duration) * 1000;

        results.push({ userCount, totalRequests, duration, throughput });

        // Clean up for next iteration
        tunnelProxy.cleanup();
        tunnelProxy = new TunnelProxy(mockLogger);
      }

      // Analyze scaling
      console.log('Scaling results:');
      for (const result of results) {
        console.log(`${result.userCount} users: ${result.totalRequests} requests in ${result.duration}ms (${result.throughput.toFixed(2)} req/s)`);
      }

      // Verify throughput doesn't degrade significantly with more users
      const baseThroughput = results[0].throughput;
      for (let i = 1; i < results.length; i++) {
        const throughputRatio = results[i].throughput / baseThroughput;
        expect(throughputRatio).toBeGreaterThan(0.5); // Should maintain at least 50% of base throughput
      }
    });
  });
});
