/**
 * Connection Pool Module
 * Exports all connection pool related components
 */

export { ConnectionPoolImpl, ConnectionPoolConfig } from './connection-pool-impl.js';
export { SSHConnectionImpl, SSHConnectionConfig } from './ssh-connection-impl.js';
export { ConnectionCleanupService, CleanupServiceConfig } from './connection-cleanup-service.js';
export { GracefulShutdownManager, ShutdownConfig, ShutdownResult } from './graceful-shutdown-manager.js';

// Re-export interfaces
export type {
  ConnectionPool,
  SSHConnection,
  ForwardRequest,
  ForwardResponse,
} from '../interfaces/connection-pool.js';
