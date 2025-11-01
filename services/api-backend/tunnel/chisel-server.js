/**
 * @fileoverview Chisel server wrapper for managing Chisel reverse proxy tunnel server
 */

import { spawn } from 'child_process';
import { EventEmitter } from 'events';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * ChiselServer manages the Chisel binary process
 * Chisel is a fast TCP/UDP tunnel over HTTP using Go
 */
export class ChiselServer extends EventEmitter {
  /**
   * @param {Object} config - Configuration object
   * @param {winston.Logger} logger - Logger instance
   * @param {number} [config.port=8080] - Chisel server port
   * @param {string} [config.binary] - Path to Chisel binary (default: auto-detect)
   */
  constructor(logger, config = {}) {
    super();
    this.logger = logger;
    this.port = config.port || 8080;
    this.binary = config.binary || this._findChiselBinary();
    this.process = null;
    this.isRunning = false;
    this._startPromise = null;
  }

  /**
   * Find Chisel binary path
   * @returns {string} Path to Chisel binary
   */
  _findChiselBinary() {
    // Try common locations
    const possiblePaths = [
      process.env.CHISEL_BINARY,
      '/usr/local/bin/chisel',
      '/usr/bin/chisel',
      path.join(__dirname, '../../bin/chisel'),
      'chisel', // In PATH
    ].filter(Boolean);

    for (const binaryPath of possiblePaths) {
      // In production, we'll verify the binary exists
      return binaryPath;
    }

    // Default fallback
    return 'chisel';
  }

  /**
   * Start Chisel server
   * @returns {Promise<void>}
   */
  async start() {
    if (this.isRunning) {
      this.logger.warn('Chisel server already running');
      return;
    }

    if (this._startPromise) {
      return this._startPromise;
    }

    this._startPromise = this._doStart();
    return this._startPromise;
  }

  /**
   * Internal start method
   * @private
   * @returns {Promise<void>}
   */
  async _doStart() {
    return new Promise((resolve, reject) => {
      try {
        // Chisel server command: chisel server --port <port> --reverse
        // --reverse allows clients to register tunnels
        const args = [
          'server',
          '--port', this.port.toString(),
          '--reverse',
          '--host', '0.0.0.0', // Listen on all interfaces
        ];

        this.logger.info('Starting Chisel server', {
          binary: this.binary,
          port: this.port,
          args: args.join(' '),
        });

        this.process = spawn(this.binary, args, {
          stdio: ['ignore', 'pipe', 'pipe'],
          detached: false,
        });

        let started = false;

        // Handle stdout
        this.process.stdout.on('data', (data) => {
          const output = data.toString();
          this.logger.debug(`Chisel stdout: ${output}`);

          // Check for server ready message
          if (output.includes('server') && !started) {
            this.isRunning = true;
            started = true;
            this.emit('started');
            resolve();
          }
        });

        // Handle stderr
        this.process.stderr.on('data', (data) => {
          const output = data.toString();
          this.logger.warn(`Chisel stderr: ${output}`);
          
          // Some Chisel info goes to stderr
          if (output.includes('server') && !started) {
            this.isRunning = true;
            started = true;
            this.emit('started');
            resolve();
          }
        });

        // Handle process errors
        this.process.on('error', (error) => {
          this.logger.error('Failed to start Chisel server', {
            error: error.message,
            binary: this.binary,
          });
          this.process = null;
          this.isRunning = false;
          if (!started) {
            reject(error);
          }
          this.emit('error', error);
        });

        // Handle process exit
        this.process.on('exit', (code, signal) => {
          this.logger.warn('Chisel server exited', { code, signal });
          this.isRunning = false;
          this.process = null;
          this.emit('exited', { code, signal });
        });

        // Timeout for startup
        setTimeout(() => {
          if (!started) {
            // Assume it started if no error after 2 seconds
            if (this.process && this.process.pid) {
              this.isRunning = true;
              started = true;
              this.emit('started');
              resolve();
            }
          }
        }, 2000);

      } catch (error) {
        this.logger.error('Exception starting Chisel server', {
          error: error.message,
          stack: error.stack,
        });
        this.process = null;
        this.isRunning = false;
        reject(error);
      }
    });
  }

  /**
   * Stop Chisel server
   * @returns {Promise<void>}
   */
  async stop() {
    if (!this.process) {
      return;
    }

    return new Promise((resolve) => {
      this.logger.info('Stopping Chisel server');

      if (this.process.killed) {
        this.process = null;
        this.isRunning = false;
        resolve();
        return;
      }

      this.process.once('exit', () => {
        this.process = null;
        this.isRunning = false;
        resolve();
      });

      // Try graceful shutdown first
      if (process.platform !== 'win32') {
        this.process.kill('SIGTERM');
        
        // Force kill after 5 seconds
        setTimeout(() => {
          if (this.process && !this.process.killed) {
            this.process.kill('SIGKILL');
          }
        }, 5000);
      } else {
        // Windows doesn't support SIGTERM
        this.process.kill();
      }
    });
  }

  /**
   * Check if server is running
   * @returns {boolean}
   */
  getStatus() {
    return {
      running: this.isRunning,
      port: this.port,
      pid: this.process?.pid || null,
    };
  }
}

