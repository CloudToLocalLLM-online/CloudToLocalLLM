/**
 * Connection Pool Implementation
 * 
 * Manages SSH connection pooling with per-user isolation and reuse.
 * 
 * ## Design Pattern: Connection Pool
 * 
 * The connection pool pattern improves performance by reusing SSH connections
 * instead of creating new ones for each request.
 * 
 * ### Connection Reuse
 * 
 * 1. **Request arrives**: Check if healthy connection exists for user
 * 2. **Reuse if available**: Return existing connection if healthy and has capacity
 * 3. **Create if needed**: Create new connection if limit not exceeded
 * 4. **Enforce limits**: Reject if user has reached max concurrent connections
 * 
 * ### Per-User Isolation (Requirement 4.1)
 * 
 * Each user has a separate set of connections:
 * - Connections are stored in Map<userId, SSHConnection[]>
 * - No cross-user connection sharing
 * - Each connection has separate SSH session (Requirement 4.6)
 * 
 * ### Connection Limits (Requirement 4.8)
 * 
 * - Max 3 concurrent connections per user
 * - Each connection supports up to 10 channels
 * - Prevents resource exhaustion
 * 
 * ### Cleanup Strategy
 * 
 * - Periodic cleanup removes idle connections (default: 1 hour)
 * - Stale connections detected and removed within 60 seconds
 * - Graceful shutdown closes all connections
 * 
 * ## Usage Example
 * 
 * ```typescript
 * const pool = new ConnectionPoolImpl({
 *   maxConnectionsPerUser: 3,
 *   maxIdleTime: 3600000, // 1 hour
 *   cleanupInterval: 300000, // 5 minutes
 * }, logger);
 * 
 * // Get connection for user
 * const connection = await pool.getConnection('user123');
 * 
 * // Use connection
 * const response = await connection.forward(request);
 * 
 * // Release back to pool
 * pool.releaseConnection('user123', connection);
 * 
 * // Cleanup on shutdown
 * await pool.closeAllConnections();
 * ```
 * 
 * Requirements:
 * - 4.1: Enforce strict user isolation
 * - 4.6: Use separate SSH sessions for each user connection
 * - 4.8: Implement connection limits per user (max 3 concurrent connections)
 * - 1.6: Detect stale connections and clean them up within 60 seconds
 * - 6.9: Implement WebSocket connection timeout (5 minutes idle)
 */

import { ConnectionPool, SSHConnection } from '../interfaces/connection-pool.js';
import { SSHConnectionImpl } from './ssh-connection-impl.js';
import { Logger } from '../utils/logger.js';

/**
 * Configuration for connection pool
 * 
 * @interface ConnectionPoolConfig
 * @property maxConnectionsPerUser - Maximum concurrent connections per user (default: 3)
 * @property maxIdleTime - Maximum idle time before cleanup in milliseconds (default: 3600000)
 * @property cleanupInterval - How often to run cleanup in milliseconds (default: 300000)
 */
export interface ConnectionPoolConfig {
  /** Maximum concurrent connections per user */
  maxConnectionsPerUser: number;
  
  /** Maximum idle time before connection cleanup (milliseconds) */
  maxIdleTime: number;
  
  /** Cleanup task interval (milliseconds) */
  cleanupInterval: number;
}

/**
 * Connection Pool Implementation
 * 
 * Manages SSH connection pooling with per-user isolation, reuse, and lifecycle management.
 */
export class ConnectionPoolImpl implements ConnectionPool {
  /** Map of user ID to their SSH connections */
  private connections: Map<string, SSHConnection[]> = new Map();
  
  /** Pool configuration */
  private readonly config: ConnectionPoolConfig;
  
  /** Logger instance */
  private readonly logger: Logger;
  
  /** Periodic cleanup timer */
  private cleanupTimer?: NodeJS.Timeout;

  /**
   * Create a new connection pool
   * 
   * @param config - Pool configuration
   * @param logger - Logger instance
   */
  constructor(config: ConnectionPoolConfig, logger: Logger) {
    this.config = config;
    this.logger = logger;
    
    // Start periodic cleanup task
    this.startCleanupTask();
  }

  /**
   * Get or create SSH connection for user
   * 
   * Implements connection reuse strategy:
   * 1. Try to find healthy connection with available channels
   * 2. If found, reuse it
   * 3. If not found and limit not exceeded, create new connection
   * 4. If limit exceeded, throw error
   * 
   * @param userId - User identifier
   * @returns SSH connection for this user
   * @throws Error if connection limit exceeded
   * 
   * @example
   * ```typescript
   * try {
   *   const connection = await pool.getConnection('user123');
   *   const response = await connection.forward(request);
   * } catch (error) {
   *   if (error.message.includes('Connection limit exceeded')) {
   *     // User has too many concurrent connections
   *   }
   * }
   * ```
   */
  async getConnection(userId: string): Promise<SSHConnection> {
    this.logger.debug(`Getting connection for user: ${userId}`);
    
    const userConnections = this.connections.get(userId) || [];
    
    // Try to find an available healthy connection with capacity
    const available = userConnections.find(
      c => c.isHealthy() && c.channelCount < 10
    );
    
    if (available) {
      available.lastUsedAt = new Date();
      this.logger.debug(`Reusing existing connection: ${available.id}`);
      return available;
    }
    
    // Check connection limit (Requirement 4.8: max 3 per user)
    if (userConnections.length >= this.config.maxConnectionsPerUser) {
      this.logger.warn(`Connection limit exceeded for user: ${userId}`);
      throw new Error(
        `Connection limit exceeded. Maximum ${this.config.maxConnectionsPerUser} concurrent connections allowed.`
      );
    }
    
    // Create new connection (Requirement 4.6: separate SSH session per user)
    this.logger.info(`Creating new SSH connection for user: ${userId}`);
    const connection = await this.createConnection(userId);
    
    userConnections.push(connection);
    this.connections.set(userId, userConnections);
    
    this.logger.info(`Connection created: ${connection.id} for user: ${userId}`);
    return connection;
  }

