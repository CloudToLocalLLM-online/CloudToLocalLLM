/**
 * @fileoverview Connection Manager for Tunnel System
 * Handles connection pooling, load balancing, and connection health monitoring
 */

import { EventEmitter } from 'events';
import { TunnelLogger } from '../utils/logger.js';

/**
 * Connection pool for managing tunnel connections
 */
export class ConnectionPool extends EventEmitter {
  constructor(options = {}) {
    super();

    this.options = {
      maxConnections: 1000,
      connectionTimeout: 60000,
      healthCheckInterval: 30000,
      maxIdleTime: 300000, // 5 minutes
      ...options,
    };

    this.logger = new TunnelLogger('connection-pool');
    this.connections = new Map(); // userId -> ConnectionInfo
    this.healthCheckInterval = null;

    this.startHealthChecks();
  }

  /**
   * Add connection to pool
   */
  addConnection(userId, ws, metadata = {}) {
    const connectionInfo = {
      ws,
      userId,
      connectedAt: Date.now(),
      lastActivity: Date.now(),
      isHealthy: true,
      requestCount: 0,
      errorCount: 0,
      metadata: {
        userAgent: metadata.userAgent,
        ip: metadata.ip,
        ...metadata,
      },
    };

    // Remove existing connection if any
    this.removeConnection(userId);

    this.connections.set(userId, connectionInfo);

    // Setup connection event handlers
    ws.on('message', () => this.updateActivity(userId));
    ws.on('close', () => this.removeConnection(userId));
    ws.on('error', () => this.incrementErrorCount(userId));

    this.logger.info('Connection added to pool', {
      userId,
      totalConnections: this.connections.size,
    });

    this.emit('connection_added', { userId, connectionInfo });

    return connectionInfo;
  }

  /**
   * Remove connection from pool
   */
  removeConnection(userId) {
    const connectionInfo = this.connections.get(userId);
    if (connectionInfo) {
      this.connections.delete(userId);

      // Calculate connection duration
      const duration = Date.now() - connectionInfo.connectedAt;

      this.logger.info('Connection removed from pool', {
        userId,
        duration,
        requestCount: connectionInfo.requestCount,
        errorCount: connectionInfo.errorCount,
        totalConnections: this.connections.size,
      });

      this.emit('connection_removed', { userId, connectionInfo, duration });
    }
  }

  /**
   * Get connection for user
   */
  getConnection(userId) {
    const connectionInfo = this.connections.get(userId);
    if (!connectionInfo) {
      return null;
    }

    // Check if connection is still valid
    if (connectionInfo.ws.readyState !== connectionInfo.ws.OPEN) {
      this.removeConnection(userId);
      return null;
    }

    this.updateActivity(userId);
    return connectionInfo;
  }

  /**
   * Check if user is connected
   */
  isConnected(userId) {
    const connectionInfo = this.connections.get(userId);
    return connectionInfo &&
           connectionInfo.ws.readyState === connectionInfo.ws.OPEN &&
           connectionInfo.isHealthy;
  }

  /**
   * Update last activity for connection
   */
  updateActivity(userId) {
    const connectionInfo = this.connections.get(userId);
    if (connectionInfo) {
      connectionInfo.lastActivity = Date.now();
    }
  }

  /**
   * Increment request count for connection
   */
  incrementRequestCount(userId) {
    const connectionInfo = this.connections.get(userId);
    if (connectionInfo) {
      connectionInfo.requestCount++;
    }
  }

  /**
   * Increment error count for connection
   */
  incrementErrorCount(userId) {
    const connectionInfo = this.connections.get(userId);
    if (connectionInfo) {
      connectionInfo.errorCount++;

      // Mark as unhealthy if too many errors
      if (connectionInfo.errorCount > 10) {
        connectionInfo.isHealthy = false;
        this.logger.warn('Connection marked as unhealthy due to errors', {
          userId,
          errorCount: connectionInfo.errorCount,
        });
      }
    }
  }

  /**
   * Get all connected users
   */
  getConnectedUsers() {
    return Array.from(this.connections.keys());
  }

