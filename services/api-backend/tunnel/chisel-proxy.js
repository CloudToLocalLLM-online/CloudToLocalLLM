/**
 * @fileoverview ChiselProxy manages tunnel connections through Chisel reverse proxy
 * Handles user connections, request forwarding, and connection lifecycle
 */

import http from 'http';
import https from 'https';
import { URL } from 'url';
import { ChiselServer } from './chisel-server.js';
import { AuthService } from '../auth/auth-service.js';

const REQUEST_TIMEOUT = 30000; // 30 seconds

/**
 * Manages Chisel reverse proxy connections for tunneling HTTP requests
 */
export class ChiselProxy {
  /**
   * @param {Object} config - Configuration object
   * @param {winston.Logger} logger - Logger instance
   * @param {AuthService} authService - AuthService for JWT validation
   */
  constructor(logger, config, authService) {
    this.logger = logger;
    this.config = config;
    this.authService = authService;
    
    // Chisel server instance
    this.chiselServer = new ChiselServer(logger, {
      port: config.chiselPort || 8080,
      binary: config.chiselBinary,
    });

    // User connections: userId -> { port, localPort, timestamp }
    // When a Chisel client connects, it registers a reverse tunnel
    // The server assigns a port that forwards to the client's local port
    this.userConnections = new Map();
    
    // Track registered tunnels: tunnelId -> userId
    this.tunnelRegistry = new Map();

    // Metrics
    this.metrics = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      timeoutRequests: 0,
      connectionCount: 0,
      reconnectionCount: 0,
    };

