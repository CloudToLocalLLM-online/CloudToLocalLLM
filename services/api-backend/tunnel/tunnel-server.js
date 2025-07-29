/**
 * @fileoverview Enhanced Tunnel Server for CloudToLocalLLM
 * Implements secure WebSocket-based tunnel system with comprehensive monitoring
 * and enterprise-grade security features
 */

import { WebSocketServer } from 'ws';
import { EventEmitter } from 'events';
import { TunnelLogger } from '../utils/logger.js';
import { createWebSocketSecurityValidator } from '../middleware/connection-security.js';
import { MessageProtocol, MESSAGE_TYPES } from './message-protocol.js';
import { TunnelMetrics } from './tunnel-metrics.js';
import { AuthService } from '../auth/auth-service.js';

/**
 * Enhanced Tunnel Server with enterprise features
 */
export class TunnelServer extends EventEmitter {
  constructor(server, config) {
    super();

    this.server = server;
    this.config = {
      maxConnections: 1000,
      heartbeatInterval: 30000,
      connectionTimeout: 60000,
      messageTimeout: 30000,
      compressionEnabled: true,
      ...config,
    };

    this.logger = new TunnelLogger('tunnel-server');
    this.metrics = new TunnelMetrics();
    this.connections = new Map(); // userId -> WebSocket
    this.pendingRequests = new Map(); // correlationId -> { resolve, reject, timeout }

    // Use AuthService for JWT validation (eliminates jwks-client issues)
    this.authService = new AuthService(config);

    // WebSocket security validator
    this.securityValidator = createWebSocketSecurityValidator({
      enforceHttps: process.env.NODE_ENV === 'production',
      minTlsVersion: 'TLSv1.2',
      allowSelfSignedCerts: process.env.NODE_ENV !== 'production',
      websocketOriginCheck: true,
      allowedOrigins: [
        'https://app.cloudtolocalllm.online',
        'https://cloudtolocalllm.online',
        'https://docs.cloudtolocalllm.online',
        ...(process.env.NODE_ENV !== 'production' ? ['http://localhost:3000', 'http://localhost:8080'] : []),
      ],
    });

    this.wss = null;
    this.heartbeatInterval = null;

    this.setupEventHandlers();
  }

  /**
   * Start the tunnel server
   */
  start() {
    this.wss = new WebSocketServer({
      server: this.server,
      path: '/ws/tunnel',
      verifyClient: this.verifyClient.bind(this),
      perMessageDeflate: this.config.compressionEnabled,
    });

    this.wss.on('connection', this.handleConnection.bind(this));
    this.wss.on('error', this.handleServerError.bind(this));

    // Start heartbeat mechanism
    this.startHeartbeat();

    this.logger.info('Tunnel server started', {
      path: '/ws/tunnel',
      maxConnections: this.config.maxConnections,
      compression: this.config.compressionEnabled,
    });

    this.emit('started');
  }

