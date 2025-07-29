/**
 * @fileoverview Database Migration System for CloudToLocalLLM Tunnel
 * Handles schema creation, updates, and rollbacks with comprehensive logging
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import { TunnelLogger } from '../utils/logger.js';
const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * Database migration manager
 */
export class DatabaseMigrator {
  constructor(config) {
    // SQLite configuration
    this.config = {
      filename: process.env.DB_PATH || join(__dirname, '../data/cloudtolocalllm.db'),
      driver: sqlite3.Database,
      ...config,
    };

    this.logger = new TunnelLogger('database-migrator');
    this.db = null;
  }

  /**
   * Initialize database connection
   */
  async initialize() {
    try {
      // Ensure data directory exists
      const dataDir = dirname(this.config.filename);
      const { mkdirSync, existsSync } = await import('fs');
      if (!existsSync(dataDir)) {
        mkdirSync(dataDir, { recursive: true });
      }

      // Open SQLite database
      this.db = await open(this.config);

      // Test connection
      await this.db.get('SELECT 1');

      this.logger.info('SQLite database connection established', {
        filename: this.config.filename,
      });

      return true;
    } catch (error) {
      this.logger.error('Failed to connect to SQLite database', {
        error: error.message,
        filename: this.config.filename,
      });
      throw error;
    }
  }

  /**
   * Create migrations table if it doesn't exist
   */
  async createMigrationsTable() {
    const query = `
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        applied_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        checksum TEXT NOT NULL,
        execution_time_ms INTEGER,
        success INTEGER DEFAULT 1
      );

      CREATE INDEX IF NOT EXISTS idx_schema_migrations_version ON schema_migrations(version);
      CREATE INDEX IF NOT EXISTS idx_schema_migrations_applied_at ON schema_migrations(applied_at);
    `;

    await this.db.exec(query);
    this.logger.info('Migrations table created/verified');
  }

  /**
   * Get applied migrations
   */
  async getAppliedMigrations() {
    const result = await this.db.all(
      'SELECT version, name, applied_at FROM schema_migrations WHERE success = 1 ORDER BY applied_at',
    );
    return result;
  }

  /**
   * Check if migration is applied
   */
  async isMigrationApplied(version) {
    const result = await this.db.get(
      'SELECT 1 FROM schema_migrations WHERE version = ? AND success = 1',
      [version],
    );
    return result !== undefined;
  }

