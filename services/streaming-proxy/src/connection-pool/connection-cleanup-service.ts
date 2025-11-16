/**
 * Connection Cleanup Service
 * Manages periodic cleanup of stale connections
 * 
 * Requirements:
 * - 1.6: THE Server SHALL detect stale connections and clean them up within 60 seconds
 * - 6.9: THE Server SHALL implement WebSocket connection timeout (5 minutes idle)
 */

import { ConnectionPool } from '../interfaces/connection-pool.js';
import { Logger } from '../utils/logger.js';

export interface CleanupServiceConfig {
  /**
   * Interval between cleanup runs (milliseconds)
   * Default: 30000 (30 seconds)
   */
  cleanupInterval: number;

  /**
   * Maximum idle time before connection is considered stale (milliseconds)
   * Default: 300000 (5 minutes) - Requirement 6.9
   */
  maxIdleTime: number;

  /**
   * Enable automatic cleanup
   * Default: true
   */
  enabled: boolean;
}

export class ConnectionCleanupService {
  private readonly pool: ConnectionPool;
  private readonly config: CleanupServiceConfig;
  private readonly logger: Logger;
  private cleanupTimer?: NodeJS.Timeout;
  private isRunning: boolean = false;
  private cleanupCount: number = 0;
  private lastCleanupTime?: Date;

  constructor(
    pool: ConnectionPool,
    logger: Logger,
    config?: Partial<CleanupServiceConfig>
  ) {
    this.pool = pool;
    this.logger = logger;
    
    // Default configuration
    this.config = {
      cleanupInterval: 30000, // 30 seconds
      maxIdleTime: 300000, // 5 minutes (Requirement 6.9)
      enabled: true,
      ...config,
    };
  }

  /**
   * Start the cleanup service
   */
  start(): void {
    if (this.isRunning) {
      this.logger.warn('Cleanup service is already running');
      return;
    }

    if (!this.config.enabled) {
      this.logger.info('Cleanup service is disabled');
      return;
    }

    this.logger.info(
      `Starting cleanup service (interval: ${this.config.cleanupInterval}ms, ` +
      `maxIdleTime: ${this.config.maxIdleTime}ms)`
    );

    this.isRunning = true;
    this.scheduleNextCleanup();
  }

  /**
   * Stop the cleanup service
   */
  stop(): void {
    if (!this.isRunning) {
      this.logger.warn('Cleanup service is not running');
      return;
    }

    this.logger.info('Stopping cleanup service');

    if (this.cleanupTimer) {
      clearTimeout(this.cleanupTimer);
      this.cleanupTimer = undefined;
    }

    this.isRunning = false;
    this.logger.info('Cleanup service stopped');
  }

  /**
   * Schedule next cleanup run
   */
  private scheduleNextCleanup(): void {
    if (!this.isRunning) {
      return;
    }

    this.cleanupTimer = setTimeout(async () => {
      await this.runCleanup();
      this.scheduleNextCleanup();
    }, this.config.cleanupInterval);
  }

  /**
   * Run cleanup operation
   * Detects and closes idle connections
   */
  private async runCleanup(): Promise<void> {
    try {
      this.logger.debug('Running connection cleanup');
      const startTime = Date.now();

      // Clean up stale connections
      const cleaned = await this.pool.cleanupStaleConnections(this.config.maxIdleTime);

      const duration = Date.now() - startTime;
      this.cleanupCount += cleaned;
      this.lastCleanupTime = new Date();

      if (cleaned > 0) {
        this.logger.info(
          `Cleanup completed: ${cleaned} connections cleaned in ${duration}ms ` +
          `(total cleaned: ${this.cleanupCount})`
        );
      } else {
        this.logger.debug(`Cleanup completed: No stale connections found (${duration}ms)`);
      }

    } catch (error) {
      this.logger.error('Error during cleanup operation:', error);
    }
  }

  /**
   * Manually trigger cleanup
   * Useful for testing or forced cleanup
   */
  async triggerCleanup(): Promise<number> {
    this.logger.info('Manual cleanup triggered');
    
    try {
      const cleaned = await this.pool.cleanupStaleConnections(this.config.maxIdleTime);
      this.cleanupCount += cleaned;
      this.lastCleanupTime = new Date();
      
      this.logger.info(`Manual cleanup completed: ${cleaned} connections cleaned`);
      return cleaned;
      
    } catch (error) {
      this.logger.error('Error during manual cleanup:', error);
      throw error;
    }
  }

  /**
   * Get cleanup service statistics
   */
  getStats(): {
    isRunning: boolean;
    cleanupCount: number;
    lastCleanupTime?: Date;
    config: CleanupServiceConfig;
  } {
    return {
      isRunning: this.isRunning,
      cleanupCount: this.cleanupCount,
      lastCleanupTime: this.lastCleanupTime,
      config: { ...this.config },
    };
  }

  /**
   * Update configuration
   * Changes take effect on next cleanup run
   */
  updateConfig(config: Partial<CleanupServiceConfig>): void {
    const oldConfig = { ...this.config };
    Object.assign(this.config, config);
    
    this.logger.info('Cleanup service configuration updated', {
      old: oldConfig,
      new: this.config,
    });

    // Restart if interval changed and service is running
    if (
      this.isRunning &&
      config.cleanupInterval !== undefined &&
      config.cleanupInterval !== oldConfig.cleanupInterval
    ) {
      this.logger.info('Restarting cleanup service with new interval');
      this.stop();
      this.start();
    }
  }
}
