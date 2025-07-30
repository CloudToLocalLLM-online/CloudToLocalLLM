/**
 * @fileoverview HTTP-based tunnel proxy service for cloud-side request routing
 * Uses HTTP polling instead of WebSocket connections for desktop client communication
 */

import { v4 as uuidv4 } from 'uuid';
import winston from 'winston';
import { TunnelLogger, ERROR_CODES } from '../utils/logger.js';
import { queueRequestForBridge, getResponseForRequest, getBridgeByUserId, isBridgeAvailable } from '../routes/bridge-polling-routes.js';

/**
 * HTTP-based tunnel proxy service
 * Manages HTTP polling connections from desktop clients and routes HTTP requests
 */
export class HttpTunnelProxy {
  constructor(logger = winston.createLogger()) {
    // Use enhanced logger if winston logger provided, otherwise create new TunnelLogger
    this.logger = logger instanceof TunnelLogger ? logger : new TunnelLogger('http-tunnel-proxy');

    this.REQUEST_TIMEOUT = 30000; // 30 seconds (default)
    this.LLM_REQUEST_TIMEOUT = 120000; // 2 minutes for LLM requests

    // Enhanced performance metrics
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

    // Start metrics collection
    this.startMetricsCollection();
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
    const startTime = Date.now();

    // Find bridge for user
    const bridge = getBridgeByUserId(userId);
    if (!bridge || !isBridgeAvailable(bridge.bridgeId)) {
      const error = new Error('Desktop client not connected');
      error.code = ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED;
      throw error;
    }

    // Update metrics
    this.metrics.totalRequests++;
    if (timeoutMs > this.REQUEST_TIMEOUT) {
      this.metrics.llmRequests++;
    }

    // Track request analytics
    this.trackRequestAnalytics(httpRequest);

    try {
      // Create request message
      const requestMessage = {
        type: 'http_request',
        id: uuidv4(),
        data: {
          method: httpRequest.method,
          path: httpRequest.path,
          headers: httpRequest.headers || {},
          ...(httpRequest.body && { body: httpRequest.body }),
        },
        timestamp: new Date().toISOString(),
      };

      // Queue request for bridge
      const requestId = queueRequestForBridge(bridge.bridgeId, requestMessage);

      this.logger.logRequest('started', requestId, userId, {
        bridgeId: bridge.bridgeId,
        method: httpRequest.method,
        path: httpRequest.path,
        timeout: timeoutMs,
        isLLMRequest: timeoutMs > this.REQUEST_TIMEOUT,
      });

      // Wait for response
      const response = await getResponseForRequest(requestId, timeoutMs);

      const responseTime = Date.now() - startTime;
      this.updateMetrics(true, responseTime, timeoutMs > this.REQUEST_TIMEOUT);

      this.logger.logRequest('completed', requestId, userId, {
        bridgeId: bridge.bridgeId,
        responseTime,
        statusCode: response.status,
        isLLMRequest: timeoutMs > this.REQUEST_TIMEOUT,
      });

      return {
        status: response.status || 200,
        statusCode: response.status || 200,
        headers: response.headers || {},
        body: response.body,
      };

    } catch (error) {
      const responseTime = Date.now() - startTime;
      const isTimeout = error.message.includes('timeout');

      this.updateMetrics(false, responseTime, timeoutMs > this.REQUEST_TIMEOUT, isTimeout);

      this.logger.logTunnelError(
        isTimeout ? ERROR_CODES.REQUEST_TIMEOUT : ERROR_CODES.REQUEST_FAILED,
        `HTTP request failed: ${error.message}`,
        {
          userId,
          bridgeId: bridge.bridgeId,
          method: httpRequest.method,
          path: httpRequest.path,
          responseTime,
          isLLMRequest: timeoutMs > this.REQUEST_TIMEOUT,
          error: error.message,
        },
      );

      throw error;
    }
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
    const bridge = getBridgeByUserId(userId);
    return bridge && isBridgeAvailable(bridge.bridgeId);
  }

  /**
   * Get connection status for a user
   * @param {string} userId - User ID
   * @returns {Object} Connection status object
   */
  getUserConnectionStatus(userId) {
    const bridge = getBridgeByUserId(userId);

    if (!bridge) {
      return {
        connected: false,
        status: 'not_registered',
        message: 'Desktop client not registered',
      };
    }

    const isAvailable = isBridgeAvailable(bridge.bridgeId);

    return {
      connected: isAvailable,
      status: isAvailable ? 'connected' : 'disconnected',
      bridgeId: bridge.bridgeId,
      lastSeen: bridge.lastSeen,
      platform: bridge.platform,
      version: bridge.version,
      capabilities: bridge.capabilities,
    };
  }

