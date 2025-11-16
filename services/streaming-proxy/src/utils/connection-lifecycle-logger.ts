import { ConsoleLogger, LogLevel } from './logger.js';
import { setUserId, setConnectionId } from './correlation-context.js';

/**
 * Connection lifecycle events
 */
export enum ConnectionLifecycleEvent {
  ESTABLISHED = 'connection_established',
  AUTHENTICATED = 'connection_authenticated',
  DISCONNECTED = 'connection_disconnected',
  RECONNECTION_ATTEMPT = 'reconnection_attempt',
  RECONNECTED = 'connection_reconnected',
  AUTH_SUCCESS = 'auth_success',
  AUTH_FAILURE = 'auth_failure',
  ERROR = 'connection_error',
}

/**
 * Connection lifecycle logger
 * Logs all connection-related events with structured format
 */
export class ConnectionLifecycleLogger {
  private logger: ConsoleLogger;

  constructor() {
    this.logger = new ConsoleLogger('ConnectionLifecycle');
  }

  /**
   * Log connection establishment
   */
  logConnectionEstablished(
    connectionId: string,
    userId: string | undefined,
    ip: string,
    metadata?: Record<string, any>
  ): void {
    setConnectionId(connectionId);
    if (userId) {
      setUserId(userId);
    }

    this.logger.info('WebSocket connection established', {
      connectionId,
      userId,
      ip,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  /**
   * Log connection disconnection
   */
  logConnectionDisconnected(
    connectionId: string,
    userId: string | undefined,
    closeCode: number,
    closeReason: string,
    metadata?: Record<string, any>
  ): void {
    setConnectionId(connectionId);
    if (userId) {
      setUserId(userId);
    }

    this.logger.info('WebSocket connection disconnected', {
      connectionId,
      userId,
      closeCode,
      closeReason,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  /**
   * Log reconnection attempt
   */
  logReconnectionAttempt(
    connectionId: string,
    userId: string | undefined,
    attemptNumber: number,
    delayMs: number,
    metadata?: Record<string, any>
  ): void {
    setConnectionId(connectionId);
    if (userId) {
      setUserId(userId);
    }

    this.logger.info('Reconnection attempt', {
      connectionId,
      userId,
      attemptNumber,
      delayMs,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  /**
   * Log successful reconnection
   */
  logReconnected(
    connectionId: string,
    userId: string | undefined,
    attemptNumber: number,
    metadata?: Record<string, any>
  ): void {
    setConnectionId(connectionId);
    if (userId) {
      setUserId(userId);
    }

    this.logger.info('Successfully reconnected', {
      connectionId,
      userId,
      attemptNumber,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  /**
   * Log authentication success
   */
  logAuthenticationSuccess(
    userId: string,
    connectionId: string,
    metadata?: Record<string, any>
  ): void {
    setConnectionId(connectionId);
    setUserId(userId);

    this.logger.info('Authentication successful', {
      connectionId,
      userId,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  /**
   * Log authentication failure
   */
  logAuthenticationFailure(
    userId: string | undefined,
    connectionId: string,
    reason: string,
    metadata?: Record<string, any>
  ): void {
    setConnectionId(connectionId);
    if (userId) {
      setUserId(userId);
    }

    this.logger.warn('Authentication failed', {
      connectionId,
      userId,
      reason,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  /**
   * Log connection error
   */
  logConnectionError(
    connectionId: string,
    userId: string | undefined,
    error: Error,
    metadata?: Record<string, any>
  ): void {
    setConnectionId(connectionId);
    if (userId) {
      setUserId(userId);
    }

    this.logger.error('Connection error', {
      connectionId,
      userId,
      error,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }

  /**
   * Log connection metadata (duration, requests, bytes transferred)
   */
  logConnectionMetadata(
    connectionId: string,
    userId: string | undefined,
    metadata: {
      duration: number; // milliseconds
      totalRequests: number;
      bytesReceived: number;
      bytesSent: number;
      averageLatency?: number;
    }
  ): void {
    setConnectionId(connectionId);
    if (userId) {
      setUserId(userId);
    }

    this.logger.info('Connection metadata', {
      connectionId,
      userId,
      durationMs: metadata.duration,
      totalRequests: metadata.totalRequests,
      bytesReceived: metadata.bytesReceived,
      bytesSent: metadata.bytesSent,
      averageLatencyMs: metadata.averageLatency,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Log connection state change
   */
  logConnectionStateChange(
    connectionId: string,
    userId: string | undefined,
    fromState: string,
    toState: string,
    reason?: string,
    metadata?: Record<string, any>
  ): void {
    setConnectionId(connectionId);
    if (userId) {
      setUserId(userId);
    }

    this.logger.debug('Connection state changed', {
      connectionId,
      userId,
      fromState,
      toState,
      reason,
      timestamp: new Date().toISOString(),
      ...metadata,
    });
  }
}

/**
 * Singleton instance of connection lifecycle logger
 */
export const connectionLifecycleLogger = new ConnectionLifecycleLogger();
