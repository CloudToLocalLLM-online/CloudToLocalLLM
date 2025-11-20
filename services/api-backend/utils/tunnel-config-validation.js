/**
 * Tunnel Configuration Validation Utilities
 *
 * Provides validation for tunnel configuration parameters:
 * - maxConnections: Maximum concurrent connections (1-10000)
 * - timeout: Request timeout in milliseconds (1000-300000)
 * - compression: Enable/disable compression (boolean)
 *
 * Validates: Requirements 4.3
 * - Implements tunnel configuration management
 * - Supports max connections, timeout, compression settings
 * - Implements config validation
 *
 * @fileoverview Tunnel configuration validation
 * @version 1.0.0
 */

/**
 * Validate tunnel configuration
 *
 * @param {Object} config - Configuration object to validate
 * @returns {Object} Validation result with isValid flag and errors array
 */
export function validateTunnelConfig(config) {
  const errors = [];

  if (!config || typeof config !== 'object') {
    return {
      isValid: false,
      errors: ['Configuration must be an object'],
    };
  }

  // Validate maxConnections
  if (config.maxConnections !== undefined) {
    if (!Number.isInteger(config.maxConnections)) {
      errors.push('maxConnections must be an integer');
    } else if (config.maxConnections < 1 || config.maxConnections > 10000) {
      errors.push('maxConnections must be between 1 and 10000');
    }
  }

  // Validate timeout
  if (config.timeout !== undefined) {
    if (!Number.isInteger(config.timeout)) {
      errors.push('timeout must be an integer');
    } else if (config.timeout < 1000 || config.timeout > 300000) {
      errors.push('timeout must be between 1000ms and 300000ms (5 minutes)');
    }
  }

  // Validate compression
  if (config.compression !== undefined) {
    if (typeof config.compression !== 'boolean') {
      errors.push('compression must be a boolean');
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Get default tunnel configuration
 *
 * @returns {Object} Default configuration
 */
export function getDefaultTunnelConfig() {
  return {
    maxConnections: 100,
    timeout: 30000,
    compression: true,
  };
}

/**
 * Merge user config with defaults
 *
 * @param {Object} userConfig - User-provided configuration
 * @returns {Object} Merged configuration with defaults
 */
export function mergeTunnelConfig(userConfig) {
  const defaults = getDefaultTunnelConfig();

  if (!userConfig || typeof userConfig !== 'object') {
    return defaults;
  }

  return {
    maxConnections: userConfig.maxConnections ?? defaults.maxConnections,
    timeout: userConfig.timeout ?? defaults.timeout,
    compression: userConfig.compression ?? defaults.compression,
  };
}

/**
 * Sanitize tunnel configuration for storage
 *
 * @param {Object} config - Configuration to sanitize
 * @returns {Object} Sanitized configuration
 */
export function sanitizeTunnelConfig(config) {
  const merged = mergeTunnelConfig(config);

  return {
    maxConnections: Math.max(1, Math.min(10000, merged.maxConnections)),
    timeout: Math.max(1000, Math.min(300000, merged.timeout)),
    compression: Boolean(merged.compression),
  };
}
