/**
 * @fileoverview Core message protocol for the simplified tunnel system
 * Defines message types and utilities for communication between cloud API and desktop client
 */

import { v4 as uuidv4 } from 'uuid';

/**
 * @typedef {Object} HttpRequest
 * @property {string} method - HTTP method (GET, POST, PUT, DELETE, etc.)
 * @property {string} path - Request path (e.g., "/api/chat")
 * @property {Record<string, string>} headers - HTTP headers
 * @property {string} [body] - Request body (optional)
 */

/**
 * @typedef {Object} HttpResponse
 * @property {number} status - HTTP status code
 * @property {Record<string, string>} headers - HTTP response headers
 * @property {string} body - Response body
 */

/**
 * @typedef {Object} TunnelRequestMessage
 * @property {"http_request"} type - Message type identifier
 * @property {string} id - Unique request correlation ID
 * @property {string} method - HTTP method
 * @property {string} path - Request path
 * @property {Record<string, string>} headers - HTTP headers
 * @property {string} [body] - Request body (optional)
 */

/**
 * @typedef {Object} TunnelResponseMessage
 * @property {"http_response"} type - Message type identifier
 * @property {string} id - Request correlation ID
 * @property {number} status - HTTP status code
 * @property {Record<string, string>} headers - HTTP response headers
 * @property {string} body - Response body
 */

/**
 * @typedef {Object} PingMessage
 * @property {"ping"} type - Message type identifier
 * @property {string} id - Ping correlation ID
 * @property {string} timestamp - ISO timestamp
 */

/**
 * @typedef {Object} PongMessage
 * @property {"pong"} type - Message type identifier
 * @property {string} id - Ping correlation ID
 * @property {string} timestamp - ISO timestamp
 */

/**
 * @typedef {Object} ErrorMessage
 * @property {"error"} type - Message type identifier
 * @property {string} id - Request correlation ID
 * @property {string} error - Error message
 * @property {number} [code] - Error code (optional)
 */

/**
 * @typedef {TunnelRequestMessage | TunnelResponseMessage | PingMessage | PongMessage | ErrorMessage} TunnelMessage
 */

// Message type constants
export const MESSAGE_TYPES = {
  HTTP_REQUEST: 'http_request',
  HTTP_RESPONSE: 'http_response',
  PING: 'ping',
  PONG: 'pong',
  ERROR: 'error',
};

// HTTP methods
export const HTTP_METHODS = {
  GET: 'GET',
  POST: 'POST',
  PUT: 'PUT',
  DELETE: 'DELETE',
  PATCH: 'PATCH',
  HEAD: 'HEAD',
  OPTIONS: 'OPTIONS',
};

export const VALID_HTTP_METHODS = Object.values(HTTP_METHODS);
export const VALID_MESSAGE_TYPES = Object.values(MESSAGE_TYPES);

/**
 * Message protocol utilities for serialization, deserialization, and validation
 */
export class MessageProtocol {
  /**
   * Create a tunnel request message from HTTP request
   * @param {HttpRequest} httpRequest - HTTP request object
   * @returns {TunnelRequestMessage} Tunnel request message
   */
  static createRequestMessage(httpRequest) {
    if (!this.validateHttpRequest(httpRequest)) {
      throw new Error('Invalid HTTP request format');
    }

    return {
      type: MESSAGE_TYPES.HTTP_REQUEST,
      id: uuidv4(),
      method: httpRequest.method,
      path: httpRequest.path,
      headers: httpRequest.headers || {},
      ...(httpRequest.body && { body: httpRequest.body }),
    };
  }

  /**
   * Create a tunnel response message from HTTP response
   * @param {string} requestId - Original request correlation ID
   * @param {HttpResponse} httpResponse - HTTP response object
   * @returns {TunnelResponseMessage} Tunnel response message
   */
  static createResponseMessage(requestId, httpResponse) {
    if (!requestId || typeof requestId !== 'string') {
      throw new Error('Request ID is required and must be a string');
    }

    if (!this.validateHttpResponse(httpResponse)) {
      throw new Error('Invalid HTTP response format');
    }

    return {
      type: MESSAGE_TYPES.HTTP_RESPONSE,
      id: requestId,
      status: httpResponse.status,
      headers: httpResponse.headers || {},
      body: httpResponse.body || '',
    };
  }

