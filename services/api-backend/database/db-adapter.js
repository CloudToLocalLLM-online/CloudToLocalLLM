import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import pg from 'pg';
import { TunnelLogger } from '../utils/logger.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const { Pool } = pg;

export class DBAdapter {
  constructor(env = process.env) {
    this.env = env;
    this.type = (env.DB_TYPE || 'sqlite').toLowerCase();
    this.logger = new TunnelLogger('db-adapter');
    this.sqlite = null;
    this.pgPool = null;
  }

  async connect() {
    if (this.type === 'postgres') {
      return this.#connectPostgres();
    }
    return this.#connectSqlite();
  }

  async #connectSqlite() {
    const filename = this.env.DB_PATH || join(__dirname, '../data/cloudtolocalllm.db');
    this.sqlite = await open({ filename, driver: sqlite3.Database });
    await this.sqlite.get('SELECT 1');
    this.logger.info('Connected to SQLite', { filename });
    return { driver: 'sqlite', client: this.sqlite };
  }

  async #connectPostgres() {
    const cfg = this.#pgConfigFromEnv();
    this.pgPool = new Pool(cfg);
    await this.pgPool.query('SELECT 1');
    this.logger.info('Connected to Postgres', { host: cfg.host || cfg.hostaddr || cfg.connectionString || cfg.host_unix_socket || 'socket' });
    return { driver: 'postgres', client: this.pgPool };
  }

  #pgConfigFromEnv() {
    const {
      DB_HOST,
      DB_PORT = '5432',
      DB_NAME,
      DB_USER,
      DB_PASSWORD,
      DB_SSL,
    } = this.env;

    // Support Cloud SQL Unix socket path via host like /cloudsql/PROJECT:REGION:INSTANCE
    const isUnixSocket = DB_HOST && DB_HOST.startsWith('/cloudsql/');

    const base = {
      database: DB_NAME,
      user: DB_USER,
      password: DB_PASSWORD,
      port: parseInt(DB_PORT, 10),
      ssl: DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    };

    if (isUnixSocket) {
      return {
        ...base,
        host: undefined,
        // pg supports unix domain socket by providing host as the directory containing .s.PGSQL.5432
        // Cloud SQL sidecar mounts /cloudsql/INSTANCE/.s.PGSQL.5432
        // Use host as the directory path and it will use a domain socket
        host: DB_HOST,
      };
    }

    return { ...base, host: DB_HOST };
  }
}

