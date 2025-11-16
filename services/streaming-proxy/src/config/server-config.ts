/**
 * Server Configuration Loader
 * 
 * Loads and validates server configuration from environment variables.
 * Provides default values for all settings and validates them on startup.
 * 
 * Requirements: 9.5, 9.10
 */

import { ConsoleLogger } from '../utils/logger';

const logger = new ConsoleLogger('ServerConfig');

/**
 * Server configuration interface
 * Defines all configurable settings for the streaming proxy server
 */
export interface ServerConfig {
  // WebSocket Configuration
  websocket: {
    port: number;
    path: string;
    pingInterval: number;
    pongTimeout: number;
    maxFrameSize: number;
  };

  // SSH Configuration (Requirement 7.1, 7.2, 7.3)
  ssh: {
    algorithms: {
      kex: string[];
      cipher: string[];
      mac: string[];
    };
    keepAliveInterval: number;
    maxChannelsPerConnection: number;
    compression: boolean;
  };

  // Connection Management
  connection: {
    maxConnectionsPerUser: number;
    idleTimeout: number;
  };

  // Rate Limiting
  rateLimit: {
    requestsPerMinute: number;
  };

  // Logging
  logging: {
    level: string;
  };
}

/**
 * Validation result interface
 */
export interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

/**
 * Load configuration from environment variables
 * Returns configuration with defaults applied
 * 
 * Environment variables:
 * - WEBSOCKET_PORT: Port for WebSocket server (default: 3001)
 * - WEBSOCKET_PATH: WebSocket endpoint path (default: /ws)
 * - PING_INTERVAL: Heartbeat ping interval in ms (default: 30000)
 * - PONG_TIMEOUT: Pong response timeout in ms (default: 5000)
 * - MAX_FRAME_SIZE: Maximum WebSocket frame size in bytes (default: 1048576)
 * - MAX_CONNECTIONS_PER_USER: Max concurrent connections per user (default: 3)
 * - IDLE_TIMEOUT: Connection idle timeout in ms (default: 300000)
 * - RATE_LIMIT_REQUESTS_PER_MINUTE: Rate limit per user (default: 100)
 * - LOG_LEVEL: Logging level (default: INFO)
 * - SSH_KEEP_ALIVE_INTERVAL: SSH keep-alive interval in ms (default: 60000)
 * - SSH_MAX_CHANNELS: Max SSH channels per connection (default: 10)
 * - SSH_COMPRESSION: Enable SSH compression (default: true)
 */
export function loadConfig(): ServerConfig {
  const config: ServerConfig = {
    websocket: {
      port: parseInt(process.env.WEBSOCKET_PORT || '3001', 10),
      path: process.env.WEBSOCKET_PATH || '/ws',
      pingInterval: parseInt(process.env.PING_INTERVAL || '30000', 10),
      pongTimeout: parseInt(process.env.PONG_TIMEOUT || '5000', 10),
      maxFrameSize: parseInt(process.env.MAX_FRAME_SIZE || '1048576', 10),
    },
    ssh: {
      algorithms: {
        kex: ['curve25519-sha256', 'ecdh-sha2-nistp256', 'ecdh-sha2-nistp384'],
        cipher: ['aes256-gcm@openssh.com', 'aes256-ctr', 'aes192-ctr', 'aes128-ctr'],
        mac: ['hmac-sha2-256', 'hmac-sha2-512'],
      },
      keepAliveInterval: parseInt(process.env.SSH_KEEP_ALIVE_INTERVAL || '60000', 10),
      maxChannelsPerConnection: parseInt(process.env.SSH_MAX_CHANNELS || '10', 10),
      compression: process.env.SSH_COMPRESSION !== 'false',
    },
    connection: {
      maxConnectionsPerUser: parseInt(process.env.MAX_CONNECTIONS_PER_USER || '3', 10),
      idleTimeout: parseInt(process.env.IDLE_TIMEOUT || '300000', 10),
    },
    rateLimit: {
      requestsPerMinute: parseInt(process.env.RATE_LIMIT_REQUESTS_PER_MINUTE || '100', 10),
    },
    logging: {
      level: process.env.LOG_LEVEL || 'INFO',
    },
  };

  return config;
}

/**
 * Validate server configuration
 * Checks all configuration values against constraints
 * 
 * Validation rules:
 * - WEBSOCKET_PORT: 1024-65535
 * - Timeout values: positive integers
 * - Rate limit settings: positive integers
 * - Connection limits: 1-100
 * - maxFrameSize: 1KB-10MB
 * - SSH algorithms: non-empty arrays
 * - SSH keep-alive: positive integer
 * - SSH max channels: 1-100
 */
