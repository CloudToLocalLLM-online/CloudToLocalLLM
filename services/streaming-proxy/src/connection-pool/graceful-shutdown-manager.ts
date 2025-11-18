/**
 * Graceful Shutdown Manager
 * Handles graceful closure of connections and cleanup of resources
 * 
 * Requirements:
 * - 8.2: THE Client SHALL send proper SSH disconnect message to server
 * - 8.3: THE Client SHALL close WebSocket connection with close code 1000 (normal closure)
 * - 8.4: THE Server SHALL wait for in-flight requests to complete before closing connections (timeout: 30 seconds)
 */

import { ConnectionPool } from '../interfaces/connection-pool.js';
import { Logger } from '../utils/logger.js';
import { ShutdownEventLogger } from '../utils/shutdown-event-logger.js';
import { ServerMetricsCollector } from '../metrics/server-metrics-collector.js';
import { WebSocketServer } from 'ws';

export interface ShutdownConfig {
  /**
   * Maximum time to wait for in-flight requests (milliseconds)
   * Default: 30000 (30 seconds) - Requirement 8.4
   */
  gracePeriod: number;

  /**
   * Force shutdown after grace period
   * Default: true
   */
  forceAfterGracePeriod: boolean;

  /**
   * Send disconnect notifications to clients
   * Default: true
   */
  notifyClients: boolean;
}

export interface ShutdownResult {
  success: boolean;
  duration: number;
  connectionsClosed: number;
  inFlightRequests: number;
  forcedShutdown: boolean;
  errors: string[];
}

export class GracefulShutdownManager {
  private readonly pool: ConnectionPool;
  private readonly logger: Logger;
  private readonly config: ShutdownConfig;
  private readonly eventLogger: ShutdownEventLogger;
  private readonly metricsCollector?: ServerMetricsCollector;
  private readonly wss?: WebSocketServer;
  private isShuttingDown: boolean = false;
  private shutdownStartTime?: Date;
  private inFlightRequests: Set<string> = new Set(); // Track active request IDs
  private requestCounter: number = 0;

  constructor(
    pool: ConnectionPool,
    logger: Logger,
    config?: Partial<ShutdownConfig>,
    metricsCollector?: ServerMetricsCollector,
    wss?: WebSocketServer
  ) {
    this.pool = pool;
    this.logger = logger;
    this.metricsCollector = metricsCollector;
    this.wss = wss;
    this.eventLogger = new ShutdownEventLogger(logger, metricsCollector);
    
    // Default configuration
    this.config = {
      gracePeriod: 30000, // 30 seconds (Requirement 8.4)
      forceAfterGracePeriod: true,
      notifyClients: true,
      ...config,
    };

    // Register signal handlers
    this.registerSignalHandlers();
  }

  /**
   * Register process signal handlers for graceful shutdown
   */
  private registerSignalHandlers(): void {
    // Handle SIGTERM (Kubernetes, Docker)
    process.on('SIGTERM', () => {
      this.logger.info('Received SIGTERM signal');
      this.initiateShutdown('SIGTERM');
    });

    // Handle SIGINT (Ctrl+C)
    process.on('SIGINT', () => {
      this.logger.info('Received SIGINT signal');
      this.initiateShutdown('SIGINT');
    });
  }

  /**
   * Initiate graceful shutdown
   */
  private async initiateShutdown(reason: 'SIGTERM' | 'SIGINT' | 'manual'): Promise<void> {
    if (this.isShuttingDown) {
      this.logger.warn('Shutdown already in progress');
      return;
    }

    // Log shutdown start (Requirement 8.6)
    this.eventLogger.logShutdownStart(reason);
    
    try {
      const result = await this.shutdown();
      
      // Log shutdown completion (Requirement 8.6)
      this.eventLogger.logShutdownComplete(
        result.connectionsClosed,
        0, // requestsFlushed - would need to track this separately
        result.errors
      );
      
      if (result.success) {
        this.logger.info('Graceful shutdown completed successfully');
        process.exit(0);
      } else {
        this.logger.error('Graceful shutdown completed with errors');
        process.exit(1);
      }
    } catch (error) {
      // Log shutdown error (Requirement 8.6)
      this.eventLogger.logShutdownError(error);
      this.logger.error('Fatal error during shutdown:', error);
      process.exit(1);
    }
  }

