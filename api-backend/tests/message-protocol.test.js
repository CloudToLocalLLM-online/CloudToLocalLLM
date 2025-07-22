/**
 * @fileoverview Unit tests for the tunnel message protocol
 * Tests message serialization, deserialization, validation, and edge cases
 */

import { describe, test, expect, beforeEach } from '@jest/globals';
import { MessageProtocol, MESSAGE_TYPES, HTTP_METHODS } from '../tunnel/message-protocol.js';

describe('MessageProtocol', () => {
  describe('createRequestMessage', () => {
    test('should create valid request message from HTTP request', () => {
      const httpRequest = {
        method: 'POST',
        path: '/api/chat',
        headers: { 'content-type': 'application/json' },
        body: '{"message": "hello"}'
      };

      const message = MessageProtocol.createRequestMessage(httpRequest);

      expect(message.type).toBe(MESSAGE_TYPES.HTTP_REQUEST);
      expect(message.id).toBeDefined();
      expect(message.method).toBe('POST');
      expect(message.path).toBe('/api/chat');
      expect(message.headers).toEqual({ 'content-type': 'application/json' });
      expect(message.body).toBe('{"message": "hello"}');
    });

    test('should create request message without body', () => {
      const httpRequest = {
        method: 'GET',
        path: '/api/status',
        headers: {}
      };

      const message = MessageProtocol.createRequestMessage(httpRequest);

      expect(message.type).toBe(MESSAGE_TYPES.HTTP_REQUEST);
      expect(message.method).toBe('GET');
      expect(message.path).toBe('/api/status');
      expect(message.body).toBeUndefined();
    });

    test('should throw error for invalid HTTP request', () => {
      const invalidRequest = {
        method: 'INVALID',
        path: '/api/test'
      };

      expect(() => MessageProtocol.createRequestMessage(invalidRequest))
        .toThrow('Invalid HTTP request format');
    });

    test('should throw error for missing required fields', () => {
      const incompleteRequest = {
        method: 'GET'
        // missing path
      };

      expect(() => MessageProtocol.createRequestMessage(incompleteRequest))
        .toThrow('Invalid HTTP request format');
    });
  });

  describe('createResponseMessage', () => {
    test('should create valid response message', () => {
      const requestId = 'test-request-id';
      const httpResponse = {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"result": "success"}'
      };

      const message = MessageProtocol.createResponseMessage(requestId, httpResponse);

      expect(message.type).toBe(MESSAGE_TYPES.HTTP_RESPONSE);
      expect(message.id).toBe(requestId);
      expect(message.status).toBe(200);
      expect(message.headers).toEqual({ 'content-type': 'application/json' });
      expect(message.body).toBe('{"result": "success"}');
    });

    test('should throw error for invalid request ID', () => {
      const httpResponse = {
        status: 200,
        headers: {},
        body: 'OK'
      };

      expect(() => MessageProtocol.createResponseMessage('', httpResponse))
        .toThrow('Request ID is required and must be a string');

      expect(() => MessageProtocol.createResponseMessage(null, httpResponse))
        .toThrow('Request ID is required and must be a string');
    });

    test('should throw error for invalid HTTP response', () => {
      const invalidResponse = {
        status: 999, // invalid status code
        headers: {},
        body: 'test'
      };

      expect(() => MessageProtocol.createResponseMessage('test-id', invalidResponse))
        .toThrow('Invalid HTTP response format');
    });
  });

  describe('createPingMessage', () => {
    test('should create valid ping message', () => {
      const message = MessageProtocol.createPingMessage();

      expect(message.type).toBe(MESSAGE_TYPES.PING);
      expect(message.id).toBeDefined();
      expect(message.timestamp).toBeDefined();
      expect(new Date(message.timestamp)).toBeInstanceOf(Date);
    });
  });

  describe('createPongMessage', () => {
    test('should create valid pong message', () => {
      const pingId = 'ping-123';
      const message = MessageProtocol.createPongMessage(pingId);

      expect(message.type).toBe(MESSAGE_TYPES.PONG);
      expect(message.id).toBe(pingId);
      expect(message.timestamp).toBeDefined();
      expect(new Date(message.timestamp)).toBeInstanceOf(Date);
    });

    test('should throw error for invalid ping ID', () => {
      expect(() => MessageProtocol.createPongMessage(''))
        .toThrow('Ping ID is required and must be a string');

      expect(() => MessageProtocol.createPongMessage(null))
        .toThrow('Ping ID is required and must be a string');
    });
  });

  describe('createErrorMessage', () => {
    test('should create valid error message', () => {
      const requestId = 'req-123';
      const error = 'Connection failed';
      const code = 500;

      const message = MessageProtocol.createErrorMessage(requestId, error, code);

      expect(message.type).toBe(MESSAGE_TYPES.ERROR);
      expect(message.id).toBe(requestId);
      expect(message.error).toBe(error);
      expect(message.code).toBe(code);
    });

    test('should create error message without code', () => {
      const requestId = 'req-123';
      const error = 'Connection failed';

      const message = MessageProtocol.createErrorMessage(requestId, error);

      expect(message.type).toBe(MESSAGE_TYPES.ERROR);
      expect(message.id).toBe(requestId);
      expect(message.error).toBe(error);
      expect(message.code).toBeUndefined();
    });

    test('should throw error for invalid parameters', () => {
      expect(() => MessageProtocol.createErrorMessage('', 'error'))
        .toThrow('Request ID is required and must be a string');

      expect(() => MessageProtocol.createErrorMessage('req-123', ''))
        .toThrow('Error message is required and must be a string');
    });
  });

  describe('serialize and deserialize', () => {
    test('should serialize and deserialize request message', () => {
      const original = MessageProtocol.createRequestMessage({
        method: 'POST',
        path: '/api/test',
        headers: { 'content-type': 'application/json' },
        body: '{"test": true}'
      });

      const serialized = MessageProtocol.serialize(original);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized).toEqual(original);
    });

    test('should serialize and deserialize response message', () => {
      const original = MessageProtocol.createResponseMessage('req-123', {
        status: 200,
        headers: { 'content-type': 'text/plain' },
        body: 'OK'
      });

      const serialized = MessageProtocol.serialize(original);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized).toEqual(original);
    });

    test('should serialize and deserialize ping message', () => {
      const original = MessageProtocol.createPingMessage();

      const serialized = MessageProtocol.serialize(original);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized).toEqual(original);
    });

    test('should throw error for invalid JSON', () => {
      expect(() => MessageProtocol.deserialize('invalid json'))
        .toThrow('Failed to parse JSON');

      expect(() => MessageProtocol.deserialize(''))
        .toThrow('JSON string is required');

      expect(() => MessageProtocol.deserialize(null))
        .toThrow('JSON string is required');
    });

    test('should throw error for invalid message format', () => {
      const invalidMessage = JSON.stringify({ type: 'invalid', id: 'test' });

      expect(() => MessageProtocol.deserialize(invalidMessage))
        .toThrow('Parsed message does not match tunnel message format');
    });
  });

  describe('validation methods', () => {
    describe('validateHttpRequest', () => {
      test('should validate correct HTTP request', () => {
        const validRequest = {
          method: 'GET',
          path: '/api/test',
          headers: {}
        };

        expect(MessageProtocol.validateHttpRequest(validRequest)).toBe(true);
      });

      test('should reject invalid HTTP methods', () => {
        const invalidRequest = {
          method: 'INVALID',
          path: '/api/test',
          headers: {}
        };

        expect(MessageProtocol.validateHttpRequest(invalidRequest)).toBe(false);
      });

      test('should reject missing required fields', () => {
        expect(MessageProtocol.validateHttpRequest({})).toBe(false);
        expect(MessageProtocol.validateHttpRequest({ method: 'GET' })).toBe(false);
        expect(MessageProtocol.validateHttpRequest({ path: '/test' })).toBe(false);
      });

      test('should reject invalid field types', () => {
        const invalidRequest = {
          method: 'GET',
          path: '/test',
          headers: 'not an object'
        };

        expect(MessageProtocol.validateHttpRequest(invalidRequest)).toBe(false);
      });
    });

    describe('validateHttpResponse', () => {
      test('should validate correct HTTP response', () => {
        const validResponse = {
          status: 200,
          headers: {},
          body: 'OK'
        };

        expect(MessageProtocol.validateHttpResponse(validResponse)).toBe(true);
      });

      test('should reject invalid status codes', () => {
        const invalidResponse = {
          status: 999,
          headers: {},
          body: 'OK'
        };

        expect(MessageProtocol.validateHttpResponse(invalidResponse)).toBe(false);
      });

      test('should reject missing status', () => {
        const invalidResponse = {
          headers: {},
          body: 'OK'
        };

        expect(MessageProtocol.validateHttpResponse(invalidResponse)).toBe(false);
      });
    });

    describe('validateTunnelMessage', () => {
      test('should validate all message types', () => {
        const requestMessage = MessageProtocol.createRequestMessage({
          method: 'GET',
          path: '/test',
          headers: {}
        });

        const responseMessage = MessageProtocol.createResponseMessage('req-123', {
          status: 200,
          headers: {},
          body: 'OK'
        });

        const pingMessage = MessageProtocol.createPingMessage();
        const pongMessage = MessageProtocol.createPongMessage('ping-123');
        const errorMessage = MessageProtocol.createErrorMessage('req-123', 'Error');

        expect(MessageProtocol.validateTunnelMessage(requestMessage)).toBe(true);
        expect(MessageProtocol.validateTunnelMessage(responseMessage)).toBe(true);
        expect(MessageProtocol.validateTunnelMessage(pingMessage)).toBe(true);
        expect(MessageProtocol.validateTunnelMessage(pongMessage)).toBe(true);
        expect(MessageProtocol.validateTunnelMessage(errorMessage)).toBe(true);
      });

      test('should reject invalid message types', () => {
        const invalidMessage = {
          type: 'invalid',
          id: 'test-123'
        };

        expect(MessageProtocol.validateTunnelMessage(invalidMessage)).toBe(false);
      });

      test('should reject messages without ID', () => {
        const invalidMessage = {
          type: MESSAGE_TYPES.PING,
          timestamp: new Date().toISOString()
        };

        expect(MessageProtocol.validateTunnelMessage(invalidMessage)).toBe(false);
      });
    });
  });

  describe('extract methods', () => {
    test('should extract HTTP request from tunnel message', () => {
      const original = {
        method: 'POST',
        path: '/api/test',
        headers: { 'content-type': 'application/json' },
        body: '{"test": true}'
      };

      const tunnelMessage = MessageProtocol.createRequestMessage(original);
      const extracted = MessageProtocol.extractHttpRequest(tunnelMessage);

      expect(extracted).toEqual(original);
    });

    test('should extract HTTP response from tunnel message', () => {
      const original = {
        status: 200,
        headers: { 'content-type': 'text/plain' },
        body: 'OK'
      };

      const tunnelMessage = MessageProtocol.createResponseMessage('req-123', original);
      const extracted = MessageProtocol.extractHttpResponse(tunnelMessage);

      expect(extracted).toEqual(original);
    });

    test('should throw error for invalid tunnel messages', () => {
      const invalidMessage = {
        type: MESSAGE_TYPES.HTTP_REQUEST,
        id: 'test',
        method: 'INVALID',
        path: '/test'
      };

      expect(() => MessageProtocol.extractHttpRequest(invalidMessage))
        .toThrow('Invalid tunnel request message');
    });
  });

  describe('edge cases', () => {
    test('should handle empty headers', () => {
      const request = MessageProtocol.createRequestMessage({
        method: 'GET',
        path: '/test',
        headers: {}
      });

      expect(request.headers).toEqual({});
    });

    test('should handle missing optional body', () => {
      const request = MessageProtocol.createRequestMessage({
        method: 'GET',
        path: '/test',
        headers: {}
      });

      expect(request.body).toBeUndefined();
    });

    test('should handle all HTTP methods', () => {
      Object.values(HTTP_METHODS).forEach(method => {
        const request = MessageProtocol.createRequestMessage({
          method,
          path: '/test',
          headers: {}
        });

        expect(request.method).toBe(method);
        expect(MessageProtocol.validateTunnelMessage(request)).toBe(true);
      });
    });

    test('should handle various status codes', () => {
      const statusCodes = [100, 200, 201, 400, 401, 404, 500, 502, 503];

      statusCodes.forEach(status => {
        const response = MessageProtocol.createResponseMessage('req-123', {
          status,
          headers: {},
          body: 'test'
        });

        expect(response.status).toBe(status);
        expect(MessageProtocol.validateTunnelMessage(response)).toBe(true);
      });
    });

    test('should handle large message bodies', () => {
      const largeBody = 'x'.repeat(10000);
      const request = MessageProtocol.createRequestMessage({
        method: 'POST',
        path: '/test',
        headers: { 'content-length': largeBody.length.toString() },
        body: largeBody
      });

      const serialized = MessageProtocol.serialize(request);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized.body).toBe(largeBody);
    });

    test('should handle special characters in paths and headers', () => {
      const request = MessageProtocol.createRequestMessage({
        method: 'GET',
        path: '/api/test?param=value&other=测试',
        headers: { 'x-custom-header': 'special-value-测试' }
      });

      const serialized = MessageProtocol.serialize(request);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized.path).toBe('/api/test?param=value&other=测试');
      expect(deserialized.headers['x-custom-header']).toBe('special-value-测试');
    });

    test('should handle null and undefined values in optional fields', () => {
      // Test request with null headers (should be valid since null is falsy)
      const requestWithNullHeaders = {
        method: 'GET',
        path: '/test',
        headers: null
      };
      expect(MessageProtocol.validateHttpRequest(requestWithNullHeaders)).toBe(true);

      // Test request with undefined body (should be valid)
      const requestWithUndefinedBody = {
        method: 'GET',
        path: '/test',
        headers: {},
        body: undefined
      };
      expect(MessageProtocol.validateHttpRequest(requestWithUndefinedBody)).toBe(true);

      // Test response with null headers (should be valid since null is falsy)
      const responseWithNullHeaders = {
        status: 200,
        headers: null,
        body: 'OK'
      };
      expect(MessageProtocol.validateHttpResponse(responseWithNullHeaders)).toBe(true);

      // Test request with string headers (should be invalid)
      const requestWithStringHeaders = {
        method: 'GET',
        path: '/test',
        headers: 'not an object'
      };
      expect(MessageProtocol.validateHttpRequest(requestWithStringHeaders)).toBe(false);
    });

    test('should handle empty string values', () => {
      // Empty path should be invalid
      const requestWithEmptyPath = {
        method: 'GET',
        path: '',
        headers: {}
      };
      expect(MessageProtocol.validateHttpRequest(requestWithEmptyPath)).toBe(false);

      // Empty method should be invalid
      const requestWithEmptyMethod = {
        method: '',
        path: '/test',
        headers: {}
      };
      expect(MessageProtocol.validateHttpRequest(requestWithEmptyMethod)).toBe(false);

      // Empty body should be valid
      const requestWithEmptyBody = {
        method: 'POST',
        path: '/test',
        headers: {},
        body: ''
      };
      expect(MessageProtocol.validateHttpRequest(requestWithEmptyBody)).toBe(true);
    });

    test('should handle boundary status codes', () => {
      // Test boundary status codes
      const boundaryStatusCodes = [99, 100, 599, 600];
      
      boundaryStatusCodes.forEach(status => {
        const response = {
          status,
          headers: {},
          body: 'test'
        };
        
        if (status >= 100 && status <= 599) {
          expect(MessageProtocol.validateHttpResponse(response)).toBe(true);
        } else {
          expect(MessageProtocol.validateHttpResponse(response)).toBe(false);
        }
      });
    });

    test('should handle case sensitivity in HTTP methods', () => {
      // Test lowercase HTTP methods
      const lowercaseRequest = {
        method: 'get',
        path: '/test',
        headers: {}
      };
      expect(MessageProtocol.validateHttpRequest(lowercaseRequest)).toBe(true);

      // Test mixed case HTTP methods
      const mixedCaseRequest = {
        method: 'PoSt',
        path: '/test',
        headers: {}
      };
      expect(MessageProtocol.validateHttpRequest(mixedCaseRequest)).toBe(true);
    });

    test('should handle malformed JSON in serialization', () => {
      // Test circular reference (should throw during serialization)
      const circularMessage = MessageProtocol.createRequestMessage({
        method: 'GET',
        path: '/test',
        headers: {}
      });
      
      // Add circular reference
      circularMessage.circular = circularMessage;
      
      expect(() => MessageProtocol.serialize(circularMessage))
        .toThrow('Failed to serialize message');
    });

    test('should handle extremely long paths and headers', () => {
      const longPath = '/api/' + 'a'.repeat(10000);
      const longHeaderValue = 'b'.repeat(10000);
      
      const request = MessageProtocol.createRequestMessage({
        method: 'GET',
        path: longPath,
        headers: { 'x-long-header': longHeaderValue }
      });

      const serialized = MessageProtocol.serialize(request);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized.path).toBe(longPath);
      expect(deserialized.headers['x-long-header']).toBe(longHeaderValue);
    });

    test('should handle invalid timestamp formats in ping/pong messages', () => {
      // Test invalid timestamp format
      const invalidPingMessage = {
        type: MESSAGE_TYPES.PING,
        id: 'ping-123',
        timestamp: 'invalid-timestamp'
      };
      expect(MessageProtocol.validateTunnelMessage(invalidPingMessage)).toBe(false);

      // Test numeric timestamp (should be invalid)
      const numericTimestampMessage = {
        type: MESSAGE_TYPES.PING,
        id: 'ping-123',
        timestamp: Date.now()
      };
      expect(MessageProtocol.validateTunnelMessage(numericTimestampMessage)).toBe(false);

      // Test valid ISO timestamp
      const validPingMessage = {
        type: MESSAGE_TYPES.PING,
        id: 'ping-123',
        timestamp: new Date().toISOString()
      };
      expect(MessageProtocol.validateTunnelMessage(validPingMessage)).toBe(true);
    });

    test('should handle array and object values in headers', () => {
      // Headers with array values should be valid (arrays are objects in JavaScript)
      const requestWithArrayHeader = {
        method: 'GET',
        path: '/test',
        headers: { 'x-array': ['value1', 'value2'] }
      };
      expect(MessageProtocol.validateHttpRequest(requestWithArrayHeader)).toBe(true);

      // Headers with nested object values should be valid
      const requestWithObjectHeader = {
        method: 'GET',
        path: '/test',
        headers: { 'x-object': { nested: 'value' } }
      };
      expect(MessageProtocol.validateHttpRequest(requestWithObjectHeader)).toBe(true);

      // Headers with primitive values should be valid
      const requestWithStringHeader = {
        method: 'GET',
        path: '/test',
        headers: { 'x-string': 'value' }
      };
      expect(MessageProtocol.validateHttpRequest(requestWithStringHeader)).toBe(true);
    });

    test('should handle non-string body values', () => {
      // Numeric body should be invalid
      const requestWithNumericBody = {
        method: 'POST',
        path: '/test',
        headers: {},
        body: 123
      };
      expect(MessageProtocol.validateHttpRequest(requestWithNumericBody)).toBe(false);

      // Object body should be invalid (should be stringified first)
      const requestWithObjectBody = {
        method: 'POST',
        path: '/test',
        headers: {},
        body: { data: 'value' }
      };
      expect(MessageProtocol.validateHttpRequest(requestWithObjectBody)).toBe(false);

      // Array body should be invalid
      const requestWithArrayBody = {
        method: 'POST',
        path: '/test',
        headers: {},
        body: ['item1', 'item2']
      };
      expect(MessageProtocol.validateHttpRequest(requestWithArrayBody)).toBe(false);
    });

    test('should handle missing headers field', () => {
      // Request without headers field should be valid (headers are optional)
      const requestWithoutHeaders = {
        method: 'GET',
        path: '/test'
      };
      expect(MessageProtocol.validateHttpRequest(requestWithoutHeaders)).toBe(true);

      // Response without headers field should be valid (headers are optional)
      const responseWithoutHeaders = {
        status: 200,
        body: 'OK'
      };
      expect(MessageProtocol.validateHttpResponse(responseWithoutHeaders)).toBe(true);
    });

    test('should handle whitespace-only values', () => {
      // Whitespace-only path should be valid (could be a valid path)
      const requestWithWhitespacePath = {
        method: 'GET',
        path: '   ',
        headers: {}
      };
      expect(MessageProtocol.validateHttpRequest(requestWithWhitespacePath)).toBe(true);

      // Whitespace-only method should be invalid
      const requestWithWhitespaceMethod = {
        method: '   ',
        path: '/test',
        headers: {}
      };
      expect(MessageProtocol.validateHttpRequest(requestWithWhitespaceMethod)).toBe(false);
    });

    test('should handle error message validation edge cases', () => {
      // Error message with zero code should be valid
      const errorWithZeroCode = MessageProtocol.createErrorMessage('req-123', 'Error', 0);
      expect(MessageProtocol.validateTunnelMessage(errorWithZeroCode)).toBe(true);

      // Error message with negative code should be valid
      const errorWithNegativeCode = MessageProtocol.createErrorMessage('req-123', 'Error', -1);
      expect(MessageProtocol.validateTunnelMessage(errorWithNegativeCode)).toBe(true);

      // Error message with string code should be invalid
      const errorWithStringCode = {
        type: MESSAGE_TYPES.ERROR,
        id: 'req-123',
        error: 'Error message',
        code: '500'
      };
      expect(MessageProtocol.validateTunnelMessage(errorWithStringCode)).toBe(false);
    });

    test('should handle message ID validation edge cases', () => {
      // Empty string ID should be invalid
      const messageWithEmptyId = {
        type: MESSAGE_TYPES.PING,
        id: '',
        timestamp: new Date().toISOString()
      };
      expect(MessageProtocol.validateTunnelMessage(messageWithEmptyId)).toBe(false);

      // Numeric ID should be invalid
      const messageWithNumericId = {
        type: MESSAGE_TYPES.PING,
        id: 123,
        timestamp: new Date().toISOString()
      };
      expect(MessageProtocol.validateTunnelMessage(messageWithNumericId)).toBe(false);

      // Very long ID should be valid
      const messageWithLongId = {
        type: MESSAGE_TYPES.PING,
        id: 'a'.repeat(1000),
        timestamp: new Date().toISOString()
      };
      expect(MessageProtocol.validateTunnelMessage(messageWithLongId)).toBe(true);
    });

    test('should handle response body validation edge cases', () => {
      // Response with missing body should be valid (body is optional in validation)
      const responseWithoutBody = {
        status: 200,
        headers: {}
      };
      expect(MessageProtocol.validateHttpResponse(responseWithoutBody)).toBe(true);

      // Response with null body should be valid (null is falsy)
      const responseWithNullBody = {
        status: 200,
        headers: {},
        body: null
      };
      expect(MessageProtocol.validateHttpResponse(responseWithNullBody)).toBe(true);

      // Response with undefined body should be valid (undefined is falsy)
      const responseWithUndefinedBody = {
        status: 200,
        headers: {},
        body: undefined
      };
      expect(MessageProtocol.validateHttpResponse(responseWithUndefinedBody)).toBe(true);

      // Response with empty string body should be valid
      const responseWithEmptyBody = {
        status: 200,
        headers: {},
        body: ''
      };
      expect(MessageProtocol.validateHttpResponse(responseWithEmptyBody)).toBe(true);

      // Response with non-string body should be invalid
      const responseWithNumericBody = {
        status: 200,
        headers: {},
        body: 123
      };
      expect(MessageProtocol.validateHttpResponse(responseWithNumericBody)).toBe(false);
    });

    test('should handle serialization of special values', () => {
      // Test serialization with Unicode characters
      const unicodeRequest = MessageProtocol.createRequestMessage({
        method: 'POST',
        path: '/api/测试',
        headers: { 'x-unicode': '🚀 rocket' },
        body: '{"emoji": "🎉", "chinese": "测试"}'
      });

      const serialized = MessageProtocol.serialize(unicodeRequest);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized.path).toBe('/api/测试');
      expect(deserialized.headers['x-unicode']).toBe('🚀 rocket');
      expect(deserialized.body).toBe('{"emoji": "🎉", "chinese": "测试"}');
    });

    test('should handle concurrent message creation', () => {
      // Test that multiple messages created concurrently have unique IDs
      const messages = [];
      for (let i = 0; i < 100; i++) {
        messages.push(MessageProtocol.createPingMessage());
      }

      const ids = messages.map(msg => msg.id);
      const uniqueIds = new Set(ids);
      
      expect(uniqueIds.size).toBe(100); // All IDs should be unique
    });

    test('should handle message type validation with extra properties', () => {
      // Request message with extra properties should still be valid
      const requestWithExtraProps = {
        type: MESSAGE_TYPES.HTTP_REQUEST,
        id: 'req-123',
        method: 'GET',
        path: '/test',
        headers: {},
        extraProperty: 'should be ignored'
      };
      expect(MessageProtocol.validateTunnelMessage(requestWithExtraProps)).toBe(true);

      // Response message with extra properties should still be valid
      const responseWithExtraProps = {
        type: MESSAGE_TYPES.HTTP_RESPONSE,
        id: 'req-123',
        status: 200,
        headers: {},
        body: 'OK',
        extraProperty: 'should be ignored'
      };
      expect(MessageProtocol.validateTunnelMessage(responseWithExtraProps)).toBe(true);
    });

    test('should handle deserialization of malformed JSON strings', () => {
      // Test various malformed JSON strings
      const malformedJsonStrings = [
        '{',
        '}',
        '{"type":}',
        '{"type":"ping","id":}',
        '{"type":"ping","id":"123",}',
        '[1,2,3]', // Valid JSON but not an object
        'true', // Valid JSON but not an object
        '"string"', // Valid JSON but not an object
        '123' // Valid JSON but not an object
      ];

      malformedJsonStrings.forEach(jsonString => {
        expect(() => MessageProtocol.deserialize(jsonString))
          .toThrow();
      });
    });

    test('should handle timestamp precision in ping/pong messages', () => {
      // Test that timestamps maintain precision through serialization
      const originalPing = MessageProtocol.createPingMessage();
      const serialized = MessageProtocol.serialize(originalPing);
      const deserialized = MessageProtocol.deserialize(serialized);

      expect(deserialized.timestamp).toBe(originalPing.timestamp);
      
      // Test that the timestamp is a valid ISO string
      const date = new Date(deserialized.timestamp);
      expect(date.toISOString()).toBe(deserialized.timestamp);
    });

    test('should handle validation of primitive values as messages', () => {
      // Test validation of primitive values
      expect(MessageProtocol.validateTunnelMessage(null)).toBe(false);
      expect(MessageProtocol.validateTunnelMessage(undefined)).toBe(false);
      expect(MessageProtocol.validateTunnelMessage('')).toBe(false);
      expect(MessageProtocol.validateTunnelMessage(123)).toBe(false);
      expect(MessageProtocol.validateTunnelMessage(true)).toBe(false);
      expect(MessageProtocol.validateTunnelMessage([])).toBe(false);
    });
  });
});