  /**
   * Update performance metrics
   */
  updateMetrics(success, responseTime, isLLMRequest = false, isTimeout = false) {
    if (success) {
      this.metrics.successfulRequests++;
      if (isLLMRequest) {
        this.metrics.llmSuccessfulRequests++;
      }
    } else {
      this.metrics.failedRequests++;
      if (isLLMRequest) {
        this.metrics.llmFailedRequests++;
      }

      if (isTimeout) {
        this.metrics.timeoutRequests++;
        if (isLLMRequest) {
          this.metrics.llmTimeoutRequests++;
        }
      }
    }

    // Update response time tracking
    this.metrics.recentResponseTimes.push(responseTime);
    if (this.metrics.recentResponseTimes.length > 100) {
      this.metrics.recentResponseTimes.shift();
    }

    if (isLLMRequest) {
      this.metrics.llmRecentResponseTimes.push(responseTime);
      if (this.metrics.llmRecentResponseTimes.length > 100) {
        this.metrics.llmRecentResponseTimes.shift();
      }
    }

    // Calculate averages
    this.metrics.averageResponseTime = this.metrics.recentResponseTimes.reduce((a, b) => a + b, 0) / this.metrics.recentResponseTimes.length;
    if (this.metrics.llmRecentResponseTimes.length > 0) {
      this.metrics.llmAverageResponseTime = this.metrics.llmRecentResponseTimes.reduce((a, b) => a + b, 0) / this.metrics.llmRecentResponseTimes.length;
    }
  }

  /**
   * Track request analytics
   */
  trackRequestAnalytics(httpRequest) {
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
   * Track model operations
   */
  trackModelOperation(path, method) {
    if (path.includes('/api/models') && method === 'GET') {
      this.metrics.modelOperations.list++;
    } else if (path.includes('/api/pull')) {
      this.metrics.modelOperations.pull++;
    } else if (path.includes('/api/delete')) {
      this.metrics.modelOperations.delete++;
    } else if (path.includes('/api/show')) {
      this.metrics.modelOperations.show++;
    }
  }

  /**
   * Track provider usage
   */
  trackProviderUsage(httpRequest) {
    const userAgent = httpRequest.headers?.['user-agent'] || '';

    if (userAgent.includes('ollama')) {
      this.metrics.providerStats.ollama++;
    } else if (userAgent.includes('lmstudio')) {
      this.metrics.providerStats.lmstudio++;
    } else if (userAgent.includes('openai')) {
      this.metrics.providerStats.openai++;
    } else {
      this.metrics.providerStats.other++;
    }
  }

  /**
   * Check if request is streaming
   */
  isStreamingRequest(httpRequest) {
    return httpRequest.headers?.['accept']?.includes('text/event-stream') ||
           httpRequest.path?.includes('/stream') ||
           httpRequest.body?.includes('"stream":true');
  }

  /**
   * Start metrics collection
   */
  startMetricsCollection() {
    setInterval(() => {
      this.metrics.memoryUsage = process.memoryUsage().heapUsed;
      if (this.metrics.memoryUsage > this.metrics.peakMemoryUsage) {
        this.metrics.peakMemoryUsage = this.metrics.memoryUsage;
      }
    }, 30000); // Every 30 seconds
  }

  /**
   * Get comprehensive metrics
   */
  getMetrics() {
    return { ...this.metrics };
  }

  /**
   * Get health status
   */
  getHealthStatus() {
    const stats = this.getMetrics();
    const hasRequests = stats.totalRequests > 0;

    // Performance checks
    const connectionPerformanceOk = !hasRequests || stats.averageResponseTime < 10000;

    return {
      status: connectionPerformanceOk ? 'ready' : 'degraded',
      architecture: 'http-polling',
      tunnelCreationAvailable: true,
      checks: {
        tunnelCreationSystemOperational: true,
        connectionPerformanceOk: connectionPerformanceOk,
        successRateOk: !hasRequests || (stats.successfulRequests / stats.totalRequests) > 0.8,
        timeoutRateOk: !hasRequests || (stats.timeoutRequests / stats.totalRequests) < 0.2,
        averageResponseTimeOk: !hasRequests || stats.averageResponseTime < 5000,
      },
      connections: {
        active: 'managed-by-bridge-polling',
        expected: 'created-on-user-login',
      },
      ...stats,
    };
  }

  /**
   * Clean up resources (no-op for HTTP polling)
   */
  cleanup() {
    // HTTP polling doesn't need cleanup like WebSocket connections
    this.logger.info('HTTP tunnel proxy cleanup completed');
  }
}