  /**
   * Perform graceful shutdown
   * Implements requirements 8.2, 8.3, 8.4, 8.5, 8.6, 8.8, 8.9
   */
  async shutdown(): Promise<ShutdownResult> {
    if (this.isShuttingDown) {
      throw new Error('Shutdown already in progress');
    }

    this.isShuttingDown = true;
    this.shutdownStartTime = new Date();
    const startTime = Date.now();
    const errors: string[] = [];
    let connectionsClosed = 0;
    let inFlightRequests = 0;

    this.logger.info(
      `Starting graceful shutdown (grace period: ${this.config.gracePeriod}ms)`,
      {
        timestamp: new Date().toISOString(),
        reason: 'graceful_shutdown',
      }
    );

    try {
      // Step 1: Stop accepting new connections (Requirement 8.9)
      // IMPORTANT: Only prevent new connections, don't close the server yet
      // We need to notify existing clients before closing
      this.logger.info('Step 1: Stopping acceptance of new connections');
      if (this.wss) {
        // Set flag to reject any pending upgrade requests
        // This prevents new connections without disconnecting existing ones
        this.wss.shouldHandle = () => false;
        this.logger.info('New connection acceptance disabled');
      }

      // Log pending request count (Requirement 8.6)
      const totalConnections = this.pool.getTotalConnections();
      const inFlightCount = this.getInFlightRequestCount();
      this.eventLogger.logPendingRequests(totalConnections + inFlightCount);

      // Step 2: Notify connected clients (Requirement 8.5)
      // This must happen BEFORE closing the server, otherwise clients are already disconnected
      if (this.config.notifyClients) {
        this.logger.info('Step 2: Notifying connected clients of shutdown');
        try {
          await this.notifyClientsOfShutdown();
        } catch (error) {
          const message = `Error notifying clients: ${error}`;
          this.logger.warn(message);
          errors.push(message);
        }
      }

      // Step 2.5: Close WebSocket server after clients have been notified
      // This ensures clients receive the shutdown notification before being disconnected
      if (this.wss) {
        this.logger.info('Step 2.5: Closing WebSocket server after client notifications');
        this.wss.close(() => {
          this.logger.info('WebSocket server closed - all connections terminated');
        });
      }

      // Step 3: Wait for in-flight requests with timeout (Requirement 8.4)
      this.logger.info(
        `Step 3: Waiting for in-flight requests (timeout: ${this.config.gracePeriod}ms)`
      );
      
      const waitResult = await this.waitForInFlightRequests(this.config.gracePeriod);
      inFlightRequests = waitResult.remaining;
      
      if (!waitResult.completed) {
        const message = `Timeout waiting for in-flight requests (${waitResult.remaining} remaining)`;
        this.logger.warn(message);
        errors.push(message);
      }

      // Step 4: Close all connections (Requirement 8.6)
      this.logger.info('Step 4: Closing all connections');
      
      try {
        connectionsClosed = await this.closeAllConnectionsGracefully();
        this.logger.info(`All connections closed successfully (${connectionsClosed} connections)`);
      } catch (error) {
        const message = `Error closing connections: ${error}`;
        this.logger.error(message);
        errors.push(message);
      }

      // Calculate results
      const duration = Date.now() - startTime;
      const result: ShutdownResult = {
        success: errors.length === 0,
        duration,
        connectionsClosed,
        inFlightRequests,
        forcedShutdown: !waitResult.completed && this.config.forceAfterGracePeriod,
        errors,
      };

      this.logger.info('Graceful shutdown completed', {
        ...result,
        timestamp: new Date().toISOString(),
        durationMs: duration,
      });
      
      return result;

    } catch (error) {
      const message = `Fatal error during shutdown: ${error}`;
      this.logger.error(message);
      errors.push(message);

      return {
        success: false,
        duration: Date.now() - startTime,
        connectionsClosed,
        inFlightRequests,
        forcedShutdown: true,
        errors,
      };
    }
  }

  /**
   * Track in-flight request
   */
  trackRequest(requestId: string): void {
    this.inFlightRequests.add(requestId);
  }

  /**
   * Mark request as completed
   */
  completeRequest(requestId: string): void {
    this.inFlightRequests.delete(requestId);
  }

  /**
   * Get current in-flight request count
   */
  getInFlightRequestCount(): number {
    return this.inFlightRequests.size;
  }

  /**
   * Wait for in-flight requests to complete
   */
  private async waitForInFlightRequests(
    timeout: number
  ): Promise<{ completed: boolean; remaining: number }> {
    const startTime = Date.now();
    const checkInterval = 100; // Check every 100ms

    while (Date.now() - startTime < timeout) {
      const inFlightCount = this.inFlightRequests.size;
      const totalConnections = this.pool.getTotalConnections();
      
      // Check both in-flight requests and active connections
      if (inFlightCount === 0 && totalConnections === 0) {
        this.logger.info('All in-flight requests completed');
        return { completed: true, remaining: 0 };
      }

      this.logger.debug(
        `Waiting for requests to complete (${inFlightCount} in-flight, ${totalConnections} connections active)`
      );
      await new Promise(resolve => setTimeout(resolve, checkInterval));
    }

    const remaining = this.inFlightRequests.size;
    const remainingConnections = this.pool.getTotalConnections();
    this.logger.warn(
      `Timeout reached with ${remaining} in-flight requests and ${remainingConnections} connections still active`
    );
    
    return { completed: false, remaining: remaining + remainingConnections };
  }

