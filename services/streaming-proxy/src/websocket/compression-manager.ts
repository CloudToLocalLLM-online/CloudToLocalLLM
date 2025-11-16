/**
 * Compression Manager
 * Manages WebSocket compression using permessage-deflate extension
 * Handles compression configuration and error recovery
 */

import { WebSocketServer, PerMessageDeflateOptions } from 'ws';

interface CompressionConfig {
  enabled: boolean;
  threshold: number; // Minimum message size to compress (bytes)
  level: number; // Compression level (0-9)
  memLevel: number; // Memory level (1-9)
  serverNoContextTakeover: boolean;
  clientNoContextTakeover: boolean;
  serverMaxWindowBits: number;
  clientMaxWindowBits: number;
}

interface CompressionStats {
  messagesCompressed: number;
  messagesUncompressed: number;
  bytesBeforeCompression: number;
  bytesAfterCompression: number;
  compressionRatio: number;
  errors: number;
}

/**
 * Compression Manager
 * Configures and monitors WebSocket compression
 */
export class CompressionManager {
  private readonly config: CompressionConfig;
  private stats: CompressionStats = {
    messagesCompressed: 0,
    messagesUncompressed: 0,
    bytesBeforeCompression: 0,
    bytesAfterCompression: 0,
    compressionRatio: 0,
    errors: 0,
  };

  constructor(config?: Partial<CompressionConfig>) {
    this.config = {
      enabled: config?.enabled !== false, // Default: enabled
      threshold: config?.threshold || 1024, // 1KB threshold
      level: config?.level || 6, // Balanced compression
      memLevel: config?.memLevel || 8, // Default memory level
      serverNoContextTakeover: config?.serverNoContextTakeover !== false,
      clientNoContextTakeover: config?.clientNoContextTakeover !== false,
      serverMaxWindowBits: config?.serverMaxWindowBits || 15,
      clientMaxWindowBits: config?.clientMaxWindowBits || 15,
    };
  }

  /**
   * Get compression options for WebSocket server
   */
  getCompressionOptions(): PerMessageDeflateOptions | false {
    if (!this.config.enabled) {
      return false;
    }

    return {
      threshold: this.config.threshold,
      zlibDeflateOptions: {
        level: this.config.level,
        memLevel: this.config.memLevel,
      },
      zlibInflateOptions: {
        chunkSize: 10 * 1024, // 10KB chunks
      },
      serverNoContextTakeover: this.config.serverNoContextTakeover,
      clientNoContextTakeover: this.config.clientNoContextTakeover,
      serverMaxWindowBits: this.config.serverMaxWindowBits,
      clientMaxWindowBits: this.config.clientMaxWindowBits,
      concurrencyLimit: 10, // Limit concurrent compression operations
    };
  }

  /**
   * Configure WebSocket server with compression
   */
  configureServer(wss: WebSocketServer): void {
    const compressionOptions = this.getCompressionOptions();

    if (compressionOptions === false) {
      console.log('WebSocket compression disabled');
      return;
    }

    console.log(JSON.stringify({
      type: 'compression_configured',
      config: {
        enabled: true,
        threshold: this.config.threshold,
        level: this.config.level,
        serverNoContextTakeover: this.config.serverNoContextTakeover,
        clientNoContextTakeover: this.config.clientNoContextTakeover,
      },
      timestamp: new Date().toISOString(),
    }));

    // Monitor compression errors
    wss.on('connection', (ws) => {
      ws.on('error', (error) => {
        if (this.isCompressionError(error)) {
          this.handleCompressionError(error);
        }
      });
    });
  }

  /**
   * Check if error is compression-related
   */
  private isCompressionError(error: Error): boolean {
    const compressionErrorPatterns = [
      'zlib',
      'deflate',
      'inflate',
      'compression',
      'decompression',
    ];

    const errorMessage = error.message.toLowerCase();
    return compressionErrorPatterns.some((pattern) => errorMessage.includes(pattern));
  }

