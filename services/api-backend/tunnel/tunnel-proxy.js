/**
 * @fileoverview Simplified tunnel proxy service for cloud-side request routing
 * Handles WebSocket connections from desktop clients and HTTP proxy endpoints for containers
 */

import { WebSocket } from 'ws';
import { v4 as uuidv4 } from 'uuid';
import winston from 'winston';
import { MessageProtocol, MESSAGE_TYPES } from './message-protocol.js';
import { TunnelLogger, ERROR_CODES, ErrorResponseBuilder } from '../utils/logger.js';

/**
 * @typedef {Object} TunnelConnection
 * @property {string} userId - User ID from JWT token
 * @property {WebSocket} websocket - WebSocket connection to desktop client
 * @property {boolean} isConnected - Connection status
 * @property {Date} lastPing - Last ping timestamp
 * @property {Map<string, PendingRequest>} pendingRequests - Active requests awaiting response
 */

/**
 * @typedef {Object} PendingRequest
 * @property {string} id - Request correlation ID
 * @property {Date} timestamp - Request start time
 * @property {NodeJS.Timeout} timeout - Timeout handler
 * @property {Function} resolve - Promise resolve function
 * @property {Function} reject - Promise reject function
 */

/**
 * Simplified tunnel proxy service
 * Manages WebSocket connections from desktop clients and routes HTTP requests
 */
export class TunnelProxy {
  constructor(logger = winston.createLogger()) {
    // Use enhanced logger if winston logger provided, otherwise create new TunnelLogger
    this.logger = logger instanceof TunnelLogger ? logger : new TunnelLogger('tunnel-proxy');

    /** @type {Map<string, TunnelConnection>} */
    this.connections = new Map();

    /** @type {Map<string, TunnelConnection>} */
    this.userConnections = new Map();

    this.REQUEST_TIMEOUT = 30000; // 30 seconds (default)
    this.LLM_REQUEST_TIMEOUT = 120000; // 2 minutes for LLM requests
    this.PING_INTERVAL = 30000; // 30 seconds
    this.PONG_TIMEOUT = 10000; // 10 seconds
    this.pingIntervals = new Map();
    this.pongTimeouts = new Map();

    // Enhanced performance metrics with connection pooling and LLM-specific tracking
    this.metrics = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      timeoutRequests: 0,
      averageResponseTime: 0,
      connectionCount: 0,
      reconnectionCount: 0,
      // Enhanced metrics
      recentResponseTimes: [],
      requestTimestamps: [],
      memoryUsage: 0,
      peakMemoryUsage: 0,
      connectionPoolHits: 0,
      connectionPoolMisses: 0,
      queuedMessages: 0,
      peakQueuedMessages: 0,
      // LLM-specific metrics
      llmRequests: 0,
      llmSuccessfulRequests: 0,
      llmFailedRequests: 0,
      llmTimeoutRequests: 0,
      llmAverageResponseTime: 0,
      llmRecentResponseTimes: [],
      streamingRequests: 0,
      modelOperations: {
        list: 0,
        pull: 0,
        delete: 0,
        show: 0,
      },
      providerStats: {
        ollama: 0,
        lmstudio: 0,
        openai: 0,
        other: 0,
      },
    };

    // Connection pooling for efficient resource management
    this.connectionPool = new Map(); // userId -> pooled connections
    this.MAX_POOL_SIZE_PER_USER = 3;
    this.POOL_CLEANUP_INTERVAL = 60000; // 1 minute

    // Message queuing for performance optimization
    this.messageQueues = new Map(); // connectionId -> message queue
    this.MAX_QUEUE_SIZE = 500;
    this.isProcessingQueues = false;

    // Performance monitoring
    this.performanceAlerts = [];
    this.lastPerformanceCheck = new Date();
    this.PERFORMANCE_CHECK_INTERVAL = 30000; // 30 seconds