  /**
   * Get connection statistics
   */
  getStats() {
    const stats = {
      totalConnections: this.connections.size,
      healthyConnections: 0,
      unhealthyConnections: 0,
      totalRequests: 0,
      totalErrors: 0,
      averageConnectionDuration: 0,
      oldestConnection: null,
      newestConnection: null,
    };

    let totalDuration = 0;
    let oldestTime = Date.now();
    let newestTime = 0;

    for (const [userId, connectionInfo] of this.connections) {
      if (connectionInfo.isHealthy) {
        stats.healthyConnections++;
      } else {
        stats.unhealthyConnections++;
      }

      stats.totalRequests += connectionInfo.requestCount;
      stats.totalErrors += connectionInfo.errorCount;

      const duration = Date.now() - connectionInfo.connectedAt;
      totalDuration += duration;

      if (connectionInfo.connectedAt < oldestTime) {
        oldestTime = connectionInfo.connectedAt;
        stats.oldestConnection = userId;
      }

      if (connectionInfo.connectedAt > newestTime) {
        newestTime = connectionInfo.connectedAt;
        stats.newestConnection = userId;
      }
    }

    if (this.connections.size > 0) {
      stats.averageConnectionDuration = totalDuration / this.connections.size;
    }

    return stats;
  }

  /**
   * Start health checks
   */
  startHealthChecks() {
    this.healthCheckInterval = setInterval(() => {
      this.performHealthChecks();
    }, this.options.healthCheckInterval);
  }

  /**
   * Stop health checks
   */
  stopHealthChecks() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
      this.healthCheckInterval = null;
    }
  }

  /**
   * Perform health checks on all connections
   */
  performHealthChecks() {
    const now = Date.now();
    const connectionsToRemove = [];

    for (const [userId, connectionInfo] of this.connections) {
      // Check if connection is idle for too long
      const idleTime = now - connectionInfo.lastActivity;
      if (idleTime > this.options.maxIdleTime) {
        this.logger.info('Removing idle connection', {
          userId,
          idleTime,
        });
        connectionsToRemove.push(userId);
        continue;
      }

      // Check WebSocket state
      if (connectionInfo.ws.readyState !== connectionInfo.ws.OPEN) {
        this.logger.info('Removing closed connection', { userId });
        connectionsToRemove.push(userId);
        continue;
      }

      // Send ping to check if connection is alive
      try {
        connectionInfo.ws.ping();
      } catch (error) {
        this.logger.warn('Failed to ping connection', {
          userId,
          error: error.message,
        });
        connectionsToRemove.push(userId);
      }
    }

    // Remove unhealthy connections
    connectionsToRemove.forEach(userId => {
      this.removeConnection(userId);
    });

    if (connectionsToRemove.length > 0) {
      this.logger.info('Health check completed', {
        removedConnections: connectionsToRemove.length,
        totalConnections: this.connections.size,
      });
    }
  }

  /**
   * Close all connections
   */
  closeAllConnections(code = 1000, reason = 'Server shutdown') {
    const userIds = Array.from(this.connections.keys());

    for (const userId of userIds) {
      const connectionInfo = this.connections.get(userId);
      if (connectionInfo && connectionInfo.ws.readyState === connectionInfo.ws.OPEN) {
        connectionInfo.ws.close(code, reason);
      }
    }

    this.connections.clear();
    this.stopHealthChecks();

    this.logger.info('All connections closed', {
      closedConnections: userIds.length,
    });
  }

  /**
   * Get connection details for user
   */
  getConnectionDetails(userId) {
    const connectionInfo = this.connections.get(userId);
    if (!connectionInfo) {
      return null;
    }

    return {
      userId,
      connectedAt: connectionInfo.connectedAt,
      lastActivity: connectionInfo.lastActivity,
      isHealthy: connectionInfo.isHealthy,
      requestCount: connectionInfo.requestCount,
      errorCount: connectionInfo.errorCount,
      duration: Date.now() - connectionInfo.connectedAt,
      idleTime: Date.now() - connectionInfo.lastActivity,
      state: connectionInfo.ws.readyState,
      metadata: connectionInfo.metadata,
    };
  }

  /**
   * Get connections by criteria
   */
  getConnectionsByCriteria(criteria = {}) {
    const results = [];

    for (const [userId, connectionInfo] of this.connections) {
      let matches = true;

      if (criteria.isHealthy !== undefined && connectionInfo.isHealthy !== criteria.isHealthy) {
        matches = false;
      }

      if (criteria.minDuration && (Date.now() - connectionInfo.connectedAt) < criteria.minDuration) {
        matches = false;
      }

      if (criteria.maxIdleTime && (Date.now() - connectionInfo.lastActivity) > criteria.maxIdleTime) {
        matches = false;
      }

      if (criteria.minRequests && connectionInfo.requestCount < criteria.minRequests) {
        matches = false;
      }

      if (matches) {
        results.push(this.getConnectionDetails(userId));
      }
    }

    return results;
  }
}
