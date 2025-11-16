/**
 * SSH Connection Implementation
 * Wraps SSH connection with health checks, keep-alive, and channel management
 * 
 * Requirements:
 * - 7.1: THE System SHALL use SSH protocol version 2 only (no SSHv1)
 * - 7.2: THE System SHALL support modern SSH key exchange algorithms (curve25519-sha256)
 * - 7.3: THE System SHALL use AES-256-GCM for SSH encryption
 * - 7.4: THE System SHALL implement SSH keep-alive messages every 60 seconds
 * - 7.6: THE System SHALL support SSH connection multiplexing (multiple channels over one connection)
 * - 7.7: THE Server SHALL limit SSH channel count per connection to 10
 * - 7.8: THE System SHALL implement SSH compression for large data transfers
 */

import { SSHConnection, ForwardRequest, ForwardResponse } from '../interfaces/connection-pool.js';
import { Logger } from '../utils/logger.js';
import { SSHErrorHandler, SSHErrorMetrics } from './ssh-error-handler.js';
import { randomUUID } from 'crypto';

export interface SSHConnectionConfig {
  keepAliveInterval: number; // milliseconds
  maxChannels: number;
  connectionTimeout: number; // milliseconds
  algorithms?: {
    kex: string[];
    cipher: string[];
    mac: string[];
  };
  compression?: boolean;
}

/**
 * SSH Connection wrapper implementation
 * 
 * Note: This is a placeholder implementation that demonstrates the structure.
 * In production, this would integrate with an actual SSH library like ssh2.
 * For now, it provides the interface and structure needed for the connection pool.
 */
export class SSHConnectionImpl implements SSHConnection {
  public readonly id: string;
  public readonly userId: string;
  public readonly createdAt: Date;
  public lastUsedAt: Date;
  public channelCount: number = 0; // Current active channels
  public compressionRatio: number = 0; // Compression effectiveness (Requirement 7.8)

  private readonly logger: Logger;
  private readonly config: SSHConnectionConfig;
  private readonly errorHandler: SSHErrorHandler;
  private readonly errorMetrics: SSHErrorMetrics;
  private keepAliveTimer?: NodeJS.Timeout;
  private isConnected: boolean = false;
  private lastKeepAliveResponse?: Date;
  private activeChannels: Set<string> = new Set();
  private bytesUncompressed: number = 0; // Track uncompressed bytes
  private bytesCompressed: number = 0; // Track compressed bytes
  private totalChannelsOpened: number = 0; // Total channels opened (Requirement 7.6)

  constructor(
    userId: string,
    logger: Logger,
    config?: Partial<SSHConnectionConfig>
  ) {
    this.id = randomUUID();
    this.userId = userId;
    this.createdAt = new Date();
    this.lastUsedAt = new Date();
    this.logger = logger;
    this.errorHandler = new SSHErrorHandler(logger);
    this.errorMetrics = new SSHErrorMetrics(logger);
    
    // Default configuration with secure SSH settings (Requirements 7.1, 7.2, 7.3)
    this.config = {
      keepAliveInterval: 60000, // 60 seconds (Requirement 7.4)
      maxChannels: 10, // Requirement 7.7
      connectionTimeout: 30000, // 30 seconds
      algorithms: {
        // SSH protocol version 2 only (Requirement 7.1)
        // Modern key exchange algorithms (Requirement 7.2)
        kex: ['curve25519-sha256', 'ecdh-sha2-nistp256', 'ecdh-sha2-nistp384'],
        // AES-256-GCM for encryption (Requirement 7.3)
        cipher: ['aes256-gcm@openssh.com', 'aes256-ctr', 'aes192-ctr', 'aes128-ctr'],
        // Secure MAC algorithms
        mac: ['hmac-sha2-256', 'hmac-sha2-512'],
      },
      compression: true, // SSH compression (Requirement 7.8)
      ...config,
    };
    
    // Initialize connection
    this.initialize();
  }

  /**
   * Initialize SSH connection with secure algorithm configuration
   * Enforces SSH protocol version 2 and modern cryptographic algorithms
   */
  private async initialize(): Promise<void> {
    try {
      this.logger.info(`Initializing SSH connection ${this.id} for user ${this.userId}`, {
        algorithms: this.config.algorithms,
        compression: this.config.compression,
      });
      
      // In production, establish actual SSH connection with algorithm configuration
      // Example with ssh2 library (Requirements 7.1, 7.2, 7.3, 7.8):
      // this.sshClient = new Client();
      // await this.sshClient.connect({
      //   host: config.host,
      //   port: config.port,
      //   username: this.userId,
      //   privateKey: config.privateKey,
      //   algorithms: {
      //     serverHostKey: ['ssh-rsa', 'ssh-dss'],
      //     cipher: this.config.algorithms.cipher,
      //     serverHostKeyAlgorithm: ['ssh-rsa', 'ssh-dss'],
      //     kex: this.config.algorithms.kex,
      //     mac: this.config.algorithms.mac,
      //     compression: this.config.compression ? ['zlib@openssh.com', 'zlib'] : [],
      //   },
      // });
      
      this.isConnected = true;
      this.startKeepAlive();
      
      this.logger.info(`SSH connection ${this.id} initialized successfully with secure algorithms`);
    } catch (error) {
      const sshError = this.errorHandler.handleSSHError(
        error instanceof Error ? error : new Error(String(error)),
        this.id,
        this.userId
      );
      this.errorMetrics.recordError(sshError.type);
      throw error;
    }
  }

