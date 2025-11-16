/**
 * Shutdown Event Logger
 * Logs comprehensive shutdown events with structured logging
 * 
 * Requirements: 8.6, 11.3, 11.4, 11.5
 */

import { Logger } from './logger';
import { ServerMetricsCollector } from '../metrics/server-metrics-collector';

export interface ShutdownEvent {
  timestamp: Date;
  eventType: 'shutdown_start' | 'shutdown_step' | 'shutdown_complete' | 'shutdown_error';
  reason?: string;
  details: Record<string, any>;
}

export interface ShutdownMetrics {
  shutdownDurationMs: number;
  connectionsClosed: number;
  requestsFlushed: number;
  errors: string[];
}

/**
 * Shutdown event logger for comprehensive logging
 */
export class ShutdownEventLogger {
  private readonly logger: Logger;
  private readonly metricsCollector?: ServerMetricsCollector;
  private shutdownStartTime?: Date;
  private shutdownEvents: ShutdownEvent[] = [];

  constructor(
    logger: Logger,
    metricsCollector?: ServerMetricsCollector
  ) {
    this.logger = logger;
    this.metricsCollector = metricsCollector;
  }

  /**
   * Log shutdown initiation
   * Requirement 8.6: Log shutdown initiation with ISO timestamp and reason
   */
  logShutdownStart(reason: 'SIGTERM' | 'SIGINT' | 'manual'): void {
    this.shutdownStartTime = new Date();
    
    const event: ShutdownEvent = {
      timestamp: this.shutdownStartTime,
      eventType: 'shutdown_start',
      reason,
      details: {
        reason,
        timestamp: this.shutdownStartTime.toISOString(),
        nodeVersion: process.version,
        uptime: process.uptime(),
      },
    };

    this.shutdownEvents.push(event);

    this.logger.info('Shutdown initiated', {
      reason,
      timestamp: this.shutdownStartTime.toISOString(),
      nodeVersion: process.version,
      uptime: process.uptime(),
    });
  }

  /**
   * Log pending request count at shutdown start
   * Requirement 8.6: Log pending request count at shutdown start
   */
  logPendingRequests(count: number): void {
    const event: ShutdownEvent = {
      timestamp: new Date(),
      eventType: 'shutdown_step',
      details: {
        step: 'pending_requests',
        count,
        timestamp: new Date().toISOString(),
      },
    };

    this.shutdownEvents.push(event);

    this.logger.info('Pending requests at shutdown', {
      count,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Log connection closure
   * Requirement 8.6: Log each connection closure with userId, connectionId, and connection duration
   */
  logConnectionClosure(
    userId: string,
    connectionId: string,
    connectionDuration: number,
    closeCode: number,
    closeReason: string
  ): void {
    const event: ShutdownEvent = {
      timestamp: new Date(),
      eventType: 'shutdown_step',
      details: {
        step: 'connection_closure',
        userId,
        connectionId,
        connectionDurationMs: connectionDuration,
        closeCode,
        closeReason,
        timestamp: new Date().toISOString(),
      },
    };

    this.shutdownEvents.push(event);

    this.logger.info('Connection closed during shutdown', {
      userId,
      connectionId,
      connectionDurationMs: connectionDuration,
      closeCode,
      closeReason,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Log shutdown completion
   * Requirement 8.6: Log total shutdown duration and number of connections closed
   */
  logShutdownComplete(
    connectionsClosed: number,
    requestsFlushed: number,
    errors: string[]
  ): void {
    if (!this.shutdownStartTime) {
      this.logger.warn('Shutdown complete called without shutdown start');
      return;
    }

    const duration = Date.now() - this.shutdownStartTime.getTime();

    const event: ShutdownEvent = {
      timestamp: new Date(),
      eventType: 'shutdown_complete',
      details: {
        shutdownDurationMs: duration,
        connectionsClosed,
        requestsFlushed,
        errorCount: errors.length,
        errors,
        timestamp: new Date().toISOString(),
      },
    };

    this.shutdownEvents.push(event);

    this.logger.info('Shutdown completed', {
      shutdownDurationMs: duration,
      connectionsClosed,
      requestsFlushed,
      errorCount: errors.length,
      timestamp: new Date().toISOString(),
    });

    // Record shutdown metrics
    if (this.metricsCollector) {
      this.recordShutdownMetrics({
        shutdownDurationMs: duration,
        connectionsClosed,
        requestsFlushed,
        errors,
      });
    }
  }

  /**
   * Log shutdown error
   * Requirement 8.6: Log any errors during shutdown process
   */
  logShutdownError(error: Error | string, context?: Record<string, any>): void {
    const errorMessage = error instanceof Error ? error.message : error;
    const errorStack = error instanceof Error ? error.stack : undefined;

    const event: ShutdownEvent = {
      timestamp: new Date(),
      eventType: 'shutdown_error',
      details: {
        error: errorMessage,
        stack: errorStack,
        context,
        timestamp: new Date().toISOString(),
      },
    };

    this.shutdownEvents.push(event);

    this.logger.error('Error during shutdown', {
      error: errorMessage,
      stack: errorStack,
      context,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Record shutdown metrics to metrics collector
   * Requirement 8.6: Add shutdown metrics to ServerMetricsCollector
   */
  private recordShutdownMetrics(metrics: ShutdownMetrics): void {
    if (!this.metricsCollector) {
      return;
    }

    // Record shutdown metrics as a special request
    // This allows them to be included in Prometheus metrics
    this.logger.debug('Recording shutdown metrics', {
      shutdownDurationMs: metrics.shutdownDurationMs,
      connectionsClosed: metrics.connectionsClosed,
      requestsFlushed: metrics.requestsFlushed,
    });

    // TODO: Implement custom shutdown metrics recording
    // This would require extending ServerMetricsCollector to support shutdown metrics
  }

  /**
   * Get all shutdown events
   */
  getShutdownEvents(): ShutdownEvent[] {
    return [...this.shutdownEvents];
  }

  /**
   * Export shutdown events as JSON
   */
  exportShutdownEventsJson(): Record<string, any> {
    return {
      events: this.shutdownEvents.map(event => ({
        ...event,
        timestamp: event.timestamp.toISOString(),
      })),
      totalEvents: this.shutdownEvents.length,
      exportedAt: new Date().toISOString(),
    };
  }

  /**
   * Clear shutdown events
   */
  clearShutdownEvents(): void {
    this.shutdownEvents = [];
  }
}