    // Start performance monitoring
    this.startPerformanceMonitoring();
  }

  /**
   * Handle new WebSocket connection from desktop client
   * @param {WebSocket} ws - WebSocket connection
   * @param {string} userId - Authenticated user ID
   * @returns {string} Connection ID
   */
  handleConnection(ws, userId) {
    const connectionId = uuidv4();
    const correlationId = this.logger.generateCorrelationId();

    try {
      // Check if user already has a connection
      const existingConnection = this.userConnections.get(userId);
      if (existingConnection && existingConnection.isConnected) {
        this.logger.logConnection('replaced', connectionId, userId, {
          correlationId,
          previousConnectionId: Array.from(this.connections.entries())
            .find(([id, conn]) => conn === existingConnection)?.[0],
          reason: 'User reconnected with new connection',
        });

        // Clean up existing connection
        this.handleDisconnection(Array.from(this.connections.entries())
          .find(([id, conn]) => conn === existingConnection)?.[0]);
      }

      const connection = {
        userId,
        websocket: ws,
        isConnected: true,
        lastPing: new Date(),
        pendingRequests: new Map(),
        connectionId,
        correlationId,
        connectedAt: new Date(),
        lastActivity: new Date(),
      };

      // Store connection
      this.connections.set(connectionId, connection);
      this.userConnections.set(userId, connection);
      this.metrics.connectionCount++;

      this.logger.logConnection('connected', connectionId, userId, {
        correlationId,
        totalConnections: this.connections.size,
        userConnections: this.userConnections.size,
      });

      // Set up message handler with error handling
      ws.on('message', (data) => {
        try {
          connection.lastActivity = new Date();
          this.handleMessage(connectionId, data);
        } catch (error) {
          this.logger.logTunnelError(
            ERROR_CODES.MESSAGE_SERIALIZATION_FAILED,
            'Failed to handle WebSocket message',
            { connectionId, userId, correlationId, error: error.message },
          );
        }
      });

      // Set up close handler
      ws.on('close', (code, reason) => {
        this.logger.logConnection('disconnected', connectionId, userId, {
          correlationId,
          closeCode: code,
          closeReason: reason?.toString() || 'Unknown',
        });
        this.handleDisconnection(connectionId);
      });

      // Set up error handler
      ws.on('error', (error) => {
        this.logger.logTunnelError(
          ERROR_CODES.WEBSOCKET_CONNECTION_FAILED,
          'WebSocket connection error',
          { connectionId, userId, correlationId, error: error.message },
        );
        this.handleDisconnection(connectionId);
      });

      // Start ping/pong health check
      this.startPingInterval(connectionId);

      // Send welcome message
      try {
        const welcomeMessage = MessageProtocol.createPingMessage();
        this.sendMessage(connectionId, welcomeMessage);
      } catch (error) {
        this.logger.logTunnelError(
          ERROR_CODES.WEBSOCKET_SEND_FAILED,
          'Failed to send welcome message',
          { connectionId, userId, correlationId, error: error.message },
        );
        throw error;
      }

      return connectionId;
    } catch (error) {
      this.logger.logTunnelError(
        ERROR_CODES.WEBSOCKET_CONNECTION_FAILED,
        'Failed to handle new connection',
        { connectionId, userId, correlationId, error: error.message },
      );
      throw error;
    }
  }

  /**
   * Handle WebSocket message from desktop client
   * @param {string} connectionId - Connection ID
   * @param {Buffer} data - Raw message data
   */
  handleMessage(connectionId, data) {
    const connection = this.connections.get(connectionId);
    if (!connection) {
      this.logger.logTunnelError(
        ERROR_CODES.INVALID_MESSAGE_FORMAT,
        'Message from unknown connection',
        { connectionId, dataLength: data?.length || 0 },
      );
      return;
    }

    try {
      const messageStr = data.toString();
      if (!messageStr || messageStr.trim().length === 0) {
        this.logger.logTunnelError(
          ERROR_CODES.INVALID_MESSAGE_FORMAT,
          'Empty message received',
          { connectionId, userId: connection.userId, correlationId: connection.correlationId },
        );
        return;
      }

      const message = MessageProtocol.deserialize(messageStr);

      this.logger.debug('Message received', {
        connectionId,
        userId: connection.userId,
        messageType: message.type,
        messageId: message.id,
        correlationId: connection.correlationId,
      });

      switch (message.type) {
      case MESSAGE_TYPES.HTTP_RESPONSE:
        this.handleHttpResponse(connectionId, message);
        break;
      case MESSAGE_TYPES.PONG:
        this.handlePong(connectionId, message);
        break;
      case MESSAGE_TYPES.ERROR:
        this.handleError(connectionId, message);
        break;
      default:
        this.logger.logTunnelError(
          ERROR_CODES.INVALID_MESSAGE_FORMAT,
          'Unknown message type received',
          {
            connectionId,
            userId: connection.userId,
            messageType: message.type,
            correlationId: connection.correlationId,
          },
        );
      }
    } catch (error) {
      this.logger.logTunnelError(
        ERROR_CODES.MESSAGE_SERIALIZATION_FAILED,
        'Failed to process WebSocket message',
        {
          connectionId,
          userId: connection.userId,
          error: error.message,
          correlationId: connection.correlationId,
          dataLength: data?.length || 0,
        },
      );
    }
  }

  /**
   * Handle HTTP response from desktop client
   * @param {string} connectionId - Connection ID
   * @param {Object} message - Response message
   */
  handleHttpResponse(connectionId, message) {
    const connection = this.connections.get(connectionId);
    if (!connection) {
      this.logger.logTunnelError(
        ERROR_CODES.INVALID_MESSAGE_FORMAT,
        'HTTP response from unknown connection',
        { connectionId, messageId: message.id },
      );
      return;
    }

    const pendingRequest = connection.pendingRequests.get(message.id);
    if (!pendingRequest) {
      this.logger.logTunnelError(
        ERROR_CODES.INVALID_REQUEST_FORMAT,
        'Response for unknown or expired request',
        {
          connectionId,
          userId: connection.userId,
          messageId: message.id,
          correlationId: connection.correlationId,
          pendingRequestsCount: connection.pendingRequests.size,
        },
      );
      return;
    }

    try {
      // Calculate response time
      const responseTime = Date.now() - pendingRequest.timestamp.getTime();

      // Clear timeout and remove from pending requests
      clearTimeout(pendingRequest.timeout);
      connection.pendingRequests.delete(message.id);

      // Extract and validate HTTP response
      const httpResponse = MessageProtocol.extractHttpResponse(message);

      // Update metrics
      this.metrics.successfulRequests++;
      this.updateAverageResponseTime(responseTime);

      // Track LLM-specific metrics if applicable
      if (pendingRequest.method && pendingRequest.path) {
        this.trackLLMRequest(
          { path: pendingRequest.path, method: pendingRequest.method, body: pendingRequest.body },
          responseTime,
          true
        );
      }

      // Resolve the promise with the HTTP response
      pendingRequest.resolve(httpResponse);

      this.logger.logRequest('completed', message.id, connection.userId, {
        connectionId,
        correlationId: connection.correlationId,
        responseTime,
        statusCode: httpResponse.status,
        pendingRequestsCount: connection.pendingRequests.size,
      });
    } catch (error) {
      // Clear timeout and remove from pending requests
      clearTimeout(pendingRequest.timeout);
      connection.pendingRequests.delete(message.id);

      this.metrics.failedRequests++;

      this.logger.logTunnelError(
        ERROR_CODES.INVALID_MESSAGE_FORMAT,
        'Failed to process HTTP response',
        {
          connectionId,
          userId: connection.userId,
          messageId: message.id,
          correlationId: connection.correlationId,
          error: error.message,
        },
      );

      pendingRequest.reject(new Error(`Invalid response format: ${error.message}`));
    }
  }

  /**
   * Handle pong message from desktop client
   * @param {string} connectionId - Connection ID
   * @param {Object} message - Pong message
   */
  handlePong(connectionId, message) {
    const connection = this.connections.get(connectionId);
    if (!connection) {
      this.logger.logTunnelError(
        ERROR_CODES.INVALID_MESSAGE_FORMAT,
        'Pong from unknown connection',
        { connectionId, messageId: message.id },
      );
      return;
    }

    // Clear pong timeout if it exists
    const pongTimeout = this.pongTimeouts.get(connectionId);
    if (pongTimeout) {
      clearTimeout(pongTimeout);
      this.pongTimeouts.delete(connectionId);
    }

    connection.lastPing = new Date();
    connection.lastActivity = new Date();

    this.logger.debug('Pong received', {
      connectionId,
      userId: connection.userId,
      messageId: message.id,
      correlationId: connection.correlationId,
    });
  }

  /**
   * Handle error message from desktop client
   * @param {string} connectionId - Connection ID
   * @param {Object} message - Error message
   */
  handleError(connectionId, message) {
    const connection = this.connections.get(connectionId);
    if (!connection) {
      this.logger.logTunnelError(
        ERROR_CODES.INVALID_MESSAGE_FORMAT,
        'Error message from unknown connection',
        { connectionId, messageId: message.id },
      );
      return;
    }

    const pendingRequest = connection.pendingRequests.get(message.id);
    if (!pendingRequest) {
      this.logger.logTunnelError(
        ERROR_CODES.INVALID_REQUEST_FORMAT,
        'Error for unknown or expired request',
        {
          connectionId,
          userId: connection.userId,
          messageId: message.id,
          correlationId: connection.correlationId,
          errorMessage: message.error,
        },
      );
      return;
    }

    // Calculate response time
    const responseTime = Date.now() - pendingRequest.timestamp.getTime();

    // Clear timeout and remove from pending requests
    clearTimeout(pendingRequest.timeout);
    connection.pendingRequests.delete(message.id);

    // Update metrics
    this.metrics.failedRequests++;

    // Create error with additional context
    const error = new Error(message.error);
    error.code = message.code;
    error.requestId = message.id;
    error.responseTime = responseTime;

    // Reject the promise with the error
    pendingRequest.reject(error);

    this.logger.logRequest('failed', message.id, connection.userId, {
      connectionId,
      correlationId: connection.correlationId,
      responseTime,
      errorCode: message.code,
      errorMessage: message.error,
      pendingRequestsCount: connection.pendingRequests.size,
    });
  }

  /**
   * Handle connection disconnection
   * @param {string} connectionId - Connection ID
   */
  handleDisconnection(connectionId) {
    const connection = this.connections.get(connectionId);
    if (!connection) {
      this.logger.debug('Disconnection for unknown connection', { connectionId });
      return;
    }

    const sessionDuration = Date.now() - connection.connectedAt.getTime();

    this.logger.logConnection('disconnected', connectionId, connection.userId, {
      correlationId: connection.correlationId,
      sessionDuration,
      pendingRequestsCount: connection.pendingRequests.size,
    });

    // Mark connection as disconnected
    connection.isConnected = false;

    // Stop ping interval and pong timeout
    this.stopPingInterval(connectionId);
    const pongTimeout = this.pongTimeouts.get(connectionId);
    if (pongTimeout) {
      clearTimeout(pongTimeout);
      this.pongTimeouts.delete(connectionId);
    }

    // Clean up pending requests with proper error handling
    const pendingRequestsCount = connection.pendingRequests.size;
    for (const [requestId, pendingRequest] of connection.pendingRequests) {
      clearTimeout(pendingRequest.timeout);

      const error = new Error('Connection closed');
      error.code = ERROR_CODES.CONNECTION_LOST;
      error.requestId = requestId;

      pendingRequest.reject(error);

      this.logger.logRequest('failed', requestId, connection.userId, {
        connectionId,
        correlationId: connection.correlationId,
        reason: 'Connection closed',
        errorCode: ERROR_CODES.CONNECTION_LOST,
      });
    }
    connection.pendingRequests.clear();

    // Update metrics
    if (pendingRequestsCount > 0) {
      this.metrics.failedRequests += pendingRequestsCount;
    }

    // Remove from maps
    this.connections.delete(connectionId);
    if (this.userConnections.get(connection.userId) === connection) {
      this.userConnections.delete(connection.userId);
    }
  }

  /**
   * Forward LLM request to desktop client with extended timeout
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @returns {Promise<Object>} HTTP response object
   */
  async forwardLLMRequest(userId, httpRequest) {
    return this.forwardRequestWithTimeout(userId, httpRequest, this.LLM_REQUEST_TIMEOUT);
  }

  /**
   * Forward HTTP request to desktop client with custom timeout
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @param {number} customTimeout - Custom timeout in milliseconds
   * @returns {Promise<Object>} HTTP response object
   */
  async forwardRequestWithTimeout(userId, httpRequest, customTimeout = null) {
    const timeoutMs = customTimeout || (httpRequest.timeout || this.REQUEST_TIMEOUT);

    const connection = this.userConnections.get(userId);
    if (!connection || !connection.isConnected) {
      const error = new Error('Desktop client not connected');
      error.code = ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED;
      throw error;
    }

    // Update metrics
    this.metrics.totalRequests++;

    return new Promise((resolve, reject) => {
      const requestMessage = MessageProtocol.createRequestMessage(httpRequest);
      const startTime = Date.now();

      // Set up timeout with enhanced error handling
      const timeout = setTimeout(() => {
        connection.pendingRequests.delete(requestMessage.id);

        // Update metrics
        this.metrics.timeoutRequests++;
        this.metrics.failedRequests++;

        // Track LLM timeout if applicable
        if (httpRequest.path && httpRequest.method) {
          this.trackLLMRequest(httpRequest, null, false);
          if (this.isLLMPath(httpRequest.path)) {
            this.metrics.llmTimeoutRequests++;
          }
        }

        const error = new Error('Request timeout');
        error.code = ERROR_CODES.REQUEST_TIMEOUT;
        error.requestId = requestMessage.id;
        error.timeout = timeoutMs;

        this.logger.logRequest('timeout', requestMessage.id, userId, {
          connectionId: connection.connectionId,
          correlationId: connection.correlationId,
          method: httpRequest.method,
          path: httpRequest.path,
          timeout: timeoutMs,
          isLLMRequest: timeoutMs > this.REQUEST_TIMEOUT,
          pendingRequestsCount: connection.pendingRequests.size,
        });

        reject(error);
      }, timeoutMs);

      // Store pending request with enhanced metadata
      connection.pendingRequests.set(requestMessage.id, {
        id: requestMessage.id,
        timestamp: new Date(),
        timeout,
        resolve,
        reject,
        method: httpRequest.method,
        path: httpRequest.path,
        startTime,
        isLLMRequest: timeoutMs > this.REQUEST_TIMEOUT,
      });

      // Send request to desktop client with error handling
      try {
        this.sendMessage(connection, requestMessage);

        this.logger.logRequest('started', requestMessage.id, userId, {
          connectionId: connection.connectionId,
          correlationId: connection.correlationId,
          method: httpRequest.method,
          path: httpRequest.path,
          timeout: timeoutMs,
          isLLMRequest: timeoutMs > this.REQUEST_TIMEOUT,
          pendingRequestsCount: connection.pendingRequests.size,
        });
      } catch (error) {
        // Clean up on send failure
        clearTimeout(timeout);
        connection.pendingRequests.delete(requestMessage.id);

        // Update metrics
        this.metrics.failedRequests++;

        this.logger.logTunnelError(
          ERROR_CODES.WEBSOCKET_SEND_FAILED,
          'Failed to send request to desktop client',
          {
            connectionId: connection.connectionId,
            userId,
            correlationId: connection.correlationId,
            requestId: requestMessage.id,
            error: error.message,
            isLLMRequest: timeoutMs > this.REQUEST_TIMEOUT,
          },
        );

        const enhancedError = new Error(`Failed to send request: ${error.message}`);
        enhancedError.code = ERROR_CODES.WEBSOCKET_SEND_FAILED;
        reject(enhancedError);
      }
    });
  }

  /**
   * Forward HTTP request to desktop client
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @returns {Promise<Object>} HTTP response object
   */
  async forwardRequest(userId, httpRequest) {
    return this.forwardRequestWithTimeout(userId, httpRequest, null);
  }

  /**
   * Check if user has active connection
   * @param {string} userId - User ID
   * @returns {boolean} True if user has active connection
   */
  isUserConnected(userId) {
    const connection = this.userConnections.get(userId);
    if (!connection) {
      return false;
    }
    return connection.isConnected && connection.websocket && connection.websocket.readyState === WebSocket.OPEN;
  }

  /**
   * Get connection status for user
   * @param {string} userId - User ID
   * @returns {Object} Connection status
   */
  getUserConnectionStatus(userId) {
    const connection = this.userConnections.get(userId);
    if (!connection) {
      return { connected: false };
    }

    return {
      connected: connection.isConnected,
      lastPing: connection.lastPing,
      pendingRequests: connection.pendingRequests.size,
    };
  }

  /**
   * Send message to connection
   * @param {string|Object} connectionIdOrConnection - Connection ID or connection object
   * @param {Object} message - Message to send
   */
  sendMessage(connectionIdOrConnection, message) {
    let connection;
    if (typeof connectionIdOrConnection === 'string') {
      connection = this.connections.get(connectionIdOrConnection);
    } else {
      connection = connectionIdOrConnection;
    }

    if (!connection || connection.websocket.readyState !== WebSocket.OPEN) {
      throw new Error('Connection not available');
    }

    const serialized = MessageProtocol.serialize(message);
    connection.websocket.send(serialized);
  }

  /**
   * Start ping interval for connection
   * @param {string} connectionId - Connection ID
   */
  startPingInterval(connectionId) {
    const interval = setInterval(() => {
      const connection = this.connections.get(connectionId);
      if (!connection || connection.websocket.readyState !== WebSocket.OPEN) {
        this.stopPingInterval(connectionId);
        return;
      }

      try {
        const pingMessage = MessageProtocol.createPingMessage();
        this.sendMessage(connection, pingMessage);

        // Set up pong timeout
        const pongTimeout = setTimeout(() => {
          this.logger.logTunnelError(
            ERROR_CODES.PING_TIMEOUT,
            'Pong timeout - connection may be dead',
            {
              connectionId,
              userId: connection.userId,
              correlationId: connection.correlationId,
              pingId: pingMessage.id,
            },
          );
          this.handleDisconnection(connectionId);
        }, this.PONG_TIMEOUT);

        this.pongTimeouts.set(connectionId, pongTimeout);

        this.logger.debug('Ping sent', {
          connectionId,
          userId: connection.userId,
          pingId: pingMessage.id,
          correlationId: connection.correlationId,
        });
      } catch (error) {
        this.logger.logTunnelError(
          ERROR_CODES.WEBSOCKET_SEND_FAILED,
          'Failed to send ping',
          {
            connectionId,
            userId: connection.userId,
            correlationId: connection.correlationId,
            error: error.message,
          },
        );
        this.stopPingInterval(connectionId);
        this.handleDisconnection(connectionId);
      }
    }, this.PING_INTERVAL);

    this.pingIntervals.set(connectionId, interval);
  }

  /**
   * Stop ping interval for connection
   * @param {string} connectionId - Connection ID
   */
  stopPingInterval(connectionId) {
    const interval = this.pingIntervals.get(connectionId);
    if (interval) {
      clearInterval(interval);
      this.pingIntervals.delete(connectionId);
    }
  }

  /**
   * Update average response time metric with enhanced tracking
   * @param {number} responseTime - Response time in milliseconds
   */
  updateAverageResponseTime(responseTime) {
    const totalSuccessful = this.metrics.successfulRequests;
    if (totalSuccessful === 1) {
      this.metrics.averageResponseTime = responseTime;
    } else {
      // Calculate running average
      this.metrics.averageResponseTime =
        ((this.metrics.averageResponseTime * (totalSuccessful - 1)) + responseTime) / totalSuccessful;
    }

    // Track recent response times for performance analysis
    this.metrics.recentResponseTimes.push(responseTime);
    if (this.metrics.recentResponseTimes.length > 100) {
      this.metrics.recentResponseTimes.shift();
    }

    // Track request timestamps for throughput calculation
    this.metrics.requestTimestamps.push(new Date());
    this.cleanupOldTimestamps();
  }

  /**
   * Clean up old timestamps for throughput calculation
   */
  cleanupOldTimestamps() {
    const cutoff = new Date(Date.now() - 60000); // 1 minute window
    this.metrics.requestTimestamps = this.metrics.requestTimestamps
      .filter(timestamp => timestamp > cutoff);
  }

  /**
   * Track LLM-specific request metrics
   * @param {Object} httpRequest - HTTP request object
   * @param {number} responseTime - Response time in milliseconds
   * @param {boolean} success - Whether the request was successful
   */
  trackLLMRequest(httpRequest, responseTime = null, success = true) {
    // Detect if this is an LLM request based on path
    const isLLMRequest = this.isLLMPath(httpRequest.path);
    if (!isLLMRequest) return;

    this.metrics.llmRequests++;

    if (success && responseTime !== null) {
      this.metrics.llmSuccessfulRequests++;
      this.updateLLMAverageResponseTime(responseTime);
    } else if (!success) {
      this.metrics.llmFailedRequests++;
    }

    // Track model operations
    this.trackModelOperation(httpRequest.path, httpRequest.method);

    // Track provider usage
    this.trackProviderUsage(httpRequest);

    // Track streaming requests
    if (this.isStreamingRequest(httpRequest)) {
      this.metrics.streamingRequests++;
    }
  }

  /**
   * Check if a request path is LLM-related
   * @param {string} path - Request path
   * @returns {boolean} True if LLM-related
   */
  isLLMPath(path) {
    const llmPaths = [
      '/api/chat', '/api/generate', '/api/embeddings',
      '/api/models', '/api/pull', '/api/push', '/api/delete',
      '/api/show', '/api/copy', '/api/create'
    ];
    return llmPaths.some(llmPath => path.startsWith(llmPath));
  }

  /**
   * Check if a request is for streaming
   * @param {Object} httpRequest - HTTP request object
   * @returns {boolean} True if streaming request
   */
  isStreamingRequest(httpRequest) {
    if (httpRequest.body) {
      try {
        const body = typeof httpRequest.body === 'string'
          ? JSON.parse(httpRequest.body)
          : httpRequest.body;
        return body.stream === true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /**
   * Track model operations (list, pull, delete, etc.)
   * @param {string} path - Request path
   * @param {string} method - HTTP method
   */
  trackModelOperation(path, method) {
    if (path.includes('/api/models') && method === 'GET') {
      this.metrics.modelOperations.list++;
    } else if (path.includes('/api/pull') && method === 'POST') {
      this.metrics.modelOperations.pull++;
    } else if (path.includes('/api/delete') && method === 'DELETE') {
      this.metrics.modelOperations.delete++;
    } else if (path.includes('/api/show') && method === 'POST') {
      this.metrics.modelOperations.show++;
    }
  }

  /**
   * Track provider usage based on request characteristics
   * @param {Object} httpRequest - HTTP request object
   */
  trackProviderUsage(httpRequest) {
    // Default to Ollama since that's the primary target
    // This could be enhanced to detect other providers based on headers or request format
    this.metrics.providerStats.ollama++;
  }

  /**
   * Update LLM average response time
   * @param {number} responseTime - Response time in milliseconds
   */
  updateLLMAverageResponseTime(responseTime) {
    const totalSuccessful = this.metrics.llmSuccessfulRequests;
    if (totalSuccessful === 1) {
      this.metrics.llmAverageResponseTime = responseTime;
    } else {
      // Calculate running average
      this.metrics.llmAverageResponseTime =
        ((this.metrics.llmAverageResponseTime * (totalSuccessful - 1)) + responseTime) / totalSuccessful;
    }

    // Track recent LLM response times
    this.metrics.llmRecentResponseTimes.push(responseTime);
    if (this.metrics.llmRecentResponseTimes.length > 50) {
      this.metrics.llmRecentResponseTimes.shift();
    }
  }

  /**
   * Start performance monitoring system
   */
  startPerformanceMonitoring() {
    // Performance check interval
    setInterval(() => {
      this.checkPerformanceAlerts();
      this.updateMemoryUsage();
      this.cleanupConnectionPool();
    }, this.PERFORMANCE_CHECK_INTERVAL);

    // Connection pool cleanup interval
    setInterval(() => {
      this.cleanupConnectionPool();
    }, this.POOL_CLEANUP_INTERVAL);

    this.logger.info('Performance monitoring started', {
      checkInterval: this.PERFORMANCE_CHECK_INTERVAL,
      poolCleanupInterval: this.POOL_CLEANUP_INTERVAL,
    });
  }

  /**
   * Check for performance issues and generate alerts
   */
  checkPerformanceAlerts() {
    const stats = this.getStats();
    const alerts = [];

    // Check success rate
    if (stats.requests.successRate < 80) {
      alerts.push({
        type: 'LOW_SUCCESS_RATE',
        message: `Success rate is ${stats.requests.successRate}% (below 80%)`,
        severity: 'high',
        timestamp: new Date(),
      });
    }

    // Check timeout rate
    if (stats.requests.timeoutRate > 20) {
      alerts.push({
        type: 'HIGH_TIMEOUT_RATE',
        message: `Timeout rate is ${stats.requests.timeoutRate}% (above 20%)`,
        severity: 'high',
        timestamp: new Date(),
      });
    }

    // Check response time
    if (stats.performance.averageResponseTime > 5000) {
      alerts.push({
        type: 'HIGH_RESPONSE_TIME',
        message: `Average response time is ${stats.performance.averageResponseTime}ms (above 5000ms)`,
        severity: 'medium',
        timestamp: new Date(),
      });
    }

    // Check memory usage
    const memoryUsageMB = this.metrics.memoryUsage / (1024 * 1024);
    if (memoryUsageMB > 100) {
      alerts.push({
        type: 'HIGH_MEMORY_USAGE',
        message: `Memory usage is ${memoryUsageMB.toFixed(2)}MB (above 100MB)`,
        severity: 'medium',
        timestamp: new Date(),
      });
    }

    // Check queue size
    if (this.metrics.queuedMessages > 200) {
      alerts.push({
        type: 'HIGH_QUEUE_SIZE',
        message: `Message queue size is ${this.metrics.queuedMessages} (above 200)`,
        severity: 'high',
        timestamp: new Date(),
      });
    }

    // Update alerts and log if new alerts found
    if (alerts.length > 0) {
      this.performanceAlerts = alerts;
      this.logger.warn('Performance alerts detected', {
        alertCount: alerts.length,
        alerts: alerts.map(a => ({ type: a.type, severity: a.severity })),
      });
    } else if (this.performanceAlerts.length > 0) {
      // Clear alerts if performance is back to normal
      this.performanceAlerts = [];
      this.logger.info('Performance alerts cleared - system performance normalized');
    }

    this.lastPerformanceCheck = new Date();
  }

  /**
   * Update memory usage estimation
   */
  updateMemoryUsage() {
    let memoryBytes = 0;

    // Base proxy overhead
    memoryBytes += 5 * 1024 * 1024; // 5MB base

    // Connection overhead
    memoryBytes += this.connections.size * 4096; // ~4KB per connection

    // Pending requests
    const totalPendingRequests = Array.from(this.connections.values())
      .reduce((sum, conn) => sum + conn.pendingRequests.size, 0);
    memoryBytes += totalPendingRequests * 1024; // ~1KB per pending request

    // Message queues
    const totalQueuedMessages = Array.from(this.messageQueues.values())
      .reduce((sum, queue) => sum + queue.length, 0);
    memoryBytes += totalQueuedMessages * 512; // ~512B per queued message

    // Connection pool
    const totalPooledConnections = Array.from(this.connectionPool.values())
      .reduce((sum, pool) => sum + pool.length, 0);
    memoryBytes += totalPooledConnections * 2048; // ~2KB per pooled connection

    this.metrics.memoryUsage = memoryBytes;
    if (memoryBytes > this.metrics.peakMemoryUsage) {
      this.metrics.peakMemoryUsage = memoryBytes;
    }

    this.metrics.queuedMessages = totalQueuedMessages;
    if (totalQueuedMessages > this.metrics.peakQueuedMessages) {
      this.metrics.peakQueuedMessages = totalQueuedMessages;
    }
  }

  /**
   * Clean up connection pool by removing stale connections
   */
  cleanupConnectionPool() {
    let cleanedConnections = 0;

    for (const [userId, pool] of this.connectionPool.entries()) {
      const activeConnections = pool.filter(conn =>
        conn.readyState === WebSocket.OPEN || conn.readyState === WebSocket.CONNECTING,
      );

      if (activeConnections.length !== pool.length) {
        cleanedConnections += pool.length - activeConnections.length;
        if (activeConnections.length > 0) {
          this.connectionPool.set(userId, activeConnections);
        } else {
          this.connectionPool.delete(userId);
        }
      }
    }

    if (cleanedConnections > 0) {
      this.logger.debug('Connection pool cleanup completed', {
        cleanedConnections,
        remainingPoolSize: Array.from(this.connectionPool.values())
          .reduce((sum, pool) => sum + pool.length, 0),
      });
    }
  }

  /**
   * Get comprehensive performance metrics
   * @returns {Object} Enhanced performance metrics
   */
  getPerformanceMetrics() {
    const stats = this.getStats();
    const recentResponseTimes = this.metrics.recentResponseTimes;

    // Calculate percentiles
    let p95ResponseTime = 0;
    let p99ResponseTime = 0;
    if (recentResponseTimes.length > 0) {
      const sorted = [...recentResponseTimes].sort((a, b) => a - b);
      const p95Index = Math.floor(sorted.length * 0.95);
      const p99Index = Math.floor(sorted.length * 0.99);
      p95ResponseTime = sorted[p95Index] || 0;
      p99ResponseTime = sorted[p99Index] || 0;
    }

    // Calculate throughput (requests per minute)
    const throughput = this.metrics.requestTimestamps.length;

    return {
      ...stats,
      enhanced: {
        p95ResponseTime: Math.round(p95ResponseTime * 100) / 100,
        p99ResponseTime: Math.round(p99ResponseTime * 100) / 100,
        throughputPerMinute: throughput,
        memoryUsageMB: Math.round((this.metrics.memoryUsage / (1024 * 1024)) * 100) / 100,
        peakMemoryUsageMB: Math.round((this.metrics.peakMemoryUsage / (1024 * 1024)) * 100) / 100,
        connectionPoolStats: {
          totalPooledConnections: Array.from(this.connectionPool.values())
            .reduce((sum, pool) => sum + pool.length, 0),
          poolHits: this.metrics.connectionPoolHits,
          poolMisses: this.metrics.connectionPoolMisses,
          poolEfficiency: this.metrics.connectionPoolHits + this.metrics.connectionPoolMisses > 0
            ? Math.round((this.metrics.connectionPoolHits / (this.metrics.connectionPoolHits + this.metrics.connectionPoolMisses)) * 10000) / 100
            : 0,
        },
        queueStats: {
          currentQueueSize: this.metrics.queuedMessages,
          peakQueueSize: this.metrics.peakQueuedMessages,
        },
        alerts: this.performanceAlerts,
        lastPerformanceCheck: this.lastPerformanceCheck,
      },
    };
  }

  /**
   * Get proxy statistics with enhanced metrics
   * @returns {Object} Proxy statistics
   */
  getStats() {
    const totalConnections = this.connections.size;
    const totalPendingRequests = Array.from(this.connections.values())
      .reduce((sum, conn) => sum + conn.pendingRequests.size, 0);

    const successRate = this.metrics.totalRequests > 0
      ? (this.metrics.successfulRequests / this.metrics.totalRequests) * 100
      : 0;

    const timeoutRate = this.metrics.totalRequests > 0
      ? (this.metrics.timeoutRequests / this.metrics.totalRequests) * 100
      : 0;

    return {
      connections: {
        total: totalConnections,
        connectedUsers: this.userConnections.size,
        totalCreated: this.metrics.connectionCount,
      },
      requests: {
        total: this.metrics.totalRequests,
        successful: this.metrics.successfulRequests,
        failed: this.metrics.failedRequests,
        timeout: this.metrics.timeoutRequests,
        pending: totalPendingRequests,
        successRate: Math.round(successRate * 100) / 100,
        timeoutRate: Math.round(timeoutRate * 100) / 100,
      },
      performance: {
        averageResponseTime: Math.round(this.metrics.averageResponseTime * 100) / 100,
      },
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Get health status of the tunnel proxy
   * @returns {Object} Health status
   */
  getHealthStatus() {
    const stats = this.getStats();

    // For on-demand tunnel architecture, the system is healthy if:
    // 1. The tunnel creation system is operational (always true if this method runs)
    // 2. If there are active connections, they should have good performance
    // 3. Zero connections is perfectly healthy in on-demand architecture

    const hasConnections = stats.connections.total > 0;
    const connectionPerformanceOk = !hasConnections || (
      stats.requests.successRate > 80 &&
      stats.requests.timeoutRate < 20 &&
      stats.performance.averageResponseTime < 5000
    );

    // System is healthy if tunnel creation capability is available
    // (which it is, since this method is running) and any active connections perform well
    const isHealthy = connectionPerformanceOk;

    return {
      status: isHealthy ? 'ready' : 'degraded',
      architecture: 'on-demand',
      tunnelCreationAvailable: true,
      checks: {
        tunnelCreationSystemOperational: true,
        connectionPerformanceOk: connectionPerformanceOk,
        successRateOk: !hasConnections || stats.requests.successRate > 80,
        timeoutRateOk: !hasConnections || stats.requests.timeoutRate < 20,
        averageResponseTimeOk: !hasConnections || stats.performance.averageResponseTime < 5000,
      },
      connections: {
        active: stats.connections.total,
        expected: 'created-on-user-login',
      },
      ...stats,
    };
  }

  /**
   * Clean up all connections and intervals
   */
  cleanup() {
    // Stop all ping intervals
    for (const interval of this.pingIntervals.values()) {
      clearInterval(interval);
    }
    this.pingIntervals.clear();

    // Close all connections
    for (const connection of this.connections.values()) {
      if (connection.websocket.readyState === WebSocket.OPEN) {
        connection.websocket.close();
      }

      // Clean up pending requests
      for (const pendingRequest of connection.pendingRequests.values()) {
        clearTimeout(pendingRequest.timeout);
        pendingRequest.reject(new Error('Service shutdown'));
      }
    }

    this.connections.clear();
    this.userConnections.clear();
  }
}
