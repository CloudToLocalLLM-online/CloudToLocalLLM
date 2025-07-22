/**
 * @fileoverview Unit tests for TunnelProxy service
 */

import { jest } from '@jest/globals';
import { WebSocket } from 'ws';
import winston from 'winston';
import { TunnelProxy } from '../tunnel/tunnel-proxy.js';
import { MessageProtocol, MESSAGE_TYPES } from '../tunnel/message-protocol.js';

// Mock WebSocket
jest.mock('ws');

describe('TunnelProxy', () => {
  let tunnelProxy;
  let mockLogger;
  let mockWebSocket;

  beforeEach(() => {
    // Create mock logger
    mockLogger = {
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
      debug: jest.fn()
    };

    // Create mock WebSocket
    mockWebSocket = {
      readyState: WebSocket.OPEN,
      send: jest.fn(),
      on: jest.fn(),
      close: jest.fn()
    };

    tunnelProxy = new TunnelProxy(mockLogger);
  });

  afterEach(() => {
    tunnelProxy.cleanup();
    jest.clearAllMocks();
  });

  describe('handleConnection', () => {
    it('should handle new WebSocket connection', () => {
      const userId = 'test-user-123';
      
      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
      
      expect(connectionId).toBeDefined();
      expect(typeof connectionId).toBe('string');
      expect(tunnelProxy.isUserConnected(userId)).toBe(true);
      expect(mockLogger.info).toHaveBeenCalledWith(
        expect.stringContaining(`New connection: ${connectionId} for user: ${userId}`)
      );
    });

    it('should set up WebSocket event handlers', () => {
      const userId = 'test-user-123';
      
      tunnelProxy.handleConnection(mockWebSocket, userId);
      
      expect(mockWebSocket.on).toHaveBeenCalledWith('message', expect.any(Function));
      expect(mockWebSocket.on).toHaveBeenCalledWith('close', expect.any(Function));
      expect(mockWebSocket.on).toHaveBeenCalledWith('error', expect.any(Function));
    });

    it('should send welcome ping message', () => {
      const userId = 'test-user-123';
      
      tunnelProxy.handleConnection(mockWebSocket, userId);
      
      expect(mockWebSocket.send).toHaveBeenCalledWith(
        expect.stringContaining('"type":"ping"')
      );
    });

    it('should store connection in both maps', () => {
      const userId = 'test-user-123';
      
      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
      
      expect(tunnelProxy.connections.has(connectionId)).toBe(true);
      expect(tunnelProxy.userConnections.has(userId)).toBe(true);
      
      const connection = tunnelProxy.connections.get(connectionId);
      expect(connection.userId).toBe(userId);
      expect(connection.websocket).toBe(mockWebSocket);
      expect(connection.isConnected).toBe(true);
    });
  });

  describe('handleMessage', () => {
    let connectionId;
    let userId;

    beforeEach(() => {
      userId = 'test-user-123';
      connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
    });

    it('should handle HTTP response message', () => {
      const requestId = 'test-request-123';
      const responseMessage = MessageProtocol.createResponseMessage(requestId, {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"result": "success"}'
      });

      // Set up pending request
      const connection = tunnelProxy.connections.get(connectionId);
      const mockResolve = jest.fn();
      const mockTimeout = setTimeout(() => {}, 1000);
      
      connection.pendingRequests.set(requestId, {
        id: requestId,
        timestamp: new Date(),
        timeout: mockTimeout,
        resolve: mockResolve,
        reject: jest.fn()
      });

      const messageData = Buffer.from(MessageProtocol.serialize(responseMessage));
      tunnelProxy.handleMessage(connectionId, messageData);

      expect(mockResolve).toHaveBeenCalledWith({
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"result": "success"}'
      });
      expect(connection.pendingRequests.has(requestId)).toBe(false);
    });

    it('should handle pong message', () => {
      const pongMessage = MessageProtocol.createPongMessage('ping-123');
      const messageData = Buffer.from(MessageProtocol.serialize(pongMessage));
      
      tunnelProxy.handleMessage(connectionId, messageData);
      
      const connection = tunnelProxy.connections.get(connectionId);
      expect(connection.lastPing).toBeInstanceOf(Date);
      expect(mockLogger.debug).toHaveBeenCalledWith(
        expect.stringContaining(`Pong received from ${connectionId}`)
      );
    });

    it('should handle error message', () => {
      const requestId = 'test-request-123';
      const errorMessage = MessageProtocol.createErrorMessage(requestId, 'Test error', 500);

      // Set up pending request
      const connection = tunnelProxy.connections.get(connectionId);
      const mockReject = jest.fn();
      const mockTimeout = setTimeout(() => {}, 1000);
      
      connection.pendingRequests.set(requestId, {
        id: requestId,
        timestamp: new Date(),
        timeout: mockTimeout,
        resolve: jest.fn(),
        reject: mockReject
      });

      const messageData = Buffer.from(MessageProtocol.serialize(errorMessage));
      tunnelProxy.handleMessage(connectionId, messageData);

      expect(mockReject).toHaveBeenCalledWith(expect.objectContaining({
        message: 'Test error',
        code: 500
      }));
      expect(connection.pendingRequests.has(requestId)).toBe(false);
    });

    it('should handle invalid JSON message', () => {
      const invalidData = Buffer.from('invalid json');
      
      tunnelProxy.handleMessage(connectionId, invalidData);
      
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.stringContaining(`Failed to process message from ${connectionId}`),
        expect.any(Error)
      );
    });

    it('should handle unknown message type', () => {
      const unknownMessage = {
        type: 'unknown_type',
        id: 'test-123'
      };
      const messageData = Buffer.from(JSON.stringify(unknownMessage));
      
      tunnelProxy.handleMessage(connectionId, messageData);
      
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.stringContaining(`Failed to process message from ${connectionId}`),
        expect.any(Error)
      );
    });
  });

  describe('forwardRequest', () => {
    let connectionId;
    let userId;

    beforeEach(() => {
      userId = 'test-user-123';
      connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
    });

    it('should forward HTTP request and return response', async () => {
      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: { 'accept': 'application/json' }
      };

      // Mock the response handling
      const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);

      // Simulate response from desktop client
      setTimeout(() => {
        const connection = tunnelProxy.connections.get(connectionId);
        const pendingRequest = Array.from(connection.pendingRequests.values())[0];
        
        if (pendingRequest) {
          const httpResponse = {
            status: 200,
            headers: { 'content-type': 'application/json' },
            body: '{"models": []}'
          };
          pendingRequest.resolve(httpResponse);
        }
      }, 10);

      const response = await responsePromise;
      
      expect(response).toEqual({
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"models": []}'
      });
      expect(mockWebSocket.send).toHaveBeenCalledWith(
        expect.stringContaining('"type":"http_request"')
      );
    });

    it('should reject when user not connected', async () => {
      const disconnectedUserId = 'disconnected-user';
      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: {}
      };

      await expect(tunnelProxy.forwardRequest(disconnectedUserId, httpRequest))
        .rejects.toThrow('Desktop client not connected');
    });

    it('should timeout after 30 seconds', async () => {
      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: {}
      };

      // Mock timeout by advancing timers
      jest.useFakeTimers();
      
      const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);
      
      // Advance time by 30 seconds
      jest.advanceTimersByTime(30000);
      
      await expect(responsePromise).rejects.toThrow('Request timeout');
      
      jest.useRealTimers();
    });

    it('should handle WebSocket send failure', async () => {
      mockWebSocket.send.mockImplementation(() => {
        throw new Error('WebSocket send failed');
      });

      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: {}
      };

      await expect(tunnelProxy.forwardRequest(userId, httpRequest))
        .rejects.toThrow('WebSocket send failed');
    });
  });

  describe('handleDisconnection', () => {
    let connectionId;
    let userId;

    beforeEach(() => {
      userId = 'test-user-123';
      connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
    });

    it('should clean up connection and pending requests', () => {
      // Add a pending request
      const connection = tunnelProxy.connections.get(connectionId);
      const mockReject = jest.fn();
      const mockTimeout = setTimeout(() => {}, 1000);
      
      connection.pendingRequests.set('test-request', {
        id: 'test-request',
        timestamp: new Date(),
        timeout: mockTimeout,
        resolve: jest.fn(),
        reject: mockReject
      });

      tunnelProxy.handleDisconnection(connectionId);

      expect(tunnelProxy.connections.has(connectionId)).toBe(false);
      expect(tunnelProxy.userConnections.has(userId)).toBe(false);
      expect(mockReject).toHaveBeenCalledWith(new Error('Connection closed'));
      expect(mockLogger.info).toHaveBeenCalledWith(
        expect.stringContaining(`Connection disconnected: ${connectionId}`)
      );
    });
  });

  describe('getUserConnectionStatus', () => {
    it('should return connected status for active user', () => {
      const userId = 'test-user-123';
      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
      
      const status = tunnelProxy.getUserConnectionStatus(userId);
      
      expect(status.connected).toBe(true);
      expect(status.lastPing).toBeInstanceOf(Date);
      expect(status.pendingRequests).toBe(0);
    });

    it('should return disconnected status for unknown user', () => {
      const status = tunnelProxy.getUserConnectionStatus('unknown-user');
      
      expect(status.connected).toBe(false);
    });
  });

  describe('getStats', () => {
    it('should return proxy statistics', () => {
      const userId1 = 'user-1';
      const userId2 = 'user-2';
      
      tunnelProxy.handleConnection(mockWebSocket, userId1);
      tunnelProxy.handleConnection({ ...mockWebSocket }, userId2);
      
      const stats = tunnelProxy.getStats();
      
      expect(stats.totalConnections).toBe(2);
      expect(stats.connectedUsers).toBe(2);
      expect(stats.totalPendingRequests).toBe(0);
    });
  });

  describe('cleanup', () => {
    it('should clean up all connections and intervals', () => {
      const userId = 'test-user-123';
      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
      
      tunnelProxy.cleanup();
      
      expect(tunnelProxy.connections.size).toBe(0);
      expect(tunnelProxy.userConnections.size).toBe(0);
      expect(tunnelProxy.pingIntervals.size).toBe(0);
      expect(mockWebSocket.close).toHaveBeenCalled();
    });
  });
});