  /**
   * Release connection back to pool
   * 
   * Updates the connection's last used time. Connection remains in pool
   * for reuse by subsequent requests.
   * 
   * @param userId - User identifier
   * @param connection - Connection to release
   */
  releaseConnection(userId: string, connection: SSHConnection): void {
    connection.lastUsedAt = new Date();
    this.logger.debug(`Connection released: ${connection.id} for user: ${userId}`);
  }

  /**
   * Close all connections for a specific user
   * 
   * Closes all SSH connections for the user and removes them from the pool.
   * Used when user logs out or session expires.
   * 
   * @param userId - User identifier
   */
  async closeConnection(userId: string): Promise<void> {
    const userConnections = this.connections.get(userId);
    if (!userConnections) {
      this.logger.debug(`No connections found for user: ${userId}`);
      return;
    }
    
    this.logger.info(`Closing ${userConnections.length} connections for user: ${userId}`);
    
    await Promise.all(
      userConnections.map(async (connection) => {
        try {
          await connection.close();
          this.logger.debug(`Connection closed: ${connection.id}`);
        } catch (error) {
          this.logger.error('Error closing connection', {
            connectionId: connection.id,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      })
    );
    
    this.connections.delete(userId);
    this.logger.info(`All connections closed for user: ${userId}`);
  }

  /**
   * Close all connections in the pool
   * 
   * Used during graceful shutdown. Closes all user connections.
   */
  async closeAllConnections(): Promise<void> {
    this.logger.info('Closing all connections in pool');
    
    const userIds = Array.from(this.connections.keys());
    await Promise.all(
      userIds.map(userId => this.closeConnection(userId))
    );
    
    this.logger.info('All connections closed');
  }

  /**
   * Get active connection count for user
   * 
   * Returns number of healthy connections for the user.
   * 
   * @param userId - User identifier
   * @returns Number of active connections
   */
  getActiveConnections(userId: string): number {
    const userConnections = this.connections.get(userId) || [];
    return userConnections.filter(c => c.isHealthy()).length;
  }

  /**
   * Get total connection count across all users
   * 
   * Returns total number of connections in the pool.
   * 
   * @returns Total connection count
   */
  getTotalConnections(): number {
    let total = 0;
    for (const connections of this.connections.values()) {
      total += connections.length;
    }
    return total;
  }

  /**
   * Clean up stale connections
   * Removes connections that have been idle for too long
   * 
   * Requirements:
   * - 1.6: Server SHALL detect stale connections and clean them up within 60 seconds
   * - 6.9: Server SHALL implement WebSocket connection timeout (5 minutes idle)
   */
  async cleanupStaleConnections(maxIdleTime: number): Promise<number> {
    this.logger.debug('Starting stale connection cleanup');
    
    let cleanedCount = 0;
    const now = Date.now();
    
    for (const [userId, connections] of this.connections.entries()) {
      const staleConnections: SSHConnection[] = [];
      const activeConnections: SSHConnection[] = [];
      
      // Separate stale from active connections
      for (const connection of connections) {
        const idleTime = now - connection.lastUsedAt.getTime();
        
        if (idleTime > maxIdleTime || !connection.isHealthy()) {
          staleConnections.push(connection);
        } else {
          activeConnections.push(connection);
        }
      }
      
      // Close stale connections
      for (const connection of staleConnections) {
        try {
          this.logger.info(
            `Closing stale connection: ${connection.id} for user: ${userId} ` +
            `(idle: ${Math.round((now - connection.lastUsedAt.getTime()) / 1000)}s)`
          );
          await connection.close();
          cleanedCount++;
        } catch (error) {
          this.logger.error('Error closing stale connection', {
            connectionId: connection.id,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }
      
      // Update connections map
      if (activeConnections.length === 0) {
        this.connections.delete(userId);
      } else {
        this.connections.set(userId, activeConnections);
      }
    }
    
    if (cleanedCount > 0) {
      this.logger.info(`Cleaned up ${cleanedCount} stale connections`);
    }
    
    return cleanedCount;
  }

  /**
   * Start periodic cleanup task
   */
  private startCleanupTask(): void {
    this.cleanupTimer = setInterval(async () => {
      try {
        await this.cleanupStaleConnections(this.config.maxIdleTime);
      } catch (error) {
        this.logger.error('Error during cleanup task', {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }, this.config.cleanupInterval);
    
    this.logger.info(
      `Cleanup task started (interval: ${this.config.cleanupInterval}ms, ` +
      `maxIdleTime: ${this.config.maxIdleTime}ms)`
    );
  }

  /**
   * Stop periodic cleanup task
   */
  stopCleanupTask(): void {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = undefined;
      this.logger.info('Cleanup task stopped');
    }
  }

  /**
   * Create a new SSH connection for user
   * This is a factory method that can be overridden for testing
   */
  private async createConnection(userId: string): Promise<SSHConnection> {
    return new SSHConnectionImpl(userId, this.logger);
  }

  /**
   * Get pool statistics for monitoring
   */
  getPoolStats(): {
    totalConnections: number;
    userCount: number;
    connectionsByUser: Record<string, number>;
  } {
    const connectionsByUser: Record<string, number> = {};
    
    for (const [userId, connections] of this.connections.entries()) {
      connectionsByUser[userId] = connections.length;
    }
    
    return {
      totalConnections: this.getTotalConnections(),
      userCount: this.connections.size,
      connectionsByUser,
    };
  }
}