    // Connection timeout cleanup
    this.connectionTimeouts = new Map();
  }

  /**
   * Start Chisel server
   * @returns {Promise<void>}
   */
  async start() {
    try {
      await this.chiselServer.start();
      this.logger.info('ChiselProxy started successfully', {
        port: this.chiselServer.port,
      });
    } catch (error) {
      this.logger.error('Failed to start ChiselProxy', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Stop Chisel server and cleanup
   * @returns {Promise<void>}
   */
  async stop() {
    await this.chiselServer.stop();
    this.userConnections.clear();
    this.tunnelRegistry.clear();
    this.logger.info('ChiselProxy stopped');
  }

  /**
   * Register a Chisel client connection
   * Called when a desktop client connects via Chisel
   * 
   * @param {string} userId - User ID from JWT
   * @param {string} tunnelId - Chisel tunnel identifier
   * @param {number} localPort - Local port on client (typically 11434 for Ollama)
   * @param {number} [serverPort] - Server-assigned port (if provided)
   * @returns {number} Server port assigned to this tunnel
   */
  registerClient(userId, tunnelId, localPort = 11434, serverPort = null) {
    // Clean up old connection if exists
    if (this.userConnections.has(userId)) {
      const oldConnection = this.userConnections.get(userId);
      this.logger.info('User reconnected, cleaning up old connection', {
        userId,
        oldPort: oldConnection.port,
      });
      this.metrics.reconnectionCount++;
    }

    // Assign port if not provided (simple sequential assignment)
    // In production, you'd want better port management
    const assignedPort = serverPort || (this.chiselServer.port + this.userConnections.size + 1);

    const connection = {
      userId,
      tunnelId,
      localPort,
      port: assignedPort,
      timestamp: new Date(),
    };

    this.userConnections.set(userId, connection);
    this.tunnelRegistry.set(tunnelId, userId);
    this.metrics.connectionCount++;

    // Set connection timeout (cleanup after 5 minutes of inactivity)
    this._setConnectionTimeout(userId);

    this.logger.info('Chisel client registered', {
      userId,
      tunnelId,
      localPort,
      serverPort: assignedPort,
      totalConnections: this.userConnections.size,
    });

    return assignedPort;
  }

  /**
   * Unregister a client connection
   * @param {string} userId - User ID
   */
  unregisterClient(userId) {
    const connection = this.userConnections.get(userId);
    if (connection) {
      this.tunnelRegistry.delete(connection.tunnelId);
      this.connectionTimeouts.delete(userId);
      this.userConnections.delete(userId);
      this.logger.info('Chisel client unregistered', { userId });
    }
  }

  /**
   * Set connection timeout for cleanup
   * @private
   * @param {string} userId - User ID
   */
  _setConnectionTimeout(userId) {
    // Clear existing timeout
    const existing = this.connectionTimeouts.get(userId);
    if (existing) {
      clearTimeout(existing);
    }

    // Set new timeout (5 minutes of inactivity)
    const timeout = setTimeout(() => {
      this.logger.warn('Connection timeout, cleaning up', { userId });
      this.unregisterClient(userId);
    }, 5 * 60 * 1000); // 5 minutes

    this.connectionTimeouts.set(userId, timeout);
  }

  /**
   * Forward HTTP request through Chisel tunnel
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @param {string} httpRequest.method - HTTP method
   * @param {string} httpRequest.path - Request path
   * @param {Object} httpRequest.headers - HTTP headers
   * @param {string} [httpRequest.body] - Request body
   * @returns {Promise<Object>} HTTP response
   */
  async forwardRequest(userId, httpRequest) {
    const connection = this.userConnections.get(userId);
    if (!connection) {
      const error = new Error('Desktop client not connected');
      error.code = 'DESKTOP_CLIENT_DISCONNECTED';
      throw error;
    }

    this.metrics.totalRequests++;

    // Reset connection timeout
    this._setConnectionTimeout(userId);

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.metrics.timeoutRequests++;
        this.metrics.failedRequests++;
        const error = new Error('Request timed out');
        error.code = 'REQUEST_TIMEOUT';
        reject(error);
      }, REQUEST_TIMEOUT);

      try {
        // Forward request to Chisel tunnel
        // Chisel reverse proxy maps serverPort -> client localPort
        // We make an HTTP request to localhost:serverPort which Chisel forwards
        const targetUrl = new URL(`http://localhost:${connection.port}${httpRequest.path}`);
        
        const requestOptions = {
          hostname: targetUrl.hostname,
          port: targetUrl.port,
          path: targetUrl.pathname + targetUrl.search,
          method: httpRequest.method,
          headers: {
            ...httpRequest.headers,
            'host': `localhost:${connection.port}`,
            // Remove headers that shouldn't be forwarded
            'connection': 'close',
          },
          timeout: REQUEST_TIMEOUT,
        };

        const client = targetUrl.protocol === 'https:' ? https : http;

        const req = client.request(requestOptions, (res) => {
          const chunks = [];
          
          res.on('data', (chunk) => {
            chunks.push(chunk);
          });

          res.on('end', () => {
            clearTimeout(timeout);
            const body = Buffer.concat(chunks).toString();
            
            this.metrics.successfulRequests++;
            
            resolve({
              status: res.statusCode,
              headers: res.headers,
              body: body,
            });
          });
        });

        req.on('error', (error) => {
          clearTimeout(timeout);
          this.metrics.failedRequests++;
          this.logger.error('Chisel tunnel request error', {
            userId,
            error: error.message,
          });
          reject(error);
        });

        req.on('timeout', () => {
          req.destroy();
          clearTimeout(timeout);
          this.metrics.timeoutRequests++;
          this.metrics.failedRequests++;
          const error = new Error('Request timeout');
          error.code = 'REQUEST_TIMEOUT';
          reject(error);
        });

        // Send request body if present
        if (httpRequest.body) {
          req.write(httpRequest.body);
        }

        req.end();

      } catch (error) {
        clearTimeout(timeout);
        this.metrics.failedRequests++;
        this.logger.error('Failed to forward request through Chisel', {
          userId,
          error: error.message,
        });
        reject(error);
      }
    });
  }

  /**
   * Check if user is connected
   * @param {string} userId - User ID
   * @returns {boolean}
   */
  isUserConnected(userId) {
    return this.userConnections.has(userId);
  }

  /**
   * Get user connection status
   * @param {string} userId - User ID
   * @returns {Object}
   */
  getUserConnectionStatus(userId) {
    const connection = this.userConnections.get(userId);
    if (!connection) {
      return {
        connected: false,
        pendingRequests: 0,
        lastPing: null,
      };
    }

    return {
      connected: true,
      port: connection.port,
      localPort: connection.localPort,
      timestamp: connection.timestamp,
    };
  }

  /**
   * Get health status
   * @returns {Object}
   */
  getHealthStatus() {
    const serverStatus = this.chiselServer.getStatus();
    return {
      status: serverStatus.running ? 'healthy' : 'degraded',
      chiselServer: serverStatus,
      connections: {
        total: this.userConnections.size,
        connectedUsers: Array.from(this.userConnections.keys()).length,
      },
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Get statistics
   * @returns {Object}
   */
  getStats() {
    return {
      connections: {
        total: this.userConnections.size,
        connectedUsers: this.userConnections.size,
      },
      requests: {
        total: this.metrics.totalRequests,
        successful: this.metrics.successfulRequests,
        failed: this.metrics.failedRequests,
        timeout: this.metrics.timeoutRequests,
        pending: 0, // Chisel doesn't track pending requests
      },
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Cleanup all connections
   */
  cleanup() {
    this.userConnections.clear();
    this.tunnelRegistry.clear();
    for (const timeout of this.connectionTimeouts.values()) {
      clearTimeout(timeout);
    }
    this.connectionTimeouts.clear();
    this.logger.info('ChiselProxy cleaned up');
  }
}

