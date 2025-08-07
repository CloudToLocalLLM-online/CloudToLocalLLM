// CloudToLocalLLM - Cloud Run Database Migration Script
// This script handles database setup and migration for Cloud Run deployment
// Supports both SQLite (for development) and Cloud SQL (for production)

const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

// Configuration
const config = {
  dbType: process.env.DB_TYPE || 'sqlite',
  dbPath: process.env.DB_PATH || '/app/data/cloudtolocalllm.db',
  dbHost: process.env.DB_HOST,
  dbPort: process.env.DB_PORT || 5432,
  dbName: process.env.DB_NAME || 'cloudtolocalllm',
  dbUser: process.env.DB_USER,
  dbPassword: process.env.DB_PASSWORD,
  dbSsl: process.env.DB_SSL === 'true',
  
  // Cloud Run specific settings
  isCloudRun: process.env.K_SERVICE !== undefined,
  dataDir: '/app/data',
  backupDir: '/app/backups'
};

// Logging
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} ${msg}`),
  warn: (msg) => console.warn(`[WARN] ${new Date().toISOString()} ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} ${msg}`)
};

// Database schema for SQLite
const sqliteSchema = `
-- CloudToLocalLLM Database Schema for Cloud Run
-- This schema is optimized for Cloud Run deployment

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  auth0_id TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  picture TEXT,
  tier TEXT DEFAULT 'free',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_login DATETIME,
  is_active BOOLEAN DEFAULT 1
);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  data TEXT,
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- API keys table
CREATE TABLE IF NOT EXISTS api_keys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  key_hash TEXT UNIQUE NOT NULL,
  name TEXT,
  permissions TEXT, -- JSON array of permissions
  expires_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_used DATETIME,
  is_active BOOLEAN DEFAULT 1,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT,
  model TEXT,
  system_prompt TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  is_archived BOOLEAN DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id INTEGER NOT NULL,
  role TEXT NOT NULL, -- 'user', 'assistant', 'system'
  content TEXT NOT NULL,
  metadata TEXT, -- JSON metadata
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
);