  /**
   * Close WebSocket connection with proper close code
   * Implements requirement 8.3
   * 
   * @param ws - WebSocket instance (any WebSocket-compatible object)
   * @param reason - Optional close reason
   */
  async closeWebSocket(ws: any, reason?: string): Promise<void> {
    // Check if WebSocket is already closed or closing
    const CLOSED = 3;
    const CLOSING = 2;
    
    if (ws.readyState === CLOSED || ws.readyState === CLOSING) {
      this.logger.debug('WebSocket already closed or closing');
      return;
    }

    try {
      // Close with code 1000 (normal closure) - Requirement 8.3
      const closeCode = 1000;
      const closeReason = reason || 'Server shutting down';
      
      this.logger.debug(`Closing WebSocket with code ${closeCode}: ${closeReason}`);
      
      ws.close(closeCode, closeReason);
      
      // Wait for close to complete (with timeout)
      await this.waitForWebSocketClose(ws, 5000);
      
      this.logger.debug('WebSocket closed successfully');
      
    } catch (error) {
      this.logger.error('Error closing WebSocket:', error);
      throw error;
    }
  }

  /**
   * Wait for WebSocket to close
   */
  private async waitForWebSocketClose(ws: any, timeout: number): Promise<void> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error('Timeout waiting for WebSocket to close'));
      }, timeout);

      ws.on('close', () => {
        clearTimeout(timer);
        resolve();
      });

      ws.on('error', (error: Error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
  }

  /**
   * Send SSH disconnect message
   * Implements requirement 8.2
   */
  async sendSSHDisconnect(userId: string, reason?: string): Promise<void> {
    try {
      this.logger.info(`Sending SSH disconnect for user ${userId}`);
      
      // Get connection for user and close it gracefully
      // The connection's close() method should send proper SSH disconnect
      try {
        const connection = await this.pool.getConnection(userId);
        if (connection && typeof connection.close === 'function') {
          await connection.close();
          this.logger.info(`SSH disconnect sent for user ${userId}`);
        } else {
          // Fallback: close connection through pool
          await this.pool.closeConnection(userId);
          this.logger.info(`SSH connection closed for user ${userId} via pool`);
        }
      } catch (error) {
        // Connection might not exist or already closed
        this.logger.debug(`No active SSH connection for user ${userId} to disconnect`);
      }
      
    } catch (error) {
      this.logger.error(`Error sending SSH disconnect for user ${userId}:`, error);
      throw error;
    }
  }

  /**
   * Check if shutdown is in progress
   */
  isShutdownInProgress(): boolean {
    return this.isShuttingDown;
  }

  /**
   * Notify all connected clients of shutdown
   * Sends WebSocket close frame with code 1001 "Going Away"
   * Implements requirement 8.5
   */
  private async notifyClientsOfShutdown(): Promise<void> {
    if (!this.wss) {
      this.logger.warn('WebSocket server not available for client notification');
      return;
    }

    const OPEN = 1; // WebSocket.OPEN
    let notifiedCount = 0;
    const errors: string[] = [];

    for (const client of this.wss.clients) {
      if (client.readyState === OPEN) {
        try {
          // Send close frame with code 1001 "Going Away"
          client.close(1001, 'Server shutting down');
          notifiedCount++;
        } catch (error) {
          const errorMsg = `Error notifying client: ${error instanceof Error ? error.message : String(error)}`;
          errors.push(errorMsg);
          this.logger.warn(errorMsg);
        }
      }
    }

    this.logger.info(`Shutdown notification sent to ${notifiedCount} connected clients`, {
      notifiedCount,
      errors: errors.length > 0 ? errors : undefined,
    });
  }

  /**
   * Close all connections gracefully
   * Implements requirement 8.6
   * Sends SSH disconnect messages before closing (Requirement 8.2)
   */
  private async closeAllConnectionsGracefully(): Promise<number> {
    try {
      const initialCount = this.pool.getTotalConnections();
      const poolStats = this.pool.getPoolStats();
      
      // Send SSH disconnect messages to all users before closing
      const userIds = Object.keys(poolStats.connectionsByUser);
      const disconnectPromises = userIds.map(userId => 
        this.sendSSHDisconnect(userId, 'Server shutting down').catch(error => {
          this.logger.warn(`Failed to send SSH disconnect to user ${userId}:`, error);
          return null; // Continue with shutdown even if disconnect fails
        })
      );
      
      await Promise.all(disconnectPromises);
      
      // Now close all connections
      await this.pool.closeAllConnections();
      
      // Get final connection count
      const remaining = this.pool.getTotalConnections();
      const closed = initialCount - remaining;
      
      // Log connection closures (Requirement 8.6)
      this.logger.info(`Closed ${closed} connections during shutdown`, {
        initialCount,
        remaining,
        closed,
        usersNotified: userIds.length,
        timestamp: new Date().toISOString(),
      });
      
      if (remaining > 0) {
        this.logger.warn(`${remaining} connections still active after close attempt`, {
          timestamp: new Date().toISOString(),
        });
      }
      
      return closed;
    } catch (error) {
      this.logger.error('Error closing all connections:', error);
      throw error;
    }
  }

  /**
   * Get shutdown statistics
   */
  getStats(): {
    isShuttingDown: boolean;
    shutdownStartTime?: Date;
    config: ShutdownConfig;
  } {
    return {
      isShuttingDown: this.isShuttingDown,
      shutdownStartTime: this.shutdownStartTime,
      config: { ...this.config },
    };
  }
}
