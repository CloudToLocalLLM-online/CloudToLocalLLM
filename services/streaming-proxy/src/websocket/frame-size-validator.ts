/**
 * Frame Size Validator
 * Enforces WebSocket frame size limits to prevent memory exhaustion
 * Logs violations and rejects oversized frames
 */

import { WebSocket } from 'ws';

interface FrameSizeConfig {
  maxFrameSize: number; // Maximum frame size in bytes
  maxPayloadSize: number; // Maximum payload size in bytes
  warnThreshold: number; // Warn when frame exceeds this size
}

interface FrameSizeViolation {
  timestamp: Date;
  frameSize: number;
  maxSize: number;
  userId?: string;
  connectionId?: string;
}

interface FrameSizeStats {
  totalFrames: number;
  totalBytes: number;
  violations: number;
  warnings: number;
  largestFrame: number;
  averageFrameSize: number;
}

/**
 * Frame Size Validator
 * Validates WebSocket frame sizes and enforces limits
 */
export class FrameSizeValidator {
  private readonly config: FrameSizeConfig;
  private readonly violations: FrameSizeViolation[] = [];
  private stats: FrameSizeStats = {
    totalFrames: 0,
    totalBytes: 0,
    violations: 0,
    warnings: 0,
    largestFrame: 0,
    averageFrameSize: 0,
  };

  constructor(config?: Partial<FrameSizeConfig>) {
    this.config = {
      maxFrameSize: config?.maxFrameSize || 1024 * 1024, // 1MB default
      maxPayloadSize: config?.maxPayloadSize || 1024 * 1024, // 1MB default
      warnThreshold: config?.warnThreshold || 512 * 1024, // 512KB warning
    };
  }

  /**
   * Validate frame size
   * Returns true if frame is within limits, false otherwise
   */
  validateFrameSize(
    frameSize: number,
    userId?: string,
    connectionId?: string
  ): ValidationResult {
    // Update statistics
    this.stats.totalFrames++;
    this.stats.totalBytes += frameSize;
    this.stats.averageFrameSize = this.stats.totalBytes / this.stats.totalFrames;

    if (frameSize > this.stats.largestFrame) {
      this.stats.largestFrame = frameSize;
    }

    // Check if frame exceeds maximum size
    if (frameSize > this.config.maxFrameSize) {
      this.stats.violations++;

      const violation: FrameSizeViolation = {
        timestamp: new Date(),
        frameSize,
        maxSize: this.config.maxFrameSize,
        userId,
        connectionId,
      };

      this.violations.push(violation);

      // Keep only last 100 violations
      if (this.violations.length > 100) {
        this.violations.shift();
      }

      // Log violation
      console.error(JSON.stringify({
        type: 'frame_size_violation',
        frameSize,
        maxSize: this.config.maxFrameSize,
        userId,
        connectionId,
        timestamp: new Date().toISOString(),
      }));

      return {
        valid: false,
        reason: 'Frame size exceeds maximum limit',
        frameSize,
        maxSize: this.config.maxFrameSize,
      };
    }

    // Check if frame exceeds warning threshold
    if (frameSize > this.config.warnThreshold) {
      this.stats.warnings++;

      console.warn(JSON.stringify({
        type: 'frame_size_warning',
        frameSize,
        warnThreshold: this.config.warnThreshold,
        maxSize: this.config.maxFrameSize,
        userId,
        connectionId,
        timestamp: new Date().toISOString(),
      }));

      return {
        valid: true,
        warning: 'Frame size exceeds warning threshold',
        frameSize,
        warnThreshold: this.config.warnThreshold,
      };
    }

    return {
      valid: true,
      frameSize,
    };
  }

  /**
   * Validate and handle frame
   * Closes connection if frame is too large
   */
  validateAndHandle(
    ws: WebSocket,
    frameSize: number,
    userId?: string,
    connectionId?: string
  ): boolean {
    const result = this.validateFrameSize(frameSize, userId, connectionId);

    if (!result.valid) {
      // Close connection with appropriate error code
      ws.close(1009, 'Message too large');
      return false;
    }

    return true;
  }

  /**
   * Get frame size configuration
   */
  getConfig(): FrameSizeConfig {
    return { ...this.config };
  }

  /**
   * Get frame size statistics
   */
  getStats(): FrameSizeStats {
    return { ...this.stats };
  }

  /**
   * Get recent violations
   */
  getViolations(limit: number = 10): FrameSizeViolation[] {
    return this.violations.slice(-limit);
  }

  /**
   * Get violation count
   */
  getViolationCount(): number {
    return this.stats.violations;
  }

  /**
   * Get warning count
   */
  getWarningCount(): number {
    return this.stats.warnings;
  }

  /**
   * Check if frame size is within limits
   */
  isWithinLimits(frameSize: number): boolean {
    return frameSize <= this.config.maxFrameSize;
  }

  /**
   * Check if frame size exceeds warning threshold
   */
  exceedsWarningThreshold(frameSize: number): boolean {
    return frameSize > this.config.warnThreshold;
  }

  /**
   * Get maximum frame size
   */
  getMaxFrameSize(): number {
    return this.config.maxFrameSize;
  }

  /**
   * Get warning threshold
   */
  getWarnThreshold(): number {
    return this.config.warnThreshold;
  }

  /**
   * Reset statistics
   */
  resetStats(): void {
    this.stats = {
      totalFrames: 0,
      totalBytes: 0,
      violations: 0,
      warnings: 0,
      largestFrame: 0,
      averageFrameSize: 0,
    };
    this.violations.length = 0;
  }

  /**
   * Get summary string
   */
  getSummary(): string {
    const avgSize = Math.round(this.stats.averageFrameSize);
    const largestSize = this.stats.largestFrame;
    const violationRate = this.stats.totalFrames > 0
      ? ((this.stats.violations / this.stats.totalFrames) * 100).toFixed(2)
      : '0.00';

    return `Frame Size: max=${this.formatBytes(this.config.maxFrameSize)} | ` +
      `avg=${this.formatBytes(avgSize)} | ` +
      `largest=${this.formatBytes(largestSize)} | ` +
      `violations=${this.stats.violations} (${violationRate}%) | ` +
      `warnings=${this.stats.warnings}`;
  }

  /**
   * Format bytes to human-readable string
   */
  private formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
  }

  /**
   * Create default validator (1MB limit)
   */
  static createDefault(): FrameSizeValidator {
    return new FrameSizeValidator({
      maxFrameSize: 1024 * 1024, // 1MB
      maxPayloadSize: 1024 * 1024, // 1MB
      warnThreshold: 512 * 1024, // 512KB
    });
  }

  /**
   * Create strict validator (smaller limits)
   */
  static createStrict(): FrameSizeValidator {
    return new FrameSizeValidator({
      maxFrameSize: 256 * 1024, // 256KB
      maxPayloadSize: 256 * 1024, // 256KB
      warnThreshold: 128 * 1024, // 128KB
    });
  }

  /**
   * Create lenient validator (larger limits)
   */
  static createLenient(): FrameSizeValidator {
    return new FrameSizeValidator({
      maxFrameSize: 10 * 1024 * 1024, // 10MB
      maxPayloadSize: 10 * 1024 * 1024, // 10MB
      warnThreshold: 5 * 1024 * 1024, // 5MB
    });
  }
}

/**
 * Validation result
 */
export interface ValidationResult {
  valid: boolean;
  reason?: string;
  warning?: string;
  frameSize: number;
  maxSize?: number;
  warnThreshold?: number;
}