  /**
   * Stop the tunnel server
   */
  stop() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }

    // Close all connections gracefully
    this.connections.forEach((ws, userId) => {
      this.closeConnection(userId, 1001, 'Server shutting down');
    });

    if (this.wss) {
      this.wss.close();
      this.wss = null;
    }

    this.logger.info('Tunnel server stopped');
    this.emit('stopped');
  }

  /**
   * Verify client connection
   */
  async verifyClient(info) {
    try {
      // Security validation
      if (!this.securityValidator(info)) {
        this.logger.warn('Connection rejected by security validator', {
          origin: info.origin,
          ip: info.req.socket.remoteAddress,
        });
        return false;
      }

      // Check connection limit
      if (this.connections.size >= this.config.maxConnections) {
        this.logger.warn('Connection rejected: max connections reached', {
          current: this.connections.size,
          max: this.config.maxConnections,
        });
        this.metrics.incrementCounter('connections_rejected_limit');
        return false;
      }

      // Extract and validate JWT token
      const token = this.extractToken(info.req);
      if (!token) {
        this.logger.warn('Connection rejected: no token provided');
        this.metrics.incrementCounter('connections_rejected_auth');
        return false;
      }

      const userId = await this.validateToken(token);
      if (!userId) {
        this.logger.warn('Connection rejected: invalid token');
        this.metrics.incrementCounter('connections_rejected_auth');
        return false;
      }

      // Store user ID for connection handler
      info.req.userId = userId;
      info.req.token = token;

      return true;
    } catch (error) {
      this.logger.error('Error verifying client', { error: error.message });
      this.metrics.incrementCounter('connections_rejected_error');
      return false;
    }
  }

  /**
   * Handle new WebSocket connection
   */
  handleConnection(ws, req) {
    const userId = req.userId;
    const correlationId = this.logger.generateCorrelationId();

    // Close existing connection for this user
    if (this.connections.has(userId)) {
      this.closeConnection(userId, 1000, 'New connection established');
    }

    // Setup connection
    ws.userId = userId;
    ws.correlationId = correlationId;
    ws.isAlive = true;
    ws.connectedAt = Date.now();

    this.connections.set(userId, ws);
    this.metrics.setGauge('active_connections', this.connections.size);
    this.metrics.incrementCounter('connections_established');

    this.logger.info('Tunnel connection established', {
      userId,
      correlationId,
      totalConnections: this.connections.size,
    });

    // Setup event handlers
    ws.on('message', (data) => this.handleMessage(ws, data));
    ws.on('close', (code, reason) => this.handleDisconnection(ws, code, reason));
    ws.on('error', (error) => this.handleConnectionError(ws, error));
    ws.on('pong', () => {
      ws.isAlive = true;
    });

    // Send connection acknowledgment
    this.sendMessage(ws, {
      type: 'connection_ack',
      id: correlationId,
      timestamp: new Date().toISOString(),
    });

    this.emit('connection', { userId, correlationId });
  }

  /**
   * Handle incoming WebSocket message
   */
  async handleMessage(ws, data) {
    const startTime = Date.now();

    try {
      const message = MessageProtocol.deserialize(data);

      this.logger.debug('Received message', {
        userId: ws.userId,
        type: message.type,
        id: message.id,
      });

      this.metrics.incrementCounter('messages_received');

      switch (message.type) {
      case MESSAGE_TYPES.HTTP_RESPONSE:
        await this.handleHttpResponse(message);
        break;

      case MESSAGE_TYPES.PONG:
        // Pong is handled by the 'pong' event
        break;

      case MESSAGE_TYPES.ERROR:
        await this.handleErrorMessage(message);
        break;

      default:
        this.logger.warn('Unknown message type', {
          userId: ws.userId,
          type: message.type,
        });
        this.metrics.incrementCounter('messages_unknown');
      }

      const latency = Date.now() - startTime;
      this.metrics.recordHistogram('message_latency_seconds', latency / 1000);

    } catch (error) {
      this.logger.error('Error handling message', {
        userId: ws.userId,
        error: error.message,
      });
      this.metrics.incrementCounter('message_errors');

      // Send error response
      this.sendMessage(ws, {
        type: MESSAGE_TYPES.ERROR,
        id: 'error',
        error: 'Message processing failed',
        code: 500,
      });
    }
  }

  /**
   * Handle HTTP response from desktop client
   */
  async handleHttpResponse(message) {
    const pending = this.pendingRequests.get(message.id);
    if (!pending) {
      this.logger.warn('Received response for unknown request', { id: message.id });
      return;
    }

    // Clear timeout
    clearTimeout(pending.timeout);
    this.pendingRequests.delete(message.id);

    // Resolve the pending promise
    pending.resolve({
      status: message.status,
      headers: message.headers,
      body: message.body,
    });

    this.metrics.incrementCounter('requests_completed');
  }

  /**
   * Handle error message from desktop client
   */
  async handleErrorMessage(message) {
    const pending = this.pendingRequests.get(message.id);
    if (!pending) {
      this.logger.warn('Received error for unknown request', { id: message.id });
      return;
    }

    // Clear timeout
    clearTimeout(pending.timeout);
    this.pendingRequests.delete(message.id);

    // Reject the pending promise
    pending.reject(new Error(message.error || 'Unknown error'));

    this.metrics.incrementCounter('requests_failed');
  }

  /**
   * Send HTTP request to desktop client
   */
  async sendHttpRequest(userId, httpRequest) {
    const ws = this.connections.get(userId);
    if (!ws || ws.readyState !== ws.OPEN) {
      throw new Error('User not connected');
    }

    const message = MessageProtocol.createRequestMessage(httpRequest);

    return new Promise((resolve, reject) => {
      // Set up timeout
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(message.id);
        reject(new Error('Request timeout'));
        this.metrics.incrementCounter('requests_timeout');
      }, this.config.messageTimeout);

      // Store pending request
      this.pendingRequests.set(message.id, { resolve, reject, timeout });

      // Send message
      this.sendMessage(ws, message);
      this.metrics.incrementCounter('requests_sent');
    });
  }

  /**
   * Send message to WebSocket
   */
  sendMessage(ws, message) {
    if (ws.readyState === ws.OPEN) {
      const data = MessageProtocol.serialize(message);
      ws.send(data);
    }
  }

  /**
   * Handle connection disconnection
   */
  handleDisconnection(ws, code, reason) {
    const userId = ws.userId;

    if (userId && this.connections.has(userId)) {
      this.connections.delete(userId);
      this.metrics.setGauge('active_connections', this.connections.size);
      this.metrics.incrementCounter('connections_closed');

      this.logger.info('Tunnel connection closed', {
        userId,
        code,
        reason: reason?.toString(),
        duration: Date.now() - ws.connectedAt,
      });

      this.emit('disconnection', { userId, code, reason });
    }
  }

  /**
   * Handle connection error
   */
  handleConnectionError(ws, error) {
    this.logger.error('Connection error', {
      userId: ws.userId,
      error: error.message,
    });
    this.metrics.incrementCounter('connection_errors');
  }

  /**
   * Handle server error
   */
  handleServerError(error) {
    this.logger.error('Server error', { error: error.message });
    this.metrics.incrementCounter('server_errors');
    this.emit('error', error);
  }

  /**
   * Close connection for user
   */
  closeConnection(userId, code = 1000, reason = 'Connection closed') {
    const ws = this.connections.get(userId);
    if (ws) {
      ws.close(code, reason);
    }
  }

  /**
   * Extract JWT token from request
   */
  extractToken(req) {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    // Check query parameter as fallback
    const url = new URL(req.url, 'http://localhost');
    return url.searchParams.get('token');
  }

  /**
   * Validate JWT token and extract user ID using AuthService
   */
  async validateToken(token) {
    try {
      const verified = await this.authService.validateToken(token);
      return verified.sub; // User ID
    } catch (error) {
      this.logger.warn('Token validation failed', { error: error.message });
      return null;
    }
  }

  // getSigningKey method removed - now handled by AuthService

  /**
   * Start heartbeat mechanism
   */
  startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      this.connections.forEach((ws, userId) => {
        if (!ws.isAlive) {
          this.logger.info('Terminating inactive connection', { userId });
          this.closeConnection(userId, 1001, 'Heartbeat timeout');
          return;
        }

        ws.isAlive = false;
        ws.ping();
      });
    }, this.config.heartbeatInterval);
  }

  /**
   * Setup event handlers
   */
  setupEventHandlers() {
    // Handle process termination
    process.on('SIGTERM', () => this.stop());
    process.on('SIGINT', () => this.stop());
  }

  /**
   * Get server statistics
   */
  getStats() {
    return {
      activeConnections: this.connections.size,
      maxConnections: this.config.maxConnections,
      pendingRequests: this.pendingRequests.size,
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      metrics: this.metrics.getMetrics(),
    };
  }
}
