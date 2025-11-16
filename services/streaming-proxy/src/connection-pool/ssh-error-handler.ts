/**
 * SSH Error Handler
 * Categorizes and logs SSH protocol errors with structured logging
 * 
 * Requirements:
 * - 7.10: THE System SHALL log all SSH protocol errors with structured logging
 * - 7.10: THE System SHALL categorize SSH errors into types
 * - 7.10: THE System SHALL provide troubleshooting hints for common errors
 * - 7.10: THE System SHALL add SSH error metrics to ServerMetricsCollector
 */

import { Logger } from '../utils/logger.js';

/**
 * SSH error categories
 */
export enum SSHErrorType {
  AUTH = 'auth',           // Authentication errors
  PROTOCOL = 'protocol',   // SSH protocol errors
  NETWORK = 'network',     // Network connectivity errors
  TIMEOUT = 'timeout',     // Timeout errors
  CHANNEL = 'channel',     // Channel-related errors
  UNKNOWN = 'unknown',     // Unknown errors
}

/**
 * SSH error with categorization
 */
export interface SSHError {
  type: SSHErrorType;
  code?: string;
  message: string;
  troubleshootingHint: string;
  connectionId?: string;
  userId?: string;
  timestamp: Date;
  stackTrace?: string;
}

/**
 * SSH Error Handler
 * Categorizes SSH errors and provides troubleshooting guidance
 */
export class SSHErrorHandler {
  private readonly logger: Logger;

  constructor(logger: Logger) {
    this.logger = logger;
  }

  /**
   * Categorize SSH error and return structured error information
   * 
   * Requirements: 7.10
   */
  categorizeError(error: Error | string, connectionId?: string, userId?: string): SSHError {
    const errorMessage = typeof error === 'string' ? error : error.message;
    const stackTrace = error instanceof Error ? error.stack : undefined;

    // Categorize based on error message patterns
    let type: SSHErrorType = SSHErrorType.UNKNOWN;
    let troubleshootingHint = 'Check SSH server logs for more details';

    // Authentication errors
    if (
      errorMessage.includes('authentication') ||
      errorMessage.includes('auth') ||
      errorMessage.includes('permission denied') ||
      errorMessage.includes('invalid credentials')
    ) {
      type = SSHErrorType.AUTH;
      troubleshootingHint = 'Check SSH credentials and permissions. Verify the user has access to the SSH server.';
    }

    // Protocol errors
    if (
      errorMessage.includes('protocol') ||
      errorMessage.includes('handshake') ||
      errorMessage.includes('version') ||
      errorMessage.includes('algorithm')
    ) {
      type = SSHErrorType.PROTOCOL;
      troubleshootingHint = 'SSH protocol negotiation failed. Check SSH server configuration and supported algorithms.';
    }

    // Network errors
    if (
      errorMessage.includes('ECONNREFUSED') ||
      errorMessage.includes('ENOTFOUND') ||
      errorMessage.includes('EHOSTUNREACH') ||
      errorMessage.includes('connection refused') ||
      errorMessage.includes('host unreachable') ||
      errorMessage.includes('network unreachable')
    ) {
      type = SSHErrorType.NETWORK;
      troubleshootingHint = 'Check network connectivity and firewall rules. Verify the SSH server is running and accessible.';
    }

    // Timeout errors
    if (
      errorMessage.includes('timeout') ||
      errorMessage.includes('ETIMEDOUT') ||
      errorMessage.includes('timed out')
    ) {
      type = SSHErrorType.TIMEOUT;
      troubleshootingHint = 'Increase timeout values or check server responsiveness. Network may be slow or unstable.';
    }

    // Channel errors
    if (
      errorMessage.includes('channel') ||
      errorMessage.includes('stream') ||
      errorMessage.includes('session')
    ) {
      type = SSHErrorType.CHANNEL;
      troubleshootingHint = 'SSH channel operation failed. Check if the channel limit has been exceeded.';
    }

    const sshError: SSHError = {
      type,
      message: errorMessage,
      troubleshootingHint,
      connectionId,
      userId,
      timestamp: new Date(),
      stackTrace,
    };

    return sshError;
  }