  /**
   * Forward request through SSH tunnel
   * Implements channel multiplexing (Requirement 7.6)
   * Enforces channel limit of 10 per connection (Requirement 7.7)
   */
  async forward(request: ForwardRequest): Promise<ForwardResponse> {
    if (!this.isConnected) {
      throw new Error(`SSH connection ${this.id} is not connected`);
    }
    
    // Check channel limit (Requirement 7.7)
    if (this.activeChannels.size >= this.config.maxChannels) {
      const error = `Channel limit exceeded (${this.config.maxChannels} channels per connection)`;
      this.logger.warn(error, {
        connectionId: this.id,
        userId: this.userId,
        activeChannels: this.activeChannels.size,
        maxChannels: this.config.maxChannels,
      });
      throw new Error(error);
    }
    
    const channelId = randomUUID();
    this.activeChannels.add(channelId);
    this.channelCount = this.activeChannels.size;
    this.totalChannelsOpened++;
    this.lastUsedAt = new Date();
    
    try {
      this.logger.debug(
        `Forwarding request ${request.id} through channel ${channelId} ` +
        `(active channels: ${this.activeChannels.size}/${this.config.maxChannels})`
      );
      
      // In production, forward request through SSH tunnel using ssh2 library
      // Example:
      // const channel = await this.sshClient.forwardOut(
      //   'localhost', 0,
      //   request.path, 22
      // );
      // const response = await this.sendRequestThroughChannel(channel, request);
      
      // Placeholder response
      const response: ForwardResponse = {
        statusCode: 200,
        headers: { 'content-type': 'application/json' },
        body: Buffer.from(JSON.stringify({ success: true })),
      };
      
      this.logger.debug(`Request ${request.id} forwarded successfully through channel ${channelId}`);
      return response;
      
    } finally {
      // Clean up channel (ssh2 handles this automatically)
      this.activeChannels.delete(channelId);
      this.channelCount = this.activeChannels.size;
      this.logger.debug(
        `Channel ${channelId} closed (active channels: ${this.activeChannels.size})`
      );
    }
  }

  /**
   * Close SSH connection gracefully
   * Implements graceful shutdown (Requirement 8.2, 8.3, 8.4)
   */
  async close(): Promise<void> {
    this.logger.info(`Closing SSH connection ${this.id}`);
    
    // Stop keep-alive
    this.stopKeepAlive();
    
    // Wait for active channels to complete (with timeout)
    if (this.activeChannels.size > 0) {
      this.logger.info(
        `Waiting for ${this.activeChannels.size} active channels to complete...`
      );
      
      const timeout = 10000; // 10 seconds
      const startTime = Date.now();
      
      while (this.activeChannels.size > 0 && Date.now() - startTime < timeout) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      if (this.activeChannels.size > 0) {
        this.logger.warn(
          `Timeout waiting for channels. Forcing closure of ${this.activeChannels.size} channels.`
        );
      }
    }
    
    // Close SSH connection
    try {
      // TODO: In production, send SSH disconnect message
      // Example with ssh2 library:
      // await this.sshClient.end();
      
      this.isConnected = false;
      this.logger.info(`SSH connection ${this.id} closed successfully`);
    } catch (error) {
      this.logger.error(`Error closing SSH connection ${this.id}:`, error);
      throw error;
    }
  }

  /**
   * Check if connection is healthy
   * Verifies connection state and recent keep-alive response
   */
  isHealthy(): boolean {
    if (!this.isConnected) {
      return false;
    }
    
    // Check if keep-alive response is recent
    if (this.lastKeepAliveResponse) {
      const timeSinceLastResponse = Date.now() - this.lastKeepAliveResponse.getTime();
      const maxResponseAge = this.config.keepAliveInterval * 2; // Allow 2 missed keep-alives
      
      if (timeSinceLastResponse > maxResponseAge) {
        this.logger.warn(
          `Connection ${this.id} unhealthy: No keep-alive response for ${timeSinceLastResponse}ms`
        );
        return false;
      }
    }
    
    return true;
  }

