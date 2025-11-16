#!/usr/bin/env node

/**
 * Database Migration Runner
 * 
 * Usage:
 *   node run-migration.js up 001    - Apply migration 001
 *   node run-migration.js down 001  - Rollback migration 001
 *   node run-migration.js status    - Show migration status
 * 
 * Environment Variables:
 *   DATABASE_URL - PostgreSQL connection string
 *   PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD - Individual connection params
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';

const { Pool } = pg;
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Database connection configuration
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  host: process.env.PGHOST || 'localhost',
  port: parseInt(process.env.PGPORT || '5432'),
  database: process.env.PGDATABASE || 'cloudtolocalllm',
  user: process.env.PGUSER || 'postgres',
  password: process.env.PGPASSWORD,
  ssl: process.env.PGSSL === 'true' ? { rejectUnauthorized: false } : false,
});

// Create migrations tracking table if it doesn't exist
async function ensureMigrationsTable() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        version TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        applied_at TIMESTAMPTZ DEFAULT NOW(),
        rolled_back_at TIMESTAMPTZ
      );
    `);
    console.log('✓ Migrations tracking table ready');
  } finally {
    client.release();
  }
}

// Apply a migration
async function applyMigration(version) {
  const client = await pool.connect();
  try {
    // Check if migration already applied
    const checkResult = await client.query(
      'SELECT * FROM schema_migrations WHERE version = $1 AND rolled_back_at IS NULL',
      [version]
    );
    
    if (checkResult.rows.length > 0) {
      console.log(`⚠ Migration ${version} already applied`);
      return;
    }

    // Read migration file
    const migrationPath = join(__dirname, `${version}_admin_center_schema.sql`);
    const migrationSQL = readFileSync(migrationPath, 'utf8');

    console.log(`Applying migration ${version}...`);
    
    // Begin transaction
    await client.query('BEGIN');
    
    try {
      // Execute migration
      await client.query(migrationSQL);
      
      // Record migration
      await client.query(
        'INSERT INTO schema_migrations (version, name) VALUES ($1, $2)',
        [version, 'admin_center_schema']
      );
      
      // Commit transaction
      await client.query('COMMIT');
      console.log(`✓ Migration ${version} applied successfully`);
    } catch (error) {
      // Rollback on error
      await client.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error(`✗ Failed to apply migration ${version}:`, error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Rollback a migration
async function rollbackMigration(version) {
  const client = await pool.connect();
  try {
    // Check if migration is applied
    const checkResult = await client.query(
      'SELECT * FROM schema_migrations WHERE version = $1 AND rolled_back_at IS NULL',
      [version]
    );
    
    if (checkResult.rows.length === 0) {
      console.log(`⚠ Migration ${version} not applied or already rolled back`);
      return;
    }

    // Read rollback file
    const rollbackPath = join(__dirname, `${version}_admin_center_schema_rollback.sql`);
    const rollbackSQL = readFileSync(rollbackPath, 'utf8');

    console.log(`Rolling back migration ${version}...`);
    
    // Begin transaction
    await client.query('BEGIN');
    
    try {
      // Execute rollback
      await client.query(rollbackSQL);
      
      // Update migration record
      await client.query(
        'UPDATE schema_migrations SET rolled_back_at = NOW() WHERE version = $1',
        [version]
      );
      
      // Commit transaction
      await client.query('COMMIT');
      console.log(`✓ Migration ${version} rolled back successfully`);
    } catch (error) {
      // Rollback on error
      await client.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error(`✗ Failed to rollback migration ${version}:`, error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Show migration status
async function showStatus() {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      SELECT version, name, applied_at, rolled_back_at
      FROM schema_migrations
      ORDER BY applied_at DESC
    `);
    
    console.log('\nMigration Status:');
    console.log('─'.repeat(80));
    
    if (result.rows.length === 0) {
      console.log('No migrations applied yet');
    } else {
      result.rows.forEach(row => {
        const status = row.rolled_back_at ? '✗ ROLLED BACK' : '✓ APPLIED';
        const date = row.rolled_back_at || row.applied_at;
        console.log(`${status} | ${row.version} | ${row.name} | ${date.toISOString()}`);
      });
    }
    
    console.log('─'.repeat(80));
  } finally {
    client.release();
  }
}

// Main execution
async function main() {
  const [,, command, version] = process.argv;

  if (!command) {
    console.log('Usage:');
    console.log('  node run-migration.js up <version>    - Apply migration');
    console.log('  node run-migration.js down <version>  - Rollback migration');
    console.log('  node run-migration.js status          - Show migration status');
    process.exit(1);
  }

  try {
    await ensureMigrationsTable();

    switch (command) {
      case 'up':
        if (!version) {
          console.error('Error: Version required for "up" command');
          process.exit(1);
        }
        await applyMigration(version);
        break;
      
      case 'down':
        if (!version) {
          console.error('Error: Version required for "down" command');
          process.exit(1);
        }
        await rollbackMigration(version);
        break;
      
      case 'status':
        await showStatus();
        break;
      
      default:
        console.error(`Unknown command: ${command}`);
        process.exit(1);
    }
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
