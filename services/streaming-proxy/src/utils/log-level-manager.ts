import { LogLevel } from './logger.js';

/**
 * Log level manager
 * Manages the current log level for the application
 * Singleton pattern for global access
 */
export class LogLevelManager {
  private static instance: LogLevelManager;
  private currentLogLevel: LogLevel;

  private constructor() {
    // Initialize from environment variable
    const envLogLevel = process.env.LOG_LEVEL || 'INFO';
    this.currentLogLevel = this.parseLogLevel(envLogLevel);
  }

  /**
   * Get singleton instance
   */
  static getInstance(): LogLevelManager {
    if (!LogLevelManager.instance) {
      LogLevelManager.instance = new LogLevelManager();
    }
    return LogLevelManager.instance;
  }

  /**
   * Parse log level from string
   */
  private parseLogLevel(level: string): LogLevel {
    const normalized = level.toUpperCase();
    if (Object.values(LogLevel).includes(normalized as LogLevel)) {
      return normalized as LogLevel;
    }
    return LogLevel.INFO;
  }

  /**
   * Get current log level
   */
  getLogLevel(): LogLevel {
    return this.currentLogLevel;
  }

  /**
   * Set log level
   */
  setLogLevel(level: LogLevel): void {
    this.currentLogLevel = level;
  }

  /**
   * Set log level from string
   */
  setLogLevelFromString(level: string): boolean {
    const parsed = this.parseLogLevel(level);
    if (parsed) {
      this.currentLogLevel = parsed;
      return true;
    }
    return false;
  }

  /**
   * Get all valid log levels
   */
  getValidLogLevels(): string[] {
    return Object.values(LogLevel);
  }

  /**
   * Validate log level
   */
  isValidLogLevel(level: string): boolean {
    const normalized = level.toUpperCase();
    return Object.values(LogLevel).includes(normalized as LogLevel);
  }
}

/**
 * Get singleton instance
 */
export function getLogLevelManager(): LogLevelManager {
  return LogLevelManager.getInstance();
}
