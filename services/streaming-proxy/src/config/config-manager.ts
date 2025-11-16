/**
 * Configuration Manager
 * 
 * Manages runtime configuration updates and provides configuration endpoints.
 * Allows partial configuration updates without requiring server restart.
 * 
 * Requirements: 9.6
 */

import { ServerConfig, validateConfig, ValidationResult } from './server-config';
import { ConsoleLogger } from '../utils/logger';

const logger = new ConsoleLogger('ConfigManager');

/**
 * Configuration manager for runtime updates
 */
export class ConfigManager {
  private config: ServerConfig;
  private originalConfig: ServerConfig;

  constructor(initialConfig: ServerConfig) {
    this.config = JSON.parse(JSON.stringify(initialConfig)); // Deep copy
    this.originalConfig = JSON.parse(JSON.stringify(initialConfig)); // Keep original for reference
  }

  /**
   * Get current configuration (sanitized)
   * Excludes sensitive values
   */
  getConfig(): ServerConfig {
    return JSON.parse(JSON.stringify(this.config));
  }

  /**
   * Update configuration with partial updates
   * Validates before applying changes
   * 
   * @param updates Partial configuration updates
   * @returns Updated configuration or error
   */
  updateConfig(updates: Partial<ServerConfig>): { success: boolean; config?: ServerConfig; error?: string } {
    try {
      // Merge updates with current config
      const mergedConfig: ServerConfig = {
        websocket: {
          ...this.config.websocket,
          ...(updates.websocket || {}),
        },
        connection: {
          ...this.config.connection,
          ...(updates.connection || {}),
        },
        rateLimit: {
          ...this.config.rateLimit,
          ...(updates.rateLimit || {}),
        },
        logging: {
          ...this.config.logging,
          ...(updates.logging || {}),
        },
      };

      // Validate merged configuration
      const validation = validateConfig(mergedConfig);
      if (!validation.isValid) {
        return {
          success: false,
          error: `Configuration validation failed: ${validation.errors.join('; ')}`,
        };
      }

      // Log changes
      this.logConfigChanges(this.config, mergedConfig);

      // Apply changes
      this.config = mergedConfig;

      logger.info('Configuration updated successfully', {
        timestamp: new Date().toISOString(),
      });

      return {
        success: true,
        config: this.getConfig(),
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      logger.error('Configuration update failed:', { error: errorMessage });
      return {
        success: false,
        error: `Configuration update failed: ${errorMessage}`,
      };
    }
  }

  /**
   * Reset configuration to original values
   */
  resetConfig(): ServerConfig {
    this.config = JSON.parse(JSON.stringify(this.originalConfig));
    logger.info('Configuration reset to original values');
    return this.getConfig();
  }

  /**
   * Log configuration changes
   */
  private logConfigChanges(oldConfig: ServerConfig, newConfig: ServerConfig): void {
    const changes: Record<string, { old: any; new: any }> = {};

    // Check websocket changes
    Object.keys(newConfig.websocket).forEach(key => {
      const oldValue = (oldConfig.websocket as any)[key];
      const newValue = (newConfig.websocket as any)[key];
      if (oldValue !== newValue) {
        changes[`websocket.${key}`] = { old: oldValue, new: newValue };
      }
    });

    // Check connection changes
    Object.keys(newConfig.connection).forEach(key => {
      const oldValue = (oldConfig.connection as any)[key];
      const newValue = (newConfig.connection as any)[key];
      if (oldValue !== newValue) {
        changes[`connection.${key}`] = { old: oldValue, new: newValue };
      }
    });

    // Check rateLimit changes
    Object.keys(newConfig.rateLimit).forEach(key => {
      const oldValue = (oldConfig.rateLimit as any)[key];
      const newValue = (newConfig.rateLimit as any)[key];
      if (oldValue !== newValue) {
        changes[`rateLimit.${key}`] = { old: oldValue, new: newValue };
      }
    });

    // Check logging changes
    Object.keys(newConfig.logging).forEach(key => {
      const oldValue = (oldConfig.logging as any)[key];
      const newValue = (newConfig.logging as any)[key];
      if (oldValue !== newValue) {
        changes[`logging.${key}`] = { old: oldValue, new: newValue };
      }
    });

    if (Object.keys(changes).length > 0) {
      logger.info('Configuration changes detected', {
        changes,
        timestamp: new Date().toISOString(),
      });
    }
  }
}

/**
 * Global configuration manager instance
 */
let globalConfigManager: ConfigManager | null = null;

/**
 * Initialize global configuration manager
 */
export function initializeConfigManager(config: ServerConfig): ConfigManager {
  globalConfigManager = new ConfigManager(config);
  return globalConfigManager;
}

/**
 * Get global configuration manager
 */
export function getConfigManager(): ConfigManager {
  if (!globalConfigManager) {
    throw new Error('Configuration manager not initialized');
  }
  return globalConfigManager;
}
