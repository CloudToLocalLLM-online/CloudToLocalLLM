/**
 * @fileoverview Integration test for the complete tunnel system
 * Tests the end-to-end functionality of the simplified tunnel system
 */

import { jest } from '@jest/globals';
import { TunnelProxy } from '../tunnel/tunnel-proxy.js';
import { MessageProtocol, MESSAGE_TYPES } from '../tunnel/message-protocol.js';
import { WebSocket } from 'ws';

describe('Tunnel System Integration', () => {
  let tunnelProxy;
  let mockLogger;

  beforeEach(() => {
    mockLogger = {
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
      debug: jest.fn()
    };

    tunnelProxy = new TunnelProxy(mockLogger);
  });

  afterEach(() => {
    tunnelProxy.cleanup();
  });

  describe('Complete Request/Response Flow', () => {
    it('should handle complete tunnel request flow', async () => {
      const userId = 'test-user-123';
      
      // Mock WebSocket
      const mockWebSocket = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };

      // Set up connection
      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
      expect(tunnelProxy.isUserConnected(userId)).toBe(true);

      // Prepare HTTP request
      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: { 'accept': 'application/json' }
      };

      // Start forwarding request (this will be async)
      const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);

      // Verify request was sent to WebSocket (should be the second call, first is welcome ping)
      expect(mockWebSocket.send).toHaveBeenCalledTimes(2);
      const sentMessage = JSON.parse(mockWebSocket.send.mock.calls[1][0]);
      expect(sentMessage.type).toBe(MESSAGE_TYPES.HTTP_REQUEST);
      expect(sentMessage.method).toBe('GET');
      expect(sentMessage.path).toBe('/api/models');

      // Simulate response from desktop client
      const responseMessage = MessageProtocol.createResponseMessage(sentMessage.id, {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"models": ["llama2", "codellama"]}'
      });

      // Simulate receiving the response
      const responseData = Buffer.from(MessageProtocol.serialize(responseMessage));
      tunnelProxy.handleMessage(connectionId, responseData);

      // Wait for response
      const httpResponse = await responsePromise;

      // Verify response
      expect(httpResponse.status).toBe(200);
      expect(httpResponse.headers['content-type']).toBe('application/json');
      expect(httpResponse.body).toBe('{"models": ["llama2", "codellama"]}');
    });

    it('should handle request timeout', async () => {
      const userId = 'test-user-123';
      
      // Mock WebSocket
      const mockWebSocket = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };

      // Set up connection
      tunnelProxy.handleConnection(mockWebSocket, userId);

      // Use fake timers for timeout testing
      jest.useFakeTimers();

      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: {}
      };

      // Start request
      const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);

      // Advance time by 30 seconds to trigger timeout
      jest.advanceTimersByTime(30000);

      // Should reject with timeout error
      await expect(responsePromise).rejects.toThrow('Request timeout');

      jest.useRealTimers();
    });

    it('should handle ping/pong health checks', () => {
      const userId = 'test-user-123';
      
      // Mock WebSocket
      const mockWebSocket = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };

      // Set up connection
      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);

      // Create and handle pong message
      const pingMessage = MessageProtocol.createPingMessage();
      const pongMessage = MessageProtocol.createPongMessage(pingMessage.id);
      const pongData = Buffer.from(MessageProtocol.serialize(pongMessage));

      tunnelProxy.handleMessage(connectionId, pongData);

      // Verify connection is still healthy
      expect(tunnelProxy.isUserConnected(userId)).toBe(true);
      
      const status = tunnelProxy.getUserConnectionStatus(userId);
      expect(status.connected).toBe(true);
      expect(status.lastPing).toBeInstanceOf(Date);
    });

    it('should handle error responses from desktop client', async () => {
      const userId = 'test-user-123';
      
      // Mock WebSocket
      const mockWebSocket = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };

      // Set up connection
      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);

      const httpRequest = {
        method: 'POST',
        path: '/api/chat',
        headers: { 'content-type': 'application/json' },
        body: '{"model": "invalid"}'
      };

      // Start request
      const responsePromise = tunnelProxy.forwardRequest(userId, httpRequest);

      // Get the sent request ID (should be the second call, first is welcome ping)
      const sentMessage = JSON.parse(mockWebSocket.send.mock.calls[1][0]);

      // Simulate error response from desktop client
      const errorMessage = MessageProtocol.createErrorMessage(
        sentMessage.id, 
        'Model not found', 
        404
      );

      const errorData = Buffer.from(MessageProtocol.serialize(errorMessage));
      tunnelProxy.handleMessage(connectionId, errorData);

      // Should reject with the error
      await expect(responsePromise).rejects.toThrow('Model not found');
    });

    it('should handle connection disconnection gracefully', () => {
      const userId = 'test-user-123';
      
      // Mock WebSocket
      const mockWebSocket = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };

      // Set up connection
      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);
      expect(tunnelProxy.isUserConnected(userId)).toBe(true);

      // Simulate disconnection
      tunnelProxy.handleDisconnection(connectionId);

      // Verify connection is cleaned up
      expect(tunnelProxy.isUserConnected(userId)).toBe(false);
      
      const status = tunnelProxy.getUserConnectionStatus(userId);
      expect(status.connected).toBe(false);
    });

    it('should maintain connection statistics', () => {
      const userId1 = 'user-1';
      const userId2 = 'user-2';
      
      // Mock WebSockets
      const mockWs1 = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };
      
      const mockWs2 = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };

      // Set up connections
      tunnelProxy.handleConnection(mockWs1, userId1);
      tunnelProxy.handleConnection(mockWs2, userId2);

      // Check stats
      const stats = tunnelProxy.getStats();
      expect(stats.totalConnections).toBe(2);
      expect(stats.connectedUsers).toBe(2);
      expect(stats.totalPendingRequests).toBe(0);
    });
  });

  describe('Message Protocol Validation', () => {
    it('should validate all message types correctly', () => {
      // Test request message
      const requestMessage = MessageProtocol.createRequestMessage({
        method: 'POST',
        path: '/api/generate',
        headers: { 'content-type': 'application/json' },
        body: '{"prompt": "Hello"}'
      });
      expect(MessageProtocol.validateTunnelMessage(requestMessage)).toBe(true);

      // Test response message
      const responseMessage = MessageProtocol.createResponseMessage('req-123', {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"response": "Hi there!"}'
      });
      expect(MessageProtocol.validateTunnelMessage(responseMessage)).toBe(true);

      // Test ping message
      const pingMessage = MessageProtocol.createPingMessage();
      expect(MessageProtocol.validateTunnelMessage(pingMessage)).toBe(true);

      // Test pong message
      const pongMessage = MessageProtocol.createPongMessage('ping-123');
      expect(MessageProtocol.validateTunnelMessage(pongMessage)).toBe(true);

      // Test error message
      const errorMessage = MessageProtocol.createErrorMessage('req-123', 'Connection failed', 500);
      expect(MessageProtocol.validateTunnelMessage(errorMessage)).toBe(true);
    });

    it('should handle message serialization/deserialization', () => {
      const originalMessage = MessageProtocol.createRequestMessage({
        method: 'GET',
        path: '/api/status',
        headers: { 'user-agent': 'CloudToLocalLLM/1.0' }
      });

      const serialized = MessageProtocol.serialize(originalMessage);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized).toEqual(originalMessage);
    });
  });

  describe('Error Handling', () => {
    it('should handle invalid JSON messages', () => {
      const userId = 'test-user-123';
      
      const mockWebSocket = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };

      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);

      // Send invalid JSON
      const invalidData = Buffer.from('invalid json');
      tunnelProxy.handleMessage(connectionId, invalidData);

      // Should log error but not crash
      expect(mockLogger.error).toHaveBeenCalled();
    });

    it('should handle unknown message types', () => {
      const userId = 'test-user-123';
      
      const mockWebSocket = {
        readyState: WebSocket.OPEN,
        send: jest.fn(),
        on: jest.fn(),
        close: jest.fn()
      };

      const connectionId = tunnelProxy.handleConnection(mockWebSocket, userId);

      // Send message with invalid format (this will trigger error handling)
      const invalidMessage = {
        type: 'http_request', // Valid type but missing required fields
        id: 'test-123'
        // Missing method and path
      };
      const messageData = Buffer.from(JSON.stringify(invalidMessage));
      tunnelProxy.handleMessage(connectionId, messageData);

      // Should log error but not crash
      expect(mockLogger.error).toHaveBeenCalled();
    });

    it('should reject requests when user not connected', async () => {
      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: {}
      };

      await expect(tunnelProxy.forwardRequest('unknown-user', httpRequest))
        .rejects.toThrow('Desktop client not connected');
    });
  });
});