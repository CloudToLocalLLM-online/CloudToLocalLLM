/**
 * @fileoverview Basic integration tests for tunnel system
 */

import { jest } from '@jest/globals';
import { TunnelProxy } from '../tunnel/tunnel-proxy.js';
import { MessageProtocol, MESSAGE_TYPES } from '../tunnel/message-protocol.js';

describe('Tunnel Integration', () => {
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

  describe('TunnelProxy Core Functionality', () => {
    it('should create tunnel proxy instance', () => {
      expect(tunnelProxy).toBeDefined();
      expect(tunnelProxy.connections).toBeInstanceOf(Map);
      expect(tunnelProxy.userConnections).toBeInstanceOf(Map);
    });

    it('should return correct stats for empty proxy', () => {
      const stats = tunnelProxy.getStats();
      
      expect(stats).toEqual({
        totalConnections: 0,
        totalPendingRequests: 0,
        connectedUsers: 0
      });
    });

    it('should return disconnected status for unknown user', () => {
      const status = tunnelProxy.getUserConnectionStatus('unknown-user');
      
      expect(status).toEqual({
        connected: false
      });
    });

    it('should check user connection status correctly', () => {
      expect(tunnelProxy.isUserConnected('unknown-user')).toBe(false);
    });
  });

  describe('Message Protocol', () => {
    it('should create valid request message', () => {
      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: { 'accept': 'application/json' }
      };

      const message = MessageProtocol.createRequestMessage(httpRequest);

      expect(message.type).toBe(MESSAGE_TYPES.HTTP_REQUEST);
      expect(message.method).toBe('GET');
      expect(message.path).toBe('/api/models');
      expect(message.headers).toEqual({ 'accept': 'application/json' });
      expect(message.id).toBeDefined();
    });

    it('should create valid response message', () => {
      const requestId = 'test-123';
      const httpResponse = {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"success": true}'
      };

      const message = MessageProtocol.createResponseMessage(requestId, httpResponse);

      expect(message.type).toBe(MESSAGE_TYPES.HTTP_RESPONSE);
      expect(message.id).toBe(requestId);
      expect(message.status).toBe(200);
      expect(message.headers).toEqual({ 'content-type': 'application/json' });
      expect(message.body).toBe('{"success": true}');
    });

    it('should create valid ping message', () => {
      const message = MessageProtocol.createPingMessage();

      expect(message.type).toBe(MESSAGE_TYPES.PING);
      expect(message.id).toBeDefined();
      expect(message.timestamp).toBeDefined();
    });

    it('should create valid pong message', () => {
      const pingId = 'ping-123';
      const message = MessageProtocol.createPongMessage(pingId);

      expect(message.type).toBe(MESSAGE_TYPES.PONG);
      expect(message.id).toBe(pingId);
      expect(message.timestamp).toBeDefined();
    });

    it('should create valid error message', () => {
      const requestId = 'req-123';
      const error = 'Test error';
      const code = 500;

      const message = MessageProtocol.createErrorMessage(requestId, error, code);

      expect(message.type).toBe(MESSAGE_TYPES.ERROR);
      expect(message.id).toBe(requestId);
      expect(message.error).toBe(error);
      expect(message.code).toBe(code);
    });

    it('should serialize and deserialize messages correctly', () => {
      const originalMessage = MessageProtocol.createPingMessage();
      const serialized = MessageProtocol.serialize(originalMessage);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized).toEqual(originalMessage);
    });

    it('should validate HTTP requests correctly', () => {
      const validRequest = {
        method: 'POST',
        path: '/api/chat',
        headers: { 'content-type': 'application/json' },
        body: '{"message": "hello"}'
      };

      expect(MessageProtocol.validateHttpRequest(validRequest)).toBe(true);

      const invalidRequest = {
        method: 'INVALID',
        path: '/api/chat'
      };

      expect(MessageProtocol.validateHttpRequest(invalidRequest)).toBe(false);
    });

    it('should validate HTTP responses correctly', () => {
      const validResponse = {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"result": "success"}'
      };

      expect(MessageProtocol.validateHttpResponse(validResponse)).toBe(true);

      const invalidResponse = {
        status: 999, // Invalid status code
        headers: { 'content-type': 'application/json' },
        body: '{"result": "success"}'
      };

      expect(MessageProtocol.validateHttpResponse(invalidResponse)).toBe(false);
    });

    it('should extract HTTP request from tunnel message', () => {
      const httpRequest = {
        method: 'GET',
        path: '/api/models',
        headers: { 'accept': 'application/json' }
      };

      const tunnelMessage = MessageProtocol.createRequestMessage(httpRequest);
      const extracted = MessageProtocol.extractHttpRequest(tunnelMessage);

      expect(extracted).toEqual(httpRequest);
    });

    it('should extract HTTP response from tunnel message', () => {
      const httpResponse = {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"success": true}'
      };

      const tunnelMessage = MessageProtocol.createResponseMessage('req-123', httpResponse);
      const extracted = MessageProtocol.extractHttpResponse(tunnelMessage);

      expect(extracted).toEqual(httpResponse);
    });
  });

  describe('Error Handling', () => {
    it('should handle invalid message serialization', () => {
      const invalidMessage = { type: 'invalid' };

      expect(() => {
        MessageProtocol.serialize(invalidMessage);
      }).toThrow('Invalid tunnel message format');
    });

    it('should handle invalid JSON deserialization', () => {
      expect(() => {
        MessageProtocol.deserialize('invalid json');
      }).toThrow('Failed to parse JSON');
    });

    it('should handle missing required fields in HTTP request', () => {
      const invalidRequest = { method: 'GET' }; // Missing path

      expect(() => {
        MessageProtocol.createRequestMessage(invalidRequest);
      }).toThrow('Invalid HTTP request format');
    });

    it('should handle missing required fields in HTTP response', () => {
      const invalidResponse = { headers: {} }; // Missing status

      expect(() => {
        MessageProtocol.createResponseMessage('req-123', invalidResponse);
      }).toThrow('Invalid HTTP response format');
    });
  });
});