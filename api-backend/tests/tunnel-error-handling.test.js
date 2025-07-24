/**
 * @fileoverview Tests for comprehensive error handling and logging in the tunnel system
 */

import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { WebSocket } from 'ws';
import { TunnelProxy } from '../tunnel/tunnel-proxy.js';
import { MessageProtocol, MESSAGE_TYPES } from '../tunnel/message-protocol.js';
import { TunnelLogger, ERROR_CODES, ErrorResponseBuilder } from '../utils/logger.js';

// Mock WebSocket for testing
class MockWebSocket extends WebSocket {
  constructor() {
    super(null);
    this.readyState = WebSocket.OPEN;
    this.messages = [];
  }

  send(data) {
    this.messages.push(data);
  }

  close(code, reason) {
    this.readyState = WebSocket.CLOSED;
    this.emit('close', code, reason);
  }

  simulateMessage(data) {
    this.emit('message', Buffer.from(data));
  }

  simulateError(error) {
    this.emit('error', error);
  }
}

describe('TunnelLogger', () => {
  let logger;

  beforeEach(() => {
    logger = new TunnelLogger('test-service');
  });

  describe('generateCorrelationId', () => {
    it('should generate unique correlation IDs', () => {
      const id1 = logger.generateCorrelationId();
      const id2 = logger.generateCorrelationId();

      expect(id1).toBeTruthy();
      expect(id2).toBeTruthy();
      expect(id1).not.toBe(id2);
    });
  });

  describe('hashUserId', () => {
    it('should hash user ID for privacy', () => {
      const userId = 'auth0|1234567890abcdef';
      const hashedId = logger.hashUserId(userId);

      expect(hashedId).toBeTruthy();
      expect(hashedId).toContain('auth0|12...');
      expect(hashedId).not.toBe(userId);
    });

    it('should handle null user ID', () => {
      const hashedId = logger.hashUserId(null);
      expect(hashedId).toBeNull();
    });
  });

  describe('structured logging', () => {
    it('should log info messages with context', () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();

      logger.info('Test message', {
        correlationId: 'test-correlation-id',
        userId: 'test-user',
        context: { key: 'value' },
      });

      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('should log errors with stack traces', () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();
      const error = new Error('Test error');

      logger.error('Test error message', error, {
        correlationId: 'test-correlation-id',
        userId: 'test-user',
      });

      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('should log tunnel errors with structured context', () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();

      logger.logTunnelError(
        ERROR_CODES.CONNECTION_LOST,
        'Connection lost',
        {
          correlationId: 'test-correlation-id',
          userId: 'test-user',
          connectionId: 'conn-123',
        },
      );

      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('should log performance metrics', () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();

      logger.logPerformance('test_operation', 500, {
        correlationId: 'test-correlation-id',
        userId: 'test-user',
      });

      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });
  });
});

describe('ErrorResponseBuilder', () => {
  describe('createErrorResponse', () => {
    it('should create standardized error response', () => {
      const response = ErrorResponseBuilder.createErrorResponse(
        ERROR_CODES.INVALID_REQUEST_FORMAT,
        'Invalid request',
        400,
        { field: 'method' },
      );

      expect(response.error.code).toBe(ERROR_CODES.INVALID_REQUEST_FORMAT);
      expect(response.error.message).toBe('Invalid request');
      expect(response.error.timestamp).toBeTruthy();
      expect(response.error.field).toBe('method');
    });
  });

  describe('specific error types', () => {
    it('should create authentication error', () => {
      const response = ErrorResponseBuilder.authenticationError(
        'Token expired',
        ERROR_CODES.AUTH_TOKEN_EXPIRED,
      );

      expect(response.error.code).toBe(ERROR_CODES.AUTH_TOKEN_EXPIRED);
      expect(response.error.message).toBe('Token expired');
    });

    it('should create service unavailable error', () => {
      const response = ErrorResponseBuilder.serviceUnavailableError(
        'Desktop client disconnected',
        ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED,
      );

      expect(response.error.code).toBe(ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED);
      expect(response.error.message).toBe('Desktop client disconnected');
    });

    it('should create gateway timeout error', () => {
      const response = ErrorResponseBuilder.gatewayTimeoutError(
        'Request timed out',
        ERROR_CODES.REQUEST_TIMEOUT,
      );

      expect(response.error.code).toBe(ERROR_CODES.REQUEST_TIMEOUT);
      expect(response.error.message).toBe('Request timed out');
    });

    it('should create bad request error', () => {
      const response = ErrorResponseBuilder.badRequestError(
        'Invalid format',
        ERROR_CODES.INVALID_REQUEST_FORMAT,
      );

      expect(response.error.code).toBe(ERROR_CODES.INVALID_REQUEST_FORMAT);
      expect(response.error.message).toBe('Invalid format');
    });

    it('should create internal server error', () => {
      const response = ErrorResponseBuilder.internalServerError(
        'Server error',
        ERROR_CODES.INTERNAL_SERVER_ERROR,
      );

      expect(response.error.code).toBe(ERROR_CODES.INTERNAL_SERVER_ERROR);
      expect(response.error.message).toBe('Server error');
    });
  });
});

describe('TunnelProxy Error Handling', () => {
  let tunnelProxy;
  let mockLogger;

  beforeEach(() => {
    mockLogger = new TunnelLogger('test-tunnel-proxy');
    tunnelProxy = new TunnelProxy(mockLogger);
  });

  afterEach(() => {
    tunnelProxy.cleanup();
  });

  describe('connection handling', () => {
    it('should handle new connection with logging', () => {
      const mockWs = new MockWebSocket();
      const userId = 'test-user-123';

      const connectionId = tunnelProxy.handleConnection(mockWs, userId);

      expect(connectionId).toBeTruthy();
      expect(tunnelProxy.isUserConnected(userId)).toBe(true);
    });

    it('should handle connection replacement', () => {
      const mockWs1 = new MockWebSocket();
      const mockWs2 = new MockWebSocket();
      const userId = 'test-user-123';

      const connectionId1 = tunnelProxy.handleConnection(mockWs1, userId);
      const connectionId2 = tunnelProxy.handleConnection(mockWs2, userId);

      expect(connectionId1).not.toBe(connectionId2);
      expect(tunnelProxy.isUserConnected(userId)).toBe(true);
    });

    it('should handle connection errors', () => {
      const mockWs = new MockWebSocket();
      const userId = 'test-user-123';

      const connectionId = tunnelProxy.handleConnection(mockWs, userId);

      // Simulate WebSocket error
      mockWs.simulateError(new Error('Connection error'));

      expect(tunnelProxy.isUserConnected(userId)).toBe(false);
    });
  });

  describe('message handling', () => {
    let mockWs;
    let userId;
    let connectionId;

    beforeEach(() => {
      mockWs = new MockWebSocket();
      userId = 'test-user-123';
      connectionId = tunnelProxy.handleConnection(mockWs, userId);
    });

    it('should handle valid HTTP response messages', () => {
      const requestId = 'req-123';
      const responseMessage = MessageProtocol.createResponseMessage(requestId, {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"result": "success"}',
      });

      // Set up a pending request
      const connection = tunnelProxy.connections.get(connectionId);
      const mockResolve = jest.fn();
      connection.pendingRequests.set(requestId, {
        id: requestId,
        timestamp: new Date(),
        timeout: setTimeout(() => {}, 1000),
        resolve: mockResolve,
        reject: jest.fn(),
      });

      mockWs.simulateMessage(MessageProtocol.serialize(responseMessage));

      expect(mockResolve).toHaveBeenCalled();
      expect(connection.pendingRequests.has(requestId)).toBe(false);
    });

    it('should handle pong messages', () => {
      const pingId = 'ping-123';
      const pongMessage = MessageProtocol.createPongMessage(pingId);

      mockWs.simulateMessage(MessageProtocol.serialize(pongMessage));

      // Should not throw and should update connection state
      const connection = tunnelProxy.connections.get(connectionId);
      expect(connection.lastPing).toBeTruthy();
    });

    it('should handle error messages', () => {
      const requestId = 'req-123';
      const errorMessage = MessageProtocol.createErrorMessage(
        requestId,
        'Request failed',
        500,
      );

      // Set up a pending request
      const connection = tunnelProxy.connections.get(connectionId);
      const mockReject = jest.fn();
      connection.pendingRequests.set(requestId, {
        id: requestId,
        timestamp: new Date(),
        timeout: setTimeout(() => {}, 1000),
        resolve: jest.fn(),
        reject: mockReject,
      });

      mockWs.simulateMessage(MessageProtocol.serialize(errorMessage));

      expect(mockReject).toHaveBeenCalled();
      expect(connection.pendingRequests.has(requestId)).toBe(false);
    });

    it('should handle invalid messages gracefully', () => {
      // Should not throw when receiving invalid JSON
      expect(() => {
        mockWs.simulateMessage('invalid json');
      }).not.toThrow();

      // Should not throw when receiving valid JSON but invalid message
      expect(() => {
        mockWs.simulateMessage('{"invalid": "message"}');
      }).not.toThrow();

      // Should not throw when receiving empty message
      expect(() => {
        mockWs.simulateMessage('');
      }).not.toThrow();
    });

    it('should handle responses for unknown requests', () => {
      const responseMessage = MessageProtocol.createResponseMessage('unknown-req', {
        status: 200,
        headers: {},
        body: 'OK',
      });

      // Should not throw when receiving response for unknown request
      expect(() => {
        mockWs.simulateMessage(MessageProtocol.serialize(responseMessage));
      }).not.toThrow();
    });
  });

  describe('request forwarding', () => {
    let mockWs;
    let userId;
    let connectionId;

    beforeEach(() => {
      mockWs = new MockWebSocket();
      userId = 'test-user-123';
      connectionId = tunnelProxy.handleConnection(mockWs, userId);
    });

    it('should forward requests to connected clients', async() => {
      const httpRequest = {
        method: 'GET',
        path: '/api/test',
        headers: { 'content-type': 'application/json' },
      };

      // Start the request (will timeout, but we can check it was sent)
      const requestPromise = tunnelProxy.forwardRequest(userId, httpRequest);

      // Check that message was sent
      expect(mockWs.messages.length).toBe(1);

      // Parse the sent message
      const sentMessage = JSON.parse(mockWs.messages[0]);
      expect(sentMessage.type).toBe(MESSAGE_TYPES.HTTP_REQUEST);
      expect(sentMessage.method).toBe('GET');
      expect(sentMessage.path).toBe('/api/test');

      // Clean up the pending request to avoid timeout
      const connection = tunnelProxy.connections.get(connectionId);
      for (const [requestId, pendingRequest] of connection.pendingRequests) {
        clearTimeout(pendingRequest.timeout);
        pendingRequest.reject(new Error('Test cleanup'));
      }
      connection.pendingRequests.clear();

      await expect(requestPromise).rejects.toThrow();
    });

    it('should reject requests for disconnected clients', async() => {
      // Disconnect the client
      mockWs.close();

      const httpRequest = {
        method: 'GET',
        path: '/api/test',
        headers: {},
      };

      await expect(tunnelProxy.forwardRequest(userId, httpRequest))
        .rejects.toThrow('Desktop client not connected');
    });

    it('should handle request timeout', async() => {
      // Mock a very short timeout for testing
      const originalTimeout = tunnelProxy.REQUEST_TIMEOUT;
      tunnelProxy.REQUEST_TIMEOUT = 10; // 10ms

      const httpRequest = {
        method: 'GET',
        path: '/api/test',
        headers: {},
      };

      await expect(tunnelProxy.forwardRequest(userId, httpRequest))
        .rejects.toThrow('Request timeout');

      // Restore original timeout
      tunnelProxy.REQUEST_TIMEOUT = originalTimeout;
    });

    it('should handle WebSocket send failures', async() => {
      // Mock WebSocket send to throw error
      mockWs.send = jest.fn().mockImplementation(() => {
        throw new Error('Send failed');
      });

      const httpRequest = {
        method: 'GET',
        path: '/api/test',
        headers: {},
      };

      await expect(tunnelProxy.forwardRequest(userId, httpRequest))
        .rejects.toThrow('Failed to send request');
    });
  });

  describe('connection cleanup', () => {
    it('should clean up pending requests on disconnection', () => {
      const mockWs = new MockWebSocket();
      const userId = 'test-user-123';
      const connectionId = tunnelProxy.handleConnection(mockWs, userId);

      // Add some pending requests
      const connection = tunnelProxy.connections.get(connectionId);
      const mockReject1 = jest.fn();
      const mockReject2 = jest.fn();

      connection.pendingRequests.set('req-1', {
        id: 'req-1',
        timestamp: new Date(),
        timeout: setTimeout(() => {}, 1000),
        resolve: jest.fn(),
        reject: mockReject1,
      });

      connection.pendingRequests.set('req-2', {
        id: 'req-2',
        timestamp: new Date(),
        timeout: setTimeout(() => {}, 1000),
        resolve: jest.fn(),
        reject: mockReject2,
      });

      // Simulate disconnection
      mockWs.close();

      expect(mockReject1).toHaveBeenCalled();
      expect(mockReject2).toHaveBeenCalled();
      expect(tunnelProxy.isUserConnected(userId)).toBe(false);
    });

    it('should stop ping intervals on disconnection', () => {
      const mockWs = new MockWebSocket();
      const userId = 'test-user-123';
      const connectionId = tunnelProxy.handleConnection(mockWs, userId);

      expect(tunnelProxy.pingIntervals.has(connectionId)).toBe(true);

      // Simulate disconnection
      mockWs.close();

      expect(tunnelProxy.pingIntervals.has(connectionId)).toBe(false);
    });
  });

  describe('health monitoring', () => {
    it('should send ping messages periodically', (done) => {
      const mockWs = new MockWebSocket();
      const userId = 'test-user-123';

      // Mock shorter ping interval for testing
      const originalInterval = tunnelProxy.PING_INTERVAL;
      tunnelProxy.PING_INTERVAL = 10; // 10ms

      const connectionId = tunnelProxy.handleConnection(mockWs, userId);

      setTimeout(() => {
        expect(mockWs.messages.length).toBeGreaterThan(0);

        // Check that ping message was sent
        const pingMessage = JSON.parse(mockWs.messages[mockWs.messages.length - 1]);
        expect(pingMessage.type).toBe(MESSAGE_TYPES.PING);

        // Restore original interval and cleanup
        tunnelProxy.PING_INTERVAL = originalInterval;
        tunnelProxy.cleanup();
        done();
      }, 50);
    });

    it('should handle pong timeout', (done) => {
      const mockWs = new MockWebSocket();
      const userId = 'test-user-123';

      // Mock very short timeouts for testing
      const originalPingInterval = tunnelProxy.PING_INTERVAL;
      const originalPongTimeout = tunnelProxy.PONG_TIMEOUT;
      tunnelProxy.PING_INTERVAL = 10; // 10ms
      tunnelProxy.PONG_TIMEOUT = 20; // 20ms

      const connectionId = tunnelProxy.handleConnection(mockWs, userId);

      setTimeout(() => {
        // Should have disconnected due to pong timeout
        expect(tunnelProxy.isUserConnected(userId)).toBe(false);

        // Restore original timeouts
        tunnelProxy.PING_INTERVAL = originalPingInterval;
        tunnelProxy.PONG_TIMEOUT = originalPongTimeout;
        done();
      }, 100);
    });
  });

  describe('metrics and statistics', () => {
    it('should track connection metrics', () => {
      const mockWs1 = new MockWebSocket();
      const mockWs2 = new MockWebSocket();
      const userId1 = 'user-1';
      const userId2 = 'user-2';

      tunnelProxy.handleConnection(mockWs1, userId1);
      tunnelProxy.handleConnection(mockWs2, userId2);

      const stats = tunnelProxy.getStats();
      expect(stats.connections.total).toBe(2);
      expect(stats.connections.connectedUsers).toBe(2);
    });

    it('should track request metrics', async() => {
      const mockWs = new MockWebSocket();
      const userId = 'test-user';
      tunnelProxy.handleConnection(mockWs, userId);

      // Simulate successful request
      tunnelProxy.metrics.totalRequests++;
      tunnelProxy.metrics.successfulRequests++;
      tunnelProxy.updateAverageResponseTime(100);

      // Simulate failed request
      tunnelProxy.metrics.totalRequests++;
      tunnelProxy.metrics.failedRequests++;

      const stats = tunnelProxy.getStats();
      expect(stats.requests.total).toBe(2);
      expect(stats.requests.successful).toBe(1);
      expect(stats.requests.failed).toBe(1);
      expect(stats.requests.successRate).toBe(50);
    });

    it('should provide health status', () => {
      const mockWs = new MockWebSocket();
      const userId = 'test-user';
      tunnelProxy.handleConnection(mockWs, userId);

      // Simulate good metrics
      tunnelProxy.metrics.totalRequests = 100;
      tunnelProxy.metrics.successfulRequests = 90;
      tunnelProxy.metrics.failedRequests = 10;

      const health = tunnelProxy.getHealthStatus();
      expect(health.status).toBe('healthy');
      expect(health.checks.hasConnections).toBe(true);
      expect(health.checks.successRateOk).toBe(true);
    });
  });
});

describe('MessageProtocol Error Handling', () => {
  describe('serialization', () => {
    it('should handle serialization errors', () => {
      const invalidMessage = {
        type: MESSAGE_TYPES.HTTP_REQUEST,
        // Missing required fields
      };

      expect(() => MessageProtocol.serialize(invalidMessage))
        .toThrow('Invalid tunnel message format');
    });

    it('should handle circular references', () => {
      const circularMessage = {
        type: MESSAGE_TYPES.HTTP_REQUEST,
        id: 'test-id',
        method: 'GET',
        path: '/test',
        headers: {},
      };
      circularMessage.circular = circularMessage;

      expect(() => MessageProtocol.serialize(circularMessage))
        .toThrow();
    });
  });

  describe('deserialization', () => {
    it('should handle invalid JSON', () => {
      expect(() => MessageProtocol.deserialize('invalid json'))
        .toThrow('Failed to parse JSON');
    });

    it('should handle empty string', () => {
      expect(() => MessageProtocol.deserialize(''))
        .toThrow('JSON string is required');
    });

    it('should handle null input', () => {
      expect(() => MessageProtocol.deserialize(null))
        .toThrow('JSON string is required');
    });

    it('should handle valid JSON but invalid message format', () => {
      expect(() => MessageProtocol.deserialize('{"invalid": "message"}'))
        .toThrow('Parsed message does not match tunnel message format');
    });
  });

  describe('validation', () => {
    it('should validate HTTP request format', () => {
      // Valid request
      const validRequest = {
        method: 'GET',
        path: '/api/test',
        headers: {},
      };
      expect(MessageProtocol.validateHttpRequest(validRequest)).toBe(true);

      // Invalid method
      const invalidMethod = {
        method: 'INVALID',
        path: '/api/test',
        headers: {},
      };
      expect(MessageProtocol.validateHttpRequest(invalidMethod)).toBe(false);

      // Missing path
      const missingPath = {
        method: 'GET',
        headers: {},
      };
      expect(MessageProtocol.validateHttpRequest(missingPath)).toBe(false);
    });

    it('should validate HTTP response format', () => {
      // Valid response
      const validResponse = {
        status: 200,
        headers: {},
        body: 'OK',
      };
      expect(MessageProtocol.validateHttpResponse(validResponse)).toBe(true);

      // Invalid status code
      const invalidStatus = {
        status: 99, // Invalid status code
        headers: {},
        body: 'OK',
      };
      expect(MessageProtocol.validateHttpResponse(invalidStatus)).toBe(false);

      // Missing status
      const missingStatus = {
        headers: {},
        body: 'OK',
      };
      expect(MessageProtocol.validateHttpResponse(missingStatus)).toBe(false);
    });

    it('should validate tunnel messages', () => {
      // Valid request message
      const validMessage = {
        type: MESSAGE_TYPES.HTTP_REQUEST,
        id: 'req-123',
        method: 'GET',
        path: '/api/test',
        headers: {},
      };
      expect(MessageProtocol.validateTunnelMessage(validMessage)).toBe(true);

      // Invalid type
      const invalidType = {
        type: 'INVALID_TYPE',
        id: 'req-123',
        method: 'GET',
        path: '/api/test',
        headers: {},
      };
      expect(MessageProtocol.validateTunnelMessage(invalidType)).toBe(false);

      // Missing ID
      const missingId = {
        type: MESSAGE_TYPES.HTTP_REQUEST,
        method: 'GET',
        path: '/api/test',
        headers: {},
      };
      expect(MessageProtocol.validateTunnelMessage(missingId)).toBe(false);
    });
  });
});
