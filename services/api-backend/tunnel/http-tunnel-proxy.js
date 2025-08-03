/**
 * @fileoverview HTTP-based tunnel proxy service for cloud-side request routing
 * Uses HTTP polling instead of WebSocket connections for desktop client communication
 * Enhanced with LLM-specific request handling, routing, and prioritization
 */

import { v4 as uuidv4 } from 'uuid';
import winston from 'winston';
import { TunnelLogger, ERROR_CODES } from '../utils/logger.js';
import { queueRequestForBridge, getResponseForRequest, getBridgeByUserId, isBridgeAvailable } from '../routes/bridge-polling-routes.js';

/**
 * LLM request types for routing and timeout handling
 */
export const LLM_REQUEST_TYPES = {
  CHAT: 'chat',
  MODEL_LIST: 'model_list',
  MODEL_PULL: 'model_pull',
  MODEL_DELETE: 'model_delete',
  MODEL_INFO: 'model_info',
  STREAMING: 'streaming',
  HEALTH_CHECK: 'health_check',
  EMBEDDINGS: 'embeddings',
  COMPLETION: 'completion'
};

/**
 * Request priority levels for queue management
 */
export const REQUEST_PRIORITY = {
  HIGH: 1,    // Health checks, model info
  NORMAL: 2,  // Chat, completion requests
  LOW: 3      // Model operations (pull, delete)
};

/**
 * User tier definitions for request prioritization
 */
export const USER_TIERS = {
  PREMIUM: 'premium',
  STANDARD: 'standard',
  FREE: 'free'
};

/**
 * HTTP-based tunnel proxy service
 * 
 * Manages HTTP polling connections from desktop clients and routes HTTP requests
 * with enhanced LLM-specific functionality including:
 * - Intelligent request classification and routing
 * - Provider-aware timeout handling
 * - Request prioritization based on user tier and operation type
 * - Comprehensive metrics and error tracking
 * 
 * @class HttpTunnelProxy
 */