  /**
   * Create a ping message
   * @returns {PingMessage} Ping message
   */
  static createPingMessage() {
    return {
      type: MESSAGE_TYPES.PING,
      id: uuidv4(),
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Create a pong message in response to ping
   * @param {string} pingId - Original ping correlation ID
   * @returns {PongMessage} Pong message
   */
  static createPongMessage(pingId) {
    if (!pingId || typeof pingId !== 'string') {
      throw new Error('Ping ID is required and must be a string');
    }

    return {
      type: MESSAGE_TYPES.PONG,
      id: pingId,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Create an error message
   * @param {string} requestId - Original request correlation ID
   * @param {string} error - Error message
   * @param {number} [code] - Optional error code
   * @returns {ErrorMessage} Error message
   */
  static createErrorMessage(requestId, error, code) {
    if (!requestId || typeof requestId !== 'string') {
      throw new Error('Request ID is required and must be a string');
    }

    if (!error || typeof error !== 'string') {
      throw new Error('Error message is required and must be a string');
    }

    return {
      type: MESSAGE_TYPES.ERROR,
      id: requestId,
      error,
      ...(code && { code }),
    };
  }  /*
*
   * Serialize a tunnel message to JSON string
   * @param {TunnelMessage} message - Message to serialize
   * @returns {string} JSON string
   * @throws {Error} If message is invalid or serialization fails
   */
  static serialize(message) {
    if (!this.validateTunnelMessage(message)) {
      throw new Error('Invalid tunnel message format');
    }

    try {
      return JSON.stringify(message);
    } catch (error) {
      throw new Error(`Failed to serialize message: ${error.message}`);
    }
  }

  /**
   * Deserialize JSON string to tunnel message
   * @param {string} jsonString - JSON string to deserialize
   * @returns {TunnelMessage} Parsed tunnel message
   * @throws {Error} If parsing fails or message is invalid
   */
  static deserialize(jsonString) {
    if (!jsonString || typeof jsonString !== 'string') {
      throw new Error('JSON string is required');
    }

    let parsed;
    try {
      parsed = JSON.parse(jsonString);
    } catch (error) {
      throw new Error(`Failed to parse JSON: ${error.message}`);
    }

    if (!this.validateTunnelMessage(parsed)) {
      throw new Error('Parsed message does not match tunnel message format');
    }

    return parsed;
  }

  /**
   * Validate HTTP request object
   * @param {any} request - Object to validate
   * @returns {boolean} True if valid HTTP request
   */
  static validateHttpRequest(request) {
    if (!request || typeof request !== 'object') {
      return false;
    }

    // Required fields
    if (!request.method || typeof request.method !== 'string') {
      return false;
    }

    if (!request.path || typeof request.path !== 'string') {
      return false;
    }

    // Validate HTTP method
    if (!VALID_HTTP_METHODS.includes(request.method.toUpperCase())) {
      return false;
    }

    // Headers must be an object if present
    if (request.headers && typeof request.headers !== 'object') {
      return false;
    }

    // Body must be a string if present
    if (request.body && typeof request.body !== 'string') {
      return false;
    }

    return true;
  }

  /**
   * Validate HTTP response object
   * @param {any} response - Object to validate
   * @returns {boolean} True if valid HTTP response
   */
  static validateHttpResponse(response) {
    if (!response || typeof response !== 'object') {
      return false;
    }

    // Status is required and must be a number
    if (typeof response.status !== 'number' || response.status < 100 || response.status > 599) {
      return false;
    }

    // Headers must be an object if present
    if (response.headers && typeof response.headers !== 'object') {
      return false;
    }

    // Body must be a string if present
    if (response.body && typeof response.body !== 'string') {
      return false;
    }

    return true;
  }

  /**
   * Validate tunnel message object
   * @param {any} message - Object to validate
   * @returns {boolean} True if valid tunnel message
   */
  static validateTunnelMessage(message) {
    if (!message || typeof message !== 'object') {
      return false;
    }

    // Type is required
    if (!message.type || !VALID_MESSAGE_TYPES.includes(message.type)) {
      return false;
    }

    // ID is required for all message types
    if (!message.id || typeof message.id !== 'string') {
      return false;
    }

    // Validate based on message type
    switch (message.type) {
    case MESSAGE_TYPES.HTTP_REQUEST:
      return this.validateRequestMessage(message);
    case MESSAGE_TYPES.HTTP_RESPONSE:
      return this.validateResponseMessage(message);
    case MESSAGE_TYPES.PING:
      return this.validatePingMessage(message);
    case MESSAGE_TYPES.PONG:
      return this.validatePongMessage(message);
    case MESSAGE_TYPES.ERROR:
      return this.validateErrorMessage(message);
    default:
      return false;
    }
  }

  /**
   * Validate tunnel request message
   * @param {any} message - Message to validate
   * @returns {boolean} True if valid
   */
  static validateRequestMessage(message) {
    // Method is required
    if (!message.method || !VALID_HTTP_METHODS.includes(message.method.toUpperCase())) {
      return false;
    }

    // Path is required
    if (!message.path || typeof message.path !== 'string') {
      return false;
    }

    // Headers must be an object
    if (message.headers && typeof message.headers !== 'object') {
      return false;
    }

    // Body must be a string if present
    if (message.body && typeof message.body !== 'string') {
      return false;
    }

    return true;
  }

  /**
   * Validate tunnel response message
   * @param {any} message - Message to validate
   * @returns {boolean} True if valid
   */
  static validateResponseMessage(message) {
    // Status is required
    if (typeof message.status !== 'number' || message.status < 100 || message.status > 599) {
      return false;
    }

    // Headers must be an object
    if (message.headers && typeof message.headers !== 'object') {
      return false;
    }

    // Body must be a string
    if (typeof message.body !== 'string') {
      return false;
    }

    return true;
  }

  /**
   * Validate ping message
   * @param {any} message - Message to validate
   * @returns {boolean} True if valid
   */
  static validatePingMessage(message) {
    // Timestamp is required
    if (!message.timestamp || typeof message.timestamp !== 'string') {
      return false;
    }

    // Validate ISO timestamp format
    try {
      const date = new Date(message.timestamp);
      return date.toISOString() === message.timestamp;
    } catch {
      return false;
    }
  }

  /**
   * Validate pong message
   * @param {any} message - Message to validate
   * @returns {boolean} True if valid
   */
  static validatePongMessage(message) {
    return this.validatePingMessage(message); // Same validation as ping
  }

  /**
   * Validate error message
   * @param {any} message - Message to validate
   * @returns {boolean} True if valid
   */
  static validateErrorMessage(message) {
    // Error message is required
    if (!message.error || typeof message.error !== 'string') {
      return false;
    }

    // Code must be a number if present
    if (message.code && typeof message.code !== 'number') {
      return false;
    }

    return true;
  }

  /**
   * Extract HTTP request from tunnel request message
   * @param {TunnelRequestMessage} message - Tunnel request message
   * @returns {HttpRequest} HTTP request object
   */
  static extractHttpRequest(message) {
    if (!this.validateRequestMessage(message)) {
      throw new Error('Invalid tunnel request message');
    }

    return {
      method: message.method,
      path: message.path,
      headers: message.headers || {},
      ...(message.body && { body: message.body }),
    };
  }

  /**
   * Extract HTTP response from tunnel response message
   * @param {TunnelResponseMessage} message - Tunnel response message
   * @returns {HttpResponse} HTTP response object
   */
  static extractHttpResponse(message) {
    if (!this.validateResponseMessage(message)) {
      throw new Error('Invalid tunnel response message');
    }

    return {
      status: message.status,
      headers: message.headers || {},
      body: message.body,
    };
  }
}
