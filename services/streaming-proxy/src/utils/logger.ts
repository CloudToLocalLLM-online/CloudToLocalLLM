import { getCorrelationContext } from './correlation-context.js';

/**
 * Log Levels
 */
export enum LogLevel {
  ERROR = 'ERROR',
  WARN = 'WARN',
  INFO = 'INFO',
  DEBUG = 'DEBUG',
  TRACE = 'TRACE',
}

/**
 * Log level hierarchy (higher number = more verbose)
 */
const LOG_LEVEL_HIERARCHY: Record<LogLevel, number> = {
  [LogLevel.ERROR]: 0,
  [LogLevel.WARN]: 1,
  [LogLevel.INFO]: 2,
  [LogLevel.DEBUG]: 3,
  [LogLevel.TRACE]: 4,
};

// Forward declaration to avoid circular dependency
let getLogLevelManager: (() => any) | null = null;

/**
 * Set the log level manager getter (called during initialization)
 */
export function setLogLevelManagerGetter(getter: () => any): void {
  getLogLevelManager = getter;
}

/**
 * Structured log entry
 */
export interface StructuredLogEntry {
  timestamp: string;
  level: LogLevel;
  service: string;
  component?: string;
  message: string;
  userId?: string;
  connectionId?: string;
  correlationId?: string;
  metadata?: Record<string, any>;
  error?: {
    message: string;
    stack?: string;
    code?: string;
  };
}

/**
 * Logger Interface
 * Provides structured logging for the streaming proxy
 */
export interface Logger {
  debug(message: string, metadata?: Record<string, any>): void;
  info(message: string, metadata?: Record<string, any>): void;
  warn(message: string, metadata?: Record<string, any>): void;
  error(message: string, metadata?: Record<string, any>): void;
  setLogLevel(level: LogLevel): void;
  getLogLevel(): LogLevel;
}

/**
 * Console Logger Implementation
 * Supports both JSON and text formatting with structured logging
 */
export class ConsoleLogger implements Logger {
  private readonly context: string;
  private logFormat: 'json' | 'text';

  constructor(context: string = 'StreamingProxy') {
    this.context = context;
    this.logFormat = (process.env.LOG_FORMAT as 'json' | 'text') || 'text';
  }

  /**
   * Get current log level from manager
   */
  private getCurrentLogLevel(): LogLevel {
    if (getLogLevelManager) {
      return getLogLevelManager().getLogLevel();
    }
    return LogLevel.INFO;
  }

  /**
   * Check if message should be logged based on current log level
   */
  private shouldLog(level: LogLevel): boolean {
    const currentLevel = this.getCurrentLogLevel();
    return LOG_LEVEL_HIERARCHY[level] <= LOG_LEVEL_HIERARCHY[currentLevel];
  }

  /**
   * Create structured log entry
   */
  private createLogEntry(
    level: LogLevel,
    message: string,
    metadata?: Record<string, any>
  ): StructuredLogEntry {
    // Get correlation context if available
    const correlationContext = getCorrelationContext();

    const entry: StructuredLogEntry = {
      timestamp: new Date().toISOString(),
      level,
      service: 'streaming-proxy',
      component: this.context,
      message,
      // Use correlation context values if available
      correlationId: metadata?.correlationId || correlationContext?.correlationId,
      userId: metadata?.userId || correlationContext?.userId,
      connectionId: metadata?.connectionId || correlationContext?.connectionId,
    };

    if (metadata) {
      entry.component = metadata.component || this.context;

      // Handle error objects
      if (metadata.error instanceof Error) {
        entry.error = {
          message: metadata.error.message,
          stack: metadata.error.stack,
          code: (metadata.error as any).code,
        };
        // Remove error from metadata to avoid duplication
        const { error, component, correlationId, userId, connectionId, ...rest } = metadata;
        entry.metadata = Object.keys(rest).length > 0 ? rest : undefined;
      } else {
        const { component, correlationId, userId, connectionId, ...rest } = metadata;
        entry.metadata = Object.keys(rest).length > 0 ? rest : undefined;
      }
    }

    return entry;
  }

  /**
   * Format log entry for output
   */
  private formatLogEntry(entry: StructuredLogEntry): string {
    if (this.logFormat === 'json') {
      return JSON.stringify(entry);
    }

    // Text format
    const parts: string[] = [];
    parts.push(`[${entry.timestamp}]`);
    parts.push(`[${entry.level}]`);
    parts.push(`[${entry.service}:${entry.component}]`);

    if (entry.correlationId) {
      parts.push(`[${entry.correlationId}]`);
    }

    parts.push(entry.message);

    if (entry.userId) {
      parts.push(`userId=${entry.userId}`);
    }

    if (entry.connectionId) {
      parts.push(`connectionId=${entry.connectionId}`);
    }

    if (entry.error) {
      parts.push(`error="${entry.error.message}"`);
      if (entry.error.code) {
        parts.push(`code="${entry.error.code}"`);
      }
    }

    if (entry.metadata && Object.keys(entry.metadata).length > 0) {
      parts.push(JSON.stringify(entry.metadata));
    }

    return parts.join(' ');
  }

  debug(message: string, metadata?: Record<string, any>): void {
    if (!this.shouldLog(LogLevel.DEBUG)) return;
    const entry = this.createLogEntry(LogLevel.DEBUG, message, metadata);
    console.debug(this.formatLogEntry(entry));
  }

  info(message: string, metadata?: Record<string, any>): void {
    if (!this.shouldLog(LogLevel.INFO)) return;
    const entry = this.createLogEntry(LogLevel.INFO, message, metadata);
    console.info(this.formatLogEntry(entry));
  }

  warn(message: string, metadata?: Record<string, any>): void {
    if (!this.shouldLog(LogLevel.WARN)) return;
    const entry = this.createLogEntry(LogLevel.WARN, message, metadata);
    console.warn(this.formatLogEntry(entry));
  }

  error(message: string, metadata?: Record<string, any>): void {
    if (!this.shouldLog(LogLevel.ERROR)) return;
    const entry = this.createLogEntry(LogLevel.ERROR, message, metadata);
    console.error(this.formatLogEntry(entry));
  }

  setLogLevel(level: LogLevel): void {
    if (getLogLevelManager) {
      getLogLevelManager().setLogLevel(level);
    }
  }

  getLogLevel(): LogLevel {
    return this.getCurrentLogLevel();
  }
}