export class HttpTunnelProxy {
  /**
   * Create a new HttpTunnelProxy instance
   * 
   * @param {winston.Logger} [logger] - Winston logger instance for logging
   */
  constructor(logger = winston.createLogger()) {
    // Use enhanced logger if winston logger provided, otherwise create new TunnelLogger
    this.logger = logger instanceof TunnelLogger ? logger : new TunnelLogger('http-tunnel-proxy');

    // Enhanced timeout configuration for different LLM operation types
    this.TIMEOUTS = {
      DEFAULT: 30000,           // 30 seconds (default)
      CHAT: 120000,            // 2 minutes for chat requests
      STREAMING: 300000,       // 5 minutes for streaming requests
      MODEL_PULL: 600000,      // 10 minutes for model downloads
      MODEL_DELETE: 60000,     // 1 minute for model deletion
      MODEL_LIST: 15000,       // 15 seconds for model listing
      MODEL_INFO: 30000,       // 30 seconds for model info
      HEALTH_CHECK: 10000,     // 10 seconds for health checks
      EMBEDDINGS: 90000,       // 1.5 minutes for embeddings
      COMPLETION: 120000       // 2 minutes for completions
    };

    // Request queue for prioritization
    this.requestQueue = {
      [REQUEST_PRIORITY.HIGH]: [],
      [REQUEST_PRIORITY.NORMAL]: [],
      [REQUEST_PRIORITY.LOW]: []
    };

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
   * Forward LLM request to desktop client with intelligent routing and timeout
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @param {string} userTier - User tier for prioritization
   * @param {string} preferredProvider - Preferred LLM provider
   * @returns {Promise<Object>} HTTP response object
   */
  async forwardLLMRequest(userId, httpRequest, userTier = USER_TIERS.STANDARD, preferredProvider = null) {
    // Classify the LLM request type
    const requestType = this.classifyLLMRequest(httpRequest);
    
    // Get appropriate timeout for request type
    const timeout = this.getTimeoutForRequestType(requestType);
    
    // Get request priority based on type and user tier
    const priority = this.getRequestPriority(requestType, userTier);
    
    // Enhance request with LLM-specific metadata
    const enhancedRequest = {
      ...httpRequest,
      llmMetadata: {
        requestType,
        priority,
        userTier,
        preferredProvider,
        timestamp: Date.now(),
        timeout
      }
    };

    this.logger.info('Processing LLM request', {
      userId,
      requestType,
      priority,
      userTier,
      preferredProvider,
      timeout,
      path: httpRequest.path
    });

    return this.forwardRequestWithTimeout(userId, enhancedRequest, timeout);
  }

  /**
   * Classify LLM request type based on path and method
   * @param {Object} httpRequest - HTTP request object
   * @returns {string} LLM request type
   */
  classifyLLMRequest(httpRequest) {
    const { path, method, headers, body } = httpRequest;
    const pathLower = path.toLowerCase();

    // Check for streaming requests
    if (headers?.['accept']?.includes('text/event-stream') || 
        pathLower.includes('/stream') || 
        (body && body.includes('"stream":true'))) {
      return LLM_REQUEST_TYPES.STREAMING;
    }

    // Model operations
    if (pathLower.includes('/api/models') && method === 'GET') {
      return LLM_REQUEST_TYPES.MODEL_LIST;
    }
    if (pathLower.includes('/api/pull')) {
      return LLM_REQUEST_TYPES.MODEL_PULL;
    }
    if (pathLower.includes('/api/delete')) {
      return LLM_REQUEST_TYPES.MODEL_DELETE;
    }
    if (pathLower.includes('/api/show') || pathLower.includes('/api/model')) {
      return LLM_REQUEST_TYPES.MODEL_INFO;
    }

    // Chat and completion requests
    if (pathLower.includes('/api/chat') || pathLower.includes('/chat')) {
      return LLM_REQUEST_TYPES.CHAT;
    }
    if (pathLower.includes('/api/generate') || pathLower.includes('/completion')) {
      return LLM_REQUEST_TYPES.COMPLETION;
    }
    if (pathLower.includes('/api/embeddings') || pathLower.includes('/embeddings')) {
      return LLM_REQUEST_TYPES.EMBEDDINGS;
    }

    // Health checks
    if (pathLower.includes('/health') || pathLower.includes('/status')) {
      return LLM_REQUEST_TYPES.HEALTH_CHECK;
    }

    // Default to chat for unknown LLM requests
    return LLM_REQUEST_TYPES.CHAT;
  }

  /**
   * Get timeout for specific request type
   * @param {string} requestType - LLM request type
   * @returns {number} Timeout in milliseconds
   */
  getTimeoutForRequestType(requestType) {
    switch (requestType) {
    case LLM_REQUEST_TYPES.STREAMING:
      return this.TIMEOUTS.STREAMING;
    case LLM_REQUEST_TYPES.MODEL_PULL:
      return this.TIMEOUTS.MODEL_PULL;
    case LLM_REQUEST_TYPES.MODEL_DELETE:
      return this.TIMEOUTS.MODEL_DELETE;
    case LLM_REQUEST_TYPES.MODEL_LIST:
      return this.TIMEOUTS.MODEL_LIST;
    case LLM_REQUEST_TYPES.MODEL_INFO:
      return this.TIMEOUTS.MODEL_INFO;
    case LLM_REQUEST_TYPES.HEALTH_CHECK:
      return this.TIMEOUTS.HEALTH_CHECK;
    case LLM_REQUEST_TYPES.EMBEDDINGS:
      return this.TIMEOUTS.EMBEDDINGS;
    case LLM_REQUEST_TYPES.COMPLETION:
      return this.TIMEOUTS.COMPLETION;
    case LLM_REQUEST_TYPES.CHAT:
    default:
      return this.TIMEOUTS.CHAT;
    }
  }

  /**
   * Get request priority based on type and user tier
   * @param {string} requestType - LLM request type
   * @param {string} userTier - User tier
   * @returns {number} Priority level
   */
  getRequestPriority(requestType, userTier) {
    // High priority requests
    if (requestType === LLM_REQUEST_TYPES.HEALTH_CHECK || 
        requestType === LLM_REQUEST_TYPES.MODEL_INFO) {
      return REQUEST_PRIORITY.HIGH;
    }

    // Low priority requests
    if (requestType === LLM_REQUEST_TYPES.MODEL_PULL || 
        requestType === LLM_REQUEST_TYPES.MODEL_DELETE) {
      return REQUEST_PRIORITY.LOW;
    }

    // Premium users get higher priority for normal requests
    if (userTier === USER_TIERS.PREMIUM) {
      return REQUEST_PRIORITY.HIGH;
    }

    // Standard priority for most requests
    return REQUEST_PRIORITY.NORMAL;
  }

  /**
   * Forward HTTP request to desktop client with custom timeout and LLM routing
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @param {number} customTimeout - Custom timeout in milliseconds
   * @returns {Promise<Object>} HTTP response object
   */
  async forwardRequestWithTimeout(userId, httpRequest, customTimeout = null) {
    const timeoutMs = customTimeout || (httpRequest.timeout || this.TIMEOUTS.DEFAULT);
    const startTime = Date.now();
    const isLLMRequest = httpRequest.llmMetadata != null;

    // Find bridge for user
    const bridge = getBridgeByUserId(userId);
    if (!bridge || !isBridgeAvailable(bridge.bridgeId)) {
      const error = new Error('Desktop client not connected');
      error.code = ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED;
      throw error;
    }

    // Update metrics
    this.metrics.totalRequests++;
    if (isLLMRequest) {
      this.metrics.llmRequests++;
      this.trackLLMRequestType(httpRequest.llmMetadata.requestType);
    }

    // Track request analytics
    this.trackRequestAnalytics(httpRequest);

    try {
      // Create enhanced request message with LLM routing information
      const requestMessage = {
        type: isLLMRequest ? 'llm_request' : 'http_request',
        id: uuidv4(),
        data: {
          method: httpRequest.method,
          path: httpRequest.path,
          headers: httpRequest.headers || {},
          ...(httpRequest.body && { body: httpRequest.body }),
          // Add LLM-specific routing metadata
          ...(isLLMRequest && {
            llmMetadata: {
              requestType: httpRequest.llmMetadata.requestType,
              priority: httpRequest.llmMetadata.priority,
              userTier: httpRequest.llmMetadata.userTier,
              preferredProvider: httpRequest.llmMetadata.preferredProvider,
              timeout: timeoutMs
            }
          })
        },
        timestamp: new Date().toISOString(),
        priority: isLLMRequest ? httpRequest.llmMetadata.priority : REQUEST_PRIORITY.NORMAL,
      };

      // Queue request for bridge with priority handling
      const requestId = this.queueRequestWithPriority(bridge.bridgeId, requestMessage);

      this.logger.logRequest('started', requestId, userId, {
        bridgeId: bridge.bridgeId,
        method: httpRequest.method,
        path: httpRequest.path,
        timeout: timeoutMs,
        isLLMRequest,
        ...(isLLMRequest && {
          requestType: httpRequest.llmMetadata.requestType,
          priority: httpRequest.llmMetadata.priority,
          userTier: httpRequest.llmMetadata.userTier,
          preferredProvider: httpRequest.llmMetadata.preferredProvider
        })
      });

      // Wait for response
      const response = await getResponseForRequest(requestId, timeoutMs);

      const responseTime = Date.now() - startTime;
      this.updateMetrics(true, responseTime, isLLMRequest);

      this.logger.logRequest('completed', requestId, userId, {
        bridgeId: bridge.bridgeId,
        responseTime,
        statusCode: response.status,
        isLLMRequest,
        ...(isLLMRequest && {
          requestType: httpRequest.llmMetadata.requestType,
          priority: httpRequest.llmMetadata.priority
        })
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

      this.updateMetrics(false, responseTime, isLLMRequest, isTimeout);

      this.logger.logTunnelError(
        isTimeout ? ERROR_CODES.REQUEST_TIMEOUT : ERROR_CODES.REQUEST_FAILED,
        `HTTP request failed: ${error.message}`,
        {
          userId,
          bridgeId: bridge.bridgeId,
          method: httpRequest.method,
          path: httpRequest.path,
          responseTime,
          isLLMRequest,
          error: error.message,
          ...(isLLMRequest && {
            requestType: httpRequest.llmMetadata.requestType,
            priority: httpRequest.llmMetadata.priority,
            preferredProvider: httpRequest.llmMetadata.preferredProvider
          })
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
   * Queue request with priority handling
   * @param {string} bridgeId - Bridge ID
   * @param {Object} requestMessage - Request message
   * @returns {string} Request ID
   */
  queueRequestWithPriority(bridgeId, requestMessage) {
    // For now, use the existing queueRequestForBridge function
    // In a full implementation, this would handle priority queuing
    return queueRequestForBridge(bridgeId, requestMessage);
  }

  /**
   * Track LLM request type metrics
   * @param {string} requestType - LLM request type
   */
  trackLLMRequestType(requestType) {
    if (!this.metrics.llmRequestTypes) {
      this.metrics.llmRequestTypes = {};
    }
    
    if (!this.metrics.llmRequestTypes[requestType]) {
      this.metrics.llmRequestTypes[requestType] = 0;
    }
    
    this.metrics.llmRequestTypes[requestType]++;
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

    // Track LLM-specific analytics
    if (httpRequest.llmMetadata) {
      this.trackLLMAnalytics(httpRequest.llmMetadata);
    }
  }

  /**
   * Track LLM-specific analytics
   * @param {Object} llmMetadata - LLM metadata
   */
  trackLLMAnalytics(llmMetadata) {
    // Track user tier distribution
    if (!this.metrics.userTierDistribution) {
      this.metrics.userTierDistribution = {};
    }
    if (!this.metrics.userTierDistribution[llmMetadata.userTier]) {
      this.metrics.userTierDistribution[llmMetadata.userTier] = 0;
    }
    this.metrics.userTierDistribution[llmMetadata.userTier]++;

    // Track preferred provider usage
    if (llmMetadata.preferredProvider) {
      if (!this.metrics.preferredProviders) {
        this.metrics.preferredProviders = {};
      }
      if (!this.metrics.preferredProviders[llmMetadata.preferredProvider]) {
        this.metrics.preferredProviders[llmMetadata.preferredProvider] = 0;
      }
      this.metrics.preferredProviders[llmMetadata.preferredProvider]++;
    }

    // Track priority distribution
    if (!this.metrics.priorityDistribution) {
      this.metrics.priorityDistribution = {};
    }
    if (!this.metrics.priorityDistribution[llmMetadata.priority]) {
      this.metrics.priorityDistribution[llmMetadata.priority] = 0;
    }
    this.metrics.priorityDistribution[llmMetadata.priority]++;
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
