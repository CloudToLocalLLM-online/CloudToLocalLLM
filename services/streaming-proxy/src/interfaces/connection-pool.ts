/**
 * Connection Pool Interface
 * Manages SSH connection pooling and reuse
 */

export interface ForwardRequest {
  id: string;
  method: string;
  path: string;
  headers: Record<string, string>;
  body?: Buffer;
}

export interface ForwardResponse {
  statusCode: number;
  headers: Record<string, string>;
  body: Buffer;
}

export interface SSHConnection {
  id: string;
  userId: string;
  createdAt: Date;
  lastUsedAt: Date;
  channelCount: number;

  /**
   * Forward request through SSH tunnel
   */
  forward(request: ForwardRequest): Promise<ForwardResponse>;

  /**
   * Close SSH connection
   */
  close(): Promise<void>;

  /**
   * Check if connection is healthy
   */
  isHealthy(): boolean;
}

export interface ConnectionPool {
  /**
   * Get or create SSH connection for user
   */
  getConnection(userId: string): Promise<SSHConnection>;

  /**
   * Release connection back to pool
   */
  releaseConnection(userId: string, connection: SSHConnection): void;

  /**
   * Close all connections for user
   */
  closeConnection(userId: string): Promise<void>;

  /**
   * Close all connections in pool
   */
  closeAllConnections(): Promise<void>;

  /**
   * Get active connection count for user
   */
  getActiveConnections(userId: string): number;

  /**
   * Get total connection count
   */
  getTotalConnections(): number;

  /**
   * Clean up stale connections
   * @param maxIdleTime - Maximum idle time in milliseconds
   * @returns Number of connections cleaned up
   */
  cleanupStaleConnections(maxIdleTime: number): Promise<number>;

  /**
   * Get pool statistics for monitoring
   */
  getPoolStats(): {
    totalConnections: number;
    userCount: number;
    connectionsByUser: Record<string, number>;
  };
}