  /**
   * Log SSH error with structured logging
   * 
   * Requirements: 7.10
   */
  logSSHError(error: SSHError): void {
    this.logger.error(`SSH ${error.type} error: ${error.message}`, {
      errorType: error.type,
      errorCode: error.code,
      connectionId: error.connectionId,
      userId: error.userId,
      troubleshootingHint: error.troubleshootingHint,
      timestamp: error.timestamp.toISOString(),
      stackTrace: error.stackTrace,
    });
  }

  /**
   * Handle SSH error with categorization and logging
   * 
   * Requirements: 7.10
   */
  handleSSHError(
    error: Error | string,
    connectionId?: string,
    userId?: string
  ): SSHError {
    const categorizedError = this.categorizeError(error, connectionId, userId);
    this.logSSHError(categorizedError);
    return categorizedError;
  }

  /**
   * Get troubleshooting hint for error type
   * 
   * Requirements: 7.10
   */
  getTroubleshootingHint(errorType: SSHErrorType): string {
    const hints: Record<SSHErrorType, string> = {
      [SSHErrorType.AUTH]: 'Check SSH credentials and permissions',
      [SSHErrorType.PROTOCOL]: 'Check SSH server configuration and supported algorithms',
      [SSHErrorType.NETWORK]: 'Check network connectivity and firewall rules',
      [SSHErrorType.TIMEOUT]: 'Increase timeout values or check server responsiveness',
      [SSHErrorType.CHANNEL]: 'Check if the channel limit has been exceeded',
      [SSHErrorType.UNKNOWN]: 'Check SSH server logs for more details',
    };

    return hints[errorType];
  }
}

/**
 * SSH Error Metrics
 * Tracks SSH error statistics for monitoring
 * 
 * Requirements: 7.10
 */
export class SSHErrorMetrics {
  private errorCounts: Record<SSHErrorType, number> = {
    [SSHErrorType.AUTH]: 0,
    [SSHErrorType.PROTOCOL]: 0,
    [SSHErrorType.NETWORK]: 0,
    [SSHErrorType.TIMEOUT]: 0,
    [SSHErrorType.CHANNEL]: 0,
    [SSHErrorType.UNKNOWN]: 0,
  };

  private readonly logger: Logger;

  constructor(logger: Logger) {
    this.logger = logger;
  }

  /**
   * Record SSH error
   */
  recordError(errorType: SSHErrorType): void {
    this.errorCounts[errorType]++;
  }

  /**
   * Get error count for type
   */
  getErrorCount(errorType: SSHErrorType): number {
    return this.errorCounts[errorType];
  }

  /**
   * Get total error count
   */
  getTotalErrorCount(): number {
    return Object.values(this.errorCounts).reduce((sum, count) => sum + count, 0);
  }

  /**
   * Get all error counts
   */
  getAllErrorCounts(): Record<SSHErrorType, number> {
    return { ...this.errorCounts };
  }

  /**
   * Reset error counts
   */
  reset(): void {
    Object.keys(this.errorCounts).forEach((key) => {
      this.errorCounts[key as SSHErrorType] = 0;
    });
  }

  /**
   * Log error frequency and patterns
   * 
   * Requirements: 7.10
   */
  logErrorFrequency(): void {
    const totalErrors = this.getTotalErrorCount();
    if (totalErrors === 0) {
      return;
    }

    this.logger.info('SSH error frequency report', {
      totalErrors,
      byType: this.getAllErrorCounts(),
      authErrors: this.errorCounts[SSHErrorType.AUTH],
      protocolErrors: this.errorCounts[SSHErrorType.PROTOCOL],
      networkErrors: this.errorCounts[SSHErrorType.NETWORK],
      timeoutErrors: this.errorCounts[SSHErrorType.TIMEOUT],
      channelErrors: this.errorCounts[SSHErrorType.CHANNEL],
      unknownErrors: this.errorCounts[SSHErrorType.UNKNOWN],
    });
  }
}