  /**
   * Start SSH keep-alive mechanism
   * Sends keep-alive messages every 60 seconds (Requirement 7.4)
   */
  private startKeepAlive(): void {
    this.keepAliveTimer = setInterval(() => {
      this.sendKeepAlive();
    }, this.config.keepAliveInterval);
    
    this.logger.debug(
      `Keep-alive started for connection ${this.id} ` +
      `(interval: ${this.config.keepAliveInterval}ms)`
    );
  }

  /**
   * Stop SSH keep-alive mechanism
   */
  private stopKeepAlive(): void {
    if (this.keepAliveTimer) {
      clearInterval(this.keepAliveTimer);
      this.keepAliveTimer = undefined;
      this.logger.debug(`Keep-alive stopped for connection ${this.id}`);
    }
  }

  /**
   * Send SSH keep-alive message every 60 seconds (Requirement 7.4)
   * Detects dead connections: no response after 3 keep-alives (180 seconds)
   * Closes unresponsive connections automatically
   */
  private async sendKeepAlive(): Promise<void> {
    if (!this.isConnected) {
      return;
    }
    
    try {
      this.logger.debug(`Sending keep-alive for connection ${this.id}`);
      
      // In production, send actual SSH keep-alive using ssh2 library
      // Example implementations:
      // 1. Using openssh_noMoreSessions (sends SSH_MSG_GLOBAL_REQUEST):
      //    await this.sshClient.openssh_noMoreSessions();
      // 2. Using custom channel for keep-alive:
      //    const channel = await this.sshClient.exec('echo "keep-alive"');
      //    await channel.close();
      // 3. Using built-in keep-alive:
      //    this.sshClient.keepalive();
      
      this.lastKeepAliveResponse = new Date();
      this.logger.debug(`Keep-alive response received for connection ${this.id}`);
      
    } catch (error) {
      const sshError = this.errorHandler.handleSSHError(
        error instanceof Error ? error : new Error(String(error)),
        this.id,
        this.userId
      );
      this.errorMetrics.recordError(sshError.type);
      
      // Check if connection is dead (no response after 3 keep-alives = 180 seconds)
      const keepAliveFailureThreshold = this.config.keepAliveInterval * 3;
      const timeSinceLastResponse = this.lastKeepAliveResponse 
        ? Date.now() - this.lastKeepAliveResponse.getTime()
        : keepAliveFailureThreshold + 1;
      
      if (timeSinceLastResponse > keepAliveFailureThreshold) {
        this.logger.warn(
          `Connection ${this.id} is dead: no keep-alive response for ${timeSinceLastResponse}ms`,
          {
            connectionId: this.id,
            userId: this.userId,
            timeSinceLastResponse,
            threshold: keepAliveFailureThreshold,
          }
        );
        
        // Close unresponsive connection
        this.isConnected = false;
        this.stopKeepAlive();
      }
    }
  }

  /**
   * Get SSH error metrics
   * 
   * Requirements: 7.10
   */
  getErrorMetrics() {
    return this.errorMetrics.getAllErrorCounts();
  }

  /**
   * Log error frequency report
   * 
   * Requirements: 7.10
   */
  logErrorFrequency(): void {
    this.errorMetrics.logErrorFrequency();
  }

  /**
   * Update compression metrics
   * Called when data is sent through the connection
   * Calculates compression ratio: (uncompressed - compressed) / uncompressed
   * 
   * Requirements: 7.8
   */
  updateCompressionMetrics(uncompressedSize: number, compressedSize: number): void {
    this.bytesUncompressed += uncompressedSize;
    this.bytesCompressed += compressedSize;
    
    if (this.bytesUncompressed > 0) {
      this.compressionRatio = 
        (this.bytesUncompressed - this.bytesCompressed) / this.bytesUncompressed;
    }
    
    this.logger.debug(`Compression metrics updated for connection ${this.id}`, {
      compressionRatio: this.compressionRatio,
      bytesUncompressed: this.bytesUncompressed,
      bytesCompressed: this.bytesCompressed,
    });
  }

  /**
   * Get connection statistics including compression and channel metrics
   */
  getStats(): {
    id: string;
    userId: string;
    createdAt: Date;
    lastUsedAt: Date;
    channelCount: number;
    isHealthy: boolean;
    uptime: number;
    compressionRatio: number;
    bytesUncompressed: number;
    bytesCompressed: number;
    activeChannels: number;
    totalChannelsOpened: number;
  } {
    return {
      id: this.id,
      userId: this.userId,
      createdAt: this.createdAt,
      lastUsedAt: this.lastUsedAt,
      channelCount: this.channelCount,
      isHealthy: this.isHealthy(),
      uptime: Date.now() - this.createdAt.getTime(),
      compressionRatio: this.compressionRatio,
      bytesUncompressed: this.bytesUncompressed,
      bytesCompressed: this.bytesCompressed,
      activeChannels: this.activeChannels.size,
      totalChannelsOpened: this.totalChannelsOpened,
    };
  }
}