  /**
   * Handle compression error
   */
  private handleCompressionError(error: Error): void {
    this.stats.errors++;

    console.error(JSON.stringify({
      type: 'compression_error',
      error: error.message,
      stack: error.stack,
      totalErrors: this.stats.errors,
      timestamp: new Date().toISOString(),
    }));

    // If too many errors, consider disabling compression
    if (this.stats.errors > 100) {
      console.error(JSON.stringify({
        type: 'compression_error_threshold_exceeded',
        errors: this.stats.errors,
        message: 'Consider disabling compression due to high error rate',
        timestamp: new Date().toISOString(),
      }));
    }
  }

  /**
   * Record compression statistics
   */
  recordCompression(originalSize: number, compressedSize: number): void {
    this.stats.messagesCompressed++;
    this.stats.bytesBeforeCompression += originalSize;
    this.stats.bytesAfterCompression += compressedSize;

    // Update compression ratio
    if (this.stats.bytesBeforeCompression > 0) {
      this.stats.compressionRatio =
        1 - this.stats.bytesAfterCompression / this.stats.bytesBeforeCompression;
    }
  }

  /**
   * Record uncompressed message
   */
  recordUncompressed(size: number): void {
    this.stats.messagesUncompressed++;
  }

  /**
   * Get compression statistics
   */
  getStats(): CompressionStats {
    return { ...this.stats };
  }

  /**
   * Get compression configuration
   */
  getConfig(): CompressionConfig {
    return { ...this.config };
  }

  /**
   * Check if compression is enabled
   */
  isEnabled(): boolean {
    return this.config.enabled;
  }

  /**
   * Get compression ratio as percentage
   */
  getCompressionRatioPercent(): number {
    return Math.round(this.stats.compressionRatio * 100);
  }

  /**
   * Get average bytes saved per message
   */
  getAverageBytesSaved(): number {
    if (this.stats.messagesCompressed === 0) {
      return 0;
    }

    const totalSaved =
      this.stats.bytesBeforeCompression - this.stats.bytesAfterCompression;
    return Math.round(totalSaved / this.stats.messagesCompressed);
  }

  /**
   * Reset statistics
   */
  resetStats(): void {
    this.stats = {
      messagesCompressed: 0,
      messagesUncompressed: 0,
      bytesBeforeCompression: 0,
      bytesAfterCompression: 0,
      compressionRatio: 0,
      errors: 0,
    };
  }

  /**
   * Get compression summary
   */
  getSummary(): string {
    const ratio = this.getCompressionRatioPercent();
    const avgSaved = this.getAverageBytesSaved();
    const totalMessages = this.stats.messagesCompressed + this.stats.messagesUncompressed;

    return `Compression: ${this.config.enabled ? 'enabled' : 'disabled'} | ` +
      `Ratio: ${ratio}% | ` +
      `Avg saved: ${avgSaved} bytes | ` +
      `Messages: ${this.stats.messagesCompressed}/${totalMessages} compressed | ` +
      `Errors: ${this.stats.errors}`;
  }

  /**
   * Create default compression manager
   */
  static createDefault(): CompressionManager {
    return new CompressionManager({
      enabled: true,
      threshold: 1024, // 1KB
      level: 6, // Balanced
      memLevel: 8,
      serverNoContextTakeover: true,
      clientNoContextTakeover: true,
      serverMaxWindowBits: 15,
      clientMaxWindowBits: 15,
    });
  }

  /**
   * Create high compression manager (slower but better ratio)
   */
  static createHighCompression(): CompressionManager {
    return new CompressionManager({
      enabled: true,
      threshold: 512, // 512 bytes
      level: 9, // Maximum compression
      memLevel: 9,
      serverNoContextTakeover: true,
      clientNoContextTakeover: true,
      serverMaxWindowBits: 15,
      clientMaxWindowBits: 15,
    });
  }

  /**
   * Create fast compression manager (faster but lower ratio)
   */
  static createFastCompression(): CompressionManager {
    return new CompressionManager({
      enabled: true,
      threshold: 2048, // 2KB
      level: 1, // Minimal compression
      memLevel: 7,
      serverNoContextTakeover: true,
      clientNoContextTakeover: true,
      serverMaxWindowBits: 15,
      clientMaxWindowBits: 15,
    });
  }

  /**
   * Create disabled compression manager
   */
  static createDisabled(): CompressionManager {
    return new CompressionManager({
      enabled: false,
    });
  }
}