export function validateConfig(config: ServerConfig): ValidationResult {
  const errors: string[] = [];

  // Validate WebSocket port
  if (config.websocket.port < 1024 || config.websocket.port > 65535) {
    errors.push(`WEBSOCKET_PORT must be between 1024 and 65535, got ${config.websocket.port}`);
  }

  // Validate WebSocket path
  if (!config.websocket.path || typeof config.websocket.path !== 'string') {
    errors.push('WEBSOCKET_PATH must be a non-empty string');
  }

  // Validate ping interval
  if (!Number.isInteger(config.websocket.pingInterval) || config.websocket.pingInterval <= 0) {
    errors.push(`PING_INTERVAL must be a positive integer, got ${config.websocket.pingInterval}`);
  }

  // Validate pong timeout
  if (!Number.isInteger(config.websocket.pongTimeout) || config.websocket.pongTimeout <= 0) {
    errors.push(`PONG_TIMEOUT must be a positive integer, got ${config.websocket.pongTimeout}`);
  }

  // Validate max frame size (1KB to 10MB)
  const minFrameSize = 1024; // 1KB
  const maxFrameSize = 10 * 1024 * 1024; // 10MB
  if (config.websocket.maxFrameSize < minFrameSize || config.websocket.maxFrameSize > maxFrameSize) {
    errors.push(
      `MAX_FRAME_SIZE must be between ${minFrameSize} and ${maxFrameSize} bytes, got ${config.websocket.maxFrameSize}`
    );
  }

  // Validate SSH algorithms (Requirement 7.1, 7.2, 7.3)
  if (!config.ssh.algorithms.kex || config.ssh.algorithms.kex.length === 0) {
    errors.push('SSH key exchange algorithms must not be empty');
  }
  if (!config.ssh.algorithms.cipher || config.ssh.algorithms.cipher.length === 0) {
    errors.push('SSH cipher algorithms must not be empty');
  }
  if (!config.ssh.algorithms.mac || config.ssh.algorithms.mac.length === 0) {
    errors.push('SSH MAC algorithms must not be empty');
  }

  // Validate SSH keep-alive interval
  if (!Number.isInteger(config.ssh.keepAliveInterval) || config.ssh.keepAliveInterval <= 0) {
    errors.push(`SSH_KEEP_ALIVE_INTERVAL must be a positive integer, got ${config.ssh.keepAliveInterval}`);
  }

  // Validate SSH max channels (1-100)
  if (config.ssh.maxChannelsPerConnection < 1 || config.ssh.maxChannelsPerConnection > 100) {
    errors.push(
      `SSH_MAX_CHANNELS must be between 1 and 100, got ${config.ssh.maxChannelsPerConnection}`
    );
  }

  // Validate max connections per user (1-100)
  if (config.connection.maxConnectionsPerUser < 1 || config.connection.maxConnectionsPerUser > 100) {
    errors.push(
      `MAX_CONNECTIONS_PER_USER must be between 1 and 100, got ${config.connection.maxConnectionsPerUser}`
    );
  }

  // Validate idle timeout
  if (!Number.isInteger(config.connection.idleTimeout) || config.connection.idleTimeout <= 0) {
    errors.push(`IDLE_TIMEOUT must be a positive integer, got ${config.connection.idleTimeout}`);
  }

  // Validate rate limit
  if (!Number.isInteger(config.rateLimit.requestsPerMinute) || config.rateLimit.requestsPerMinute <= 0) {
    errors.push(
      `RATE_LIMIT_REQUESTS_PER_MINUTE must be a positive integer, got ${config.rateLimit.requestsPerMinute}`
    );
  }

  // Validate log level
  const validLogLevels = ['ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE'];
  if (!validLogLevels.includes(config.logging.level.toUpperCase())) {
    errors.push(
      `LOG_LEVEL must be one of ${validLogLevels.join(', ')}, got ${config.logging.level}`
    );
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Load and validate configuration
 * Logs errors and exits if validation fails
 */
export function loadAndValidateConfig(): ServerConfig {
  const config = loadConfig();
  const validation = validateConfig(config);

  if (!validation.isValid) {
    logger.error('Invalid configuration:', {
      errors: validation.errors,
    });
    console.error('Invalid configuration:');
    validation.errors.forEach(error => console.error(`  - ${error}`));
    process.exit(1);
  }

  logger.info('Configuration loaded and validated', {
    port: config.websocket.port,
    websocketPath: config.websocket.path,
    logLevel: config.logging.level,
  });

  return config;
}