-- Usage tracking table
CREATE TABLE IF NOT EXISTS usage_tracking (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  action TEXT NOT NULL, -- 'chat', 'api_call', etc.
  tokens_used INTEGER DEFAULT 0,
  cost DECIMAL(10,6) DEFAULT 0,
  metadata TEXT, -- JSON metadata
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- System settings table
CREATE TABLE IF NOT EXISTS system_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  description TEXT,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_auth0_id ON users (auth0_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions (expires_at);
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON api_keys (user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON api_keys (key_hash);
CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations (user_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_usage_tracking_user_id ON usage_tracking (user_id);
CREATE INDEX IF NOT EXISTS idx_usage_tracking_created_at ON usage_tracking (created_at);

-- Insert default system settings
INSERT OR IGNORE INTO system_settings (key, value, description) VALUES
  ('app_version', '1.0.0', 'Application version'),
  ('db_version', '1.0.0', 'Database schema version'),
  ('deployment_type', 'cloudrun', 'Deployment environment'),
  ('max_conversations_per_user', '100', 'Maximum conversations per user'),
  ('max_messages_per_conversation', '1000', 'Maximum messages per conversation'),
  ('token_limit_free_tier', '10000', 'Token limit for free tier users'),
  ('token_limit_pro_tier', '100000', 'Token limit for pro tier users');
`;

// Setup directories for Cloud Run
function setupDirectories() {
  log.info('Setting up directories for Cloud Run...');
  
  const dirs = [config.dataDir, config.backupDir];
  
  for (const dir of dirs) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
      log.info(`Created directory: ${dir}`);
    }
  }
  
  log.success('Directories setup completed');
}

// Initialize SQLite database
async function initializeSQLite() {
  log.info('Initializing SQLite database...');
  
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(config.dbPath, (err) => {
      if (err) {
        log.error(`Failed to connect to SQLite database: ${err.message}`);
        reject(err);
        return;
      }
      
      log.info(`Connected to SQLite database: ${config.dbPath}`);
      
      // Execute schema
      db.exec(sqliteSchema, (err) => {
        if (err) {
          log.error(`Failed to execute schema: ${err.message}`);
          db.close();
          reject(err);
          return;
        }
        
        log.success('SQLite database schema created successfully');
        
        // Close database connection
        db.close((err) => {
          if (err) {
            log.error(`Error closing database: ${err.message}`);
            reject(err);
          } else {
            log.info('Database connection closed');
            resolve();
          }
        });
      });
    });
  });
}

// Initialize Cloud SQL database (PostgreSQL/MySQL)
async function initializeCloudSQL() {
  log.info('Initializing Cloud SQL database...');
  
  // This would require pg or mysql2 package
  // For now, we'll just log the configuration
  log.info('Cloud SQL configuration:');
  log.info(`  Host: ${config.dbHost}`);
  log.info(`  Port: ${config.dbPort}`);
  log.info(`  Database: ${config.dbName}`);
  log.info(`  User: ${config.dbUser}`);
  log.info(`  SSL: ${config.dbSsl}`);
  
  // TODO: Implement Cloud SQL migration
  log.warn('Cloud SQL migration not yet implemented - using SQLite fallback');
  return initializeSQLite();
}

// Create backup of existing database
async function createBackup() {
  if (config.dbType === 'sqlite' && fs.existsSync(config.dbPath)) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupPath = path.join(config.backupDir, `backup-${timestamp}.db`);
    
    try {
      fs.copyFileSync(config.dbPath, backupPath);
      log.success(`Database backup created: ${backupPath}`);
    } catch (error) {
      log.error(`Failed to create backup: ${error.message}`);
      throw error;
    }
  }
}

// Verify database integrity
async function verifyDatabase() {
  log.info('Verifying database integrity...');
  
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(config.dbPath, sqlite3.OPEN_READONLY, (err) => {
      if (err) {
        log.error(`Failed to open database for verification: ${err.message}`);
        reject(err);
        return;
      }
      
      // Check if required tables exist
      const requiredTables = ['users', 'sessions', 'conversations', 'messages', 'system_settings'];
      let tablesChecked = 0;
      
      for (const table of requiredTables) {
        db.get(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
          (err, row) => {
            if (err) {
              log.error(`Error checking table ${table}: ${err.message}`);
              db.close();
              reject(err);
              return;
            }
            
            if (!row) {
              log.error(`Required table ${table} not found`);
              db.close();
              reject(new Error(`Missing table: ${table}`));
              return;
            }
            
            tablesChecked++;
            if (tablesChecked === requiredTables.length) {
              log.success('Database integrity verification passed');
              db.close();
              resolve();
            }
          }
        );
      }
    });
  });
}

// Main migration function
async function migrate() {
  try {
    log.info('Starting CloudToLocalLLM database migration for Cloud Run...');
    log.info(`Environment: ${config.isCloudRun ? 'Cloud Run' : 'Local'}`);
    log.info(`Database type: ${config.dbType}`);
    
    // Setup directories
    setupDirectories();
    
    // Create backup if database exists
    await createBackup();
    
    // Initialize database based on type
    if (config.dbType === 'sqlite') {
      await initializeSQLite();
    } else {
      await initializeCloudSQL();
    }
    
    // Verify database integrity
    await verifyDatabase();
    
    log.success('Database migration completed successfully!');
    
    // Output configuration for debugging
    if (config.isCloudRun) {
      log.info('Cloud Run database configuration:');
      log.info(`  Database path: ${config.dbPath}`);
      log.info(`  Data directory: ${config.dataDir}`);
      log.info(`  Backup directory: ${config.backupDir}`);
    }
    
  } catch (error) {
    log.error(`Database migration failed: ${error.message}`);
    process.exit(1);
  }
}

// Run migration if this script is executed directly
if (require.main === module) {
  migrate();
}

module.exports = {
  migrate,
  config,
  setupDirectories,
  initializeSQLite,
  createBackup,
  verifyDatabase
};