  /**
   * Apply initial schema
   */
  async applyInitialSchema() {
    const version = '001_initial_schema';

    if (await this.isMigrationApplied(version)) {
      this.logger.info('Initial schema already applied');
      return;
    }

    const startTime = Date.now();
    const client = await this.pool.connect();

    try {
      await client.query('BEGIN');

      // Read and execute schema file
      const schemaPath = join(__dirname, 'schema.sql');
      const schemaSQL = readFileSync(schemaPath, 'utf8');

      // Calculate checksum
      const checksum = this.calculateChecksum(schemaSQL);

      // Execute schema
      await client.query(schemaSQL);

      // Record migration
      const executionTime = Date.now() - startTime;
      await client.query(
        `INSERT INTO schema_migrations (version, name, checksum, execution_time_ms) 
         VALUES ($1, $2, $3, $4)`,
        [version, 'Initial tunnel system schema', checksum, executionTime],
      );

      await client.query('COMMIT');

      this.logger.info('Initial schema applied successfully', {
        version,
        executionTime,
        checksum,
      });

    } catch (error) {
      await client.query('ROLLBACK');

      // Record failed migration
      await client.query(
        `INSERT INTO schema_migrations (version, name, checksum, success) 
         VALUES ($1, $2, $3, false)`,
        [version, 'Initial tunnel system schema', 'failed'],
      );

      this.logger.error('Failed to apply initial schema', {
        version,
        error: error.message,
      });

      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Apply specific migration
   */
  async applyMigration(migrationFile) {
    const version = this.extractVersionFromFilename(migrationFile);
    const name = this.extractNameFromFilename(migrationFile);

    if (await this.isMigrationApplied(version)) {
      this.logger.info('Migration already applied', { version, name });
      return;
    }

    const startTime = Date.now();
    const client = await this.pool.connect();

    try {
      await client.query('BEGIN');

      // Read migration file
      const migrationPath = join(__dirname, 'migrations', migrationFile);
      const migrationSQL = readFileSync(migrationPath, 'utf8');

      // Calculate checksum
      const checksum = this.calculateChecksum(migrationSQL);

      // Execute migration
      await client.query(migrationSQL);

      // Record migration
      const executionTime = Date.now() - startTime;
      await client.query(
        `INSERT INTO schema_migrations (version, name, checksum, execution_time_ms) 
         VALUES ($1, $2, $3, $4)`,
        [version, name, checksum, executionTime],
      );

      await client.query('COMMIT');

      this.logger.info('Migration applied successfully', {
        version,
        name,
        executionTime,
        checksum,
      });

    } catch (error) {
      await client.query('ROLLBACK');

      // Record failed migration
      await client.query(
        `INSERT INTO schema_migrations (version, name, checksum, success) 
         VALUES ($1, $2, $3, false)`,
        [version, name, 'failed'],
      );

      this.logger.error('Failed to apply migration', {
        version,
        name,
        error: error.message,
      });

      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Rollback migration
   */
  async rollbackMigration(version) {
    const client = await this.pool.connect();

    try {
      await client.query('BEGIN');

      // Check if rollback file exists
      const rollbackFile = `${version}_rollback.sql`;
      const rollbackPath = join(__dirname, 'rollbacks', rollbackFile);

      try {
        const rollbackSQL = readFileSync(rollbackPath, 'utf8');

        // Execute rollback
        await client.query(rollbackSQL);

        // Remove migration record
        await client.query(
          'DELETE FROM schema_migrations WHERE version = $1',
          [version],
        );

        await client.query('COMMIT');

        this.logger.info('Migration rolled back successfully', { version });

      } catch (fileError) {
        this.logger.warn('No rollback file found, manual rollback required', {
          version,
          rollbackFile,
        });
        throw new Error(`No rollback file found for version ${version}`);
      }

    } catch (error) {
      await client.query('ROLLBACK');

      this.logger.error('Failed to rollback migration', {
        version,
        error: error.message,
      });

      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Validate database schema
   */
  async validateSchema() {
    const validations = [
      {
        name: 'user_sessions_table',
        query: 'SELECT 1 FROM information_schema.tables WHERE table_name = \'user_sessions\'',
      },
      {
        name: 'tunnel_connections_table',
        query: 'SELECT 1 FROM information_schema.tables WHERE table_name = \'tunnel_connections\'',
      },
      {
        name: 'tunnel_requests_table',
        query: 'SELECT 1 FROM information_schema.tables WHERE table_name = \'tunnel_requests\'',
      },
      {
        name: 'audit_logs_table',
        query: 'SELECT 1 FROM information_schema.tables WHERE table_name = \'audit_logs\'',
      },
      {
        name: 'security_events_table',
        query: 'SELECT 1 FROM information_schema.tables WHERE table_name = \'security_events\'',
      },
      {
        name: 'performance_metrics_table',
        query: 'SELECT 1 FROM information_schema.tables WHERE table_name = \'performance_metrics\'',
      },
      {
        name: 'active_connections_view',
        query: 'SELECT 1 FROM information_schema.views WHERE table_name = \'active_connections\'',
      },
      {
        name: 'uuid_extension',
        query: 'SELECT 1 FROM pg_extension WHERE extname = \'uuid-ossp\'',
      },
    ];

    const results = {};

    for (const validation of validations) {
      try {
        const result = await this.pool.query(validation.query);
        results[validation.name] = result.rows.length > 0;
      } catch (error) {
        results[validation.name] = false;
        this.logger.warn('Schema validation failed', {
          validation: validation.name,
          error: error.message,
        });
      }
    }

    const allValid = Object.values(results).every(valid => valid);

    this.logger.info('Schema validation completed', {
      results,
      allValid,
    });

    return { results, allValid };
  }

  /**
   * Get database statistics
   */
  async getDatabaseStats() {
    const queries = {
      totalSessions: 'SELECT COUNT(*) as count FROM user_sessions',
      activeSessions: 'SELECT COUNT(*) as count FROM user_sessions WHERE is_active = true AND expires_at > CURRENT_TIMESTAMP',
      totalConnections: 'SELECT COUNT(*) as count FROM tunnel_connections',
      activeConnections: 'SELECT COUNT(*) as count FROM active_connections',
      totalRequests: 'SELECT COUNT(*) as count FROM tunnel_requests',
      auditLogCount: 'SELECT COUNT(*) as count FROM audit_logs',
      securityEventCount: 'SELECT COUNT(*) as count FROM security_events',
      databaseSize: 'SELECT pg_size_pretty(pg_database_size(current_database())) as size',
    };

    const stats = {};

    for (const [key, query] of Object.entries(queries)) {
      try {
        const result = await this.pool.query(query);
        stats[key] = result.rows[0].count || result.rows[0].size;
      } catch (error) {
        stats[key] = 'error';
        this.logger.warn('Failed to get database stat', {
          stat: key,
          error: error.message,
        });
      }
    }

    return stats;
  }

  /**
   * Calculate checksum for SQL content
   */
  calculateChecksum(content) {
    const crypto = require('crypto');
    return crypto.createHash('sha256').update(content).digest('hex');
  }

  /**
   * Extract version from migration filename
   */
  extractVersionFromFilename(filename) {
    const match = filename.match(/^(\d+)_/);
    return match ? match[1] : filename;
  }

  /**
   * Extract name from migration filename
   */
  extractNameFromFilename(filename) {
    const match = filename.match(/^\d+_(.+)\.sql$/);
    return match ? match[1].replace(/_/g, ' ') : filename;
  }

  /**
   * Close database connection
   */
  async close() {
    if (this.pool) {
      await this.pool.end();
      this.logger.info('Database connection closed');
    }
  }
}

/**
 * CLI command runner function
 */
async function runCommand() {
  const command = process.argv[2];
  const migrator = new DatabaseMigrator();
  try {
    await migrator.initialize();
    await migrator.createMigrationsTable();

    switch (command) {
    case 'init':
      await migrator.applyInitialSchema();
      break;

    case 'validate': {
      const validation = await migrator.validateSchema();
      console.log('Validation results:', validation);
      break;
    }

    case 'stats': {
      const stats = await migrator.getDatabaseStats();
      console.log('Database statistics:', stats);
      break;
    }

    case 'status': {
      const migrations = await migrator.getAppliedMigrations();
      console.log('Applied migrations:', migrations);
      break;
    }

    default:
      console.log('Usage: node migrate.js [init|validate|stats|status]');
    }

  } catch (error) {
    console.error('Migration failed:', error.message);
    process.exit(1);
  } finally {
    await migrator.close();
  }
}

/**
 * CLI interface for migrations
 */
if (import.meta.url === `file://${process.argv[1]}`) {
  runCommand();
}
