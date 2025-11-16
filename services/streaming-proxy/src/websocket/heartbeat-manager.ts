/**
 * Heartbeat Manager
 * Manages WebSocket heartbeat monitoring with ping/pong protocol
 * Detects dead connections and closes unresponsive connections
 */

import { WebSocket } from 'ws';

interface HeartbeatMetadata {
  lastPingAt: Date;
  lastPongAt: Date;
  missedPongs: number;
  latency: number;
  timer?: NodeJS.Timeout;
}

interface HeartbeatConfig {
  pingInterval: number; // Interval between pings (ms)
  pongTimeout: number; // Max time to wait for pong (ms)
  maxMissedPongs: number; // Max missed pongs before closing
}

/**
 * Heartbeat Manager
 * Monitors WebSocket connections using ping/pong protocol
 */
export class HeartbeatManager {
  private readonly config: HeartbeatConfig;
  private readonly heartbeats: Map<WebSocket, HeartbeatMetadata> = new Map();

  constructor(config?: Partial<HeartbeatConfig>) {
    this.config = {
      pingInterval: config?.pingInterval || 30000, // 30 seconds
      pongTimeout: config?.pongTimeout || 5000, // 5 seconds
      maxMissedPongs: config?.maxMissedPongs || 3, // 3 missed pongs
    };
  }

  /**
   * Start heartbeat monitoring for a WebSocket connection
   */
  startHeartbeat(ws: WebSocket, onTimeout?: (ws: WebSocket) => void): void {
    if (this.heartbeats.has(ws)) {
      // Already monitoring this connection
      return;
    }

    const metadata: HeartbeatMetadata = {
      lastPingAt: new Date(),
      lastPongAt: new Date(),
      missedPongs: 0,
      latency: 0,
    };

    this.heartbeats.set(ws, metadata);

    // Set up pong handler
    ws.on('pong', () => {
      this.handlePong(ws);
    });

    // Start ping timer
    metadata.timer = setInterval(() => {
      this.sendPing(ws, onTimeout);
    }, this.config.pingInterval);

    // Send initial ping
    this.sendPing(ws, onTimeout);
  }

  /**
   * Stop heartbeat monitoring for a WebSocket connection
   */
  stopHeartbeat(ws: WebSocket): void {
    const metadata = this.heartbeats.get(ws);

    if (!metadata) {
      return;
    }

    // Clear timer
    if (metadata.timer) {
      clearInterval(metadata.timer);
      metadata.timer = undefined;
    }

    // Remove from map
    this.heartbeats.delete(ws);
  }

  /**
   * Send ping to WebSocket connection
   */
  private sendPing(ws: WebSocket, onTimeout?: (ws: WebSocket) => void): void {
    const metadata = this.heartbeats.get(ws);

    if (!metadata) {
      return;
    }

    // Check if connection is still open
    if (ws.readyState !== WebSocket.OPEN) {
      this.stopHeartbeat(ws);
      return;
    }

    // Check if last pong was received within timeout
    const timeSinceLastPong = Date.now() - metadata.lastPongAt.getTime();

    if (timeSinceLastPong > this.config.pingInterval + this.config.pongTimeout) {
      metadata.missedPongs++;

      console.warn(JSON.stringify({
        type: 'heartbeat_missed_pong',
        missedPongs: metadata.missedPongs,
        timeSinceLastPong,
        timestamp: new Date().toISOString(),
      }));

      // Check if max missed pongs exceeded
      if (metadata.missedPongs >= this.config.maxMissedPongs) {
        console.error(JSON.stringify({
          type: 'heartbeat_connection_dead',
          missedPongs: metadata.missedPongs,
          timeSinceLastPong,
          timestamp: new Date().toISOString(),
        }));

        // Stop heartbeat
        this.stopHeartbeat(ws);

        // Call timeout callback
        if (onTimeout) {
          onTimeout(ws);
        } else {
          // Default: close connection
          ws.close(1001, 'Connection timeout - no pong received');
        }

        return;
      }
    }

    // Send ping
    try {
      metadata.lastPingAt = new Date();
      ws.ping();
    } catch (error) {
      console.error('Error sending ping:', error);
      this.stopHeartbeat(ws);
    }
  }

  /**
   * Handle pong response from WebSocket connection
   */
  private handlePong(ws: WebSocket): void {
    const metadata = this.heartbeats.get(ws);

    if (!metadata) {
      return;
    }

    const now = new Date();
    metadata.lastPongAt = now;
    metadata.missedPongs = 0;

    // Calculate latency (round-trip time)
    const latency = now.getTime() - metadata.lastPingAt.getTime();
    metadata.latency = latency;

    console.log(JSON.stringify({
      type: 'heartbeat_pong_received',
      latency,
      timestamp: now.toISOString(),
    }));
  }

  /**
   * Get heartbeat statistics for a connection
   */
  getHeartbeatStats(ws: WebSocket): HeartbeatStats | null {
    const metadata = this.heartbeats.get(ws);

    if (!metadata) {
      return null;
    }

    return {
      lastPingAt: metadata.lastPingAt,
      lastPongAt: metadata.lastPongAt,
      missedPongs: metadata.missedPongs,
      latency: metadata.latency,
      isHealthy: metadata.missedPongs === 0,
    };
  }

  /**
   * Get all heartbeat statistics
   */
  getAllHeartbeatStats(): Map<WebSocket, HeartbeatStats> {
    const stats = new Map<WebSocket, HeartbeatStats>();

    for (const [ws, metadata] of this.heartbeats.entries()) {
      stats.set(ws, {
        lastPingAt: metadata.lastPingAt,
        lastPongAt: metadata.lastPongAt,
        missedPongs: metadata.missedPongs,
        latency: metadata.latency,
        isHealthy: metadata.missedPongs === 0,
      });
    }

    return stats;
  }

  /**
   * Check if connection is healthy based on heartbeat
   */
  isConnectionHealthy(ws: WebSocket): boolean {
    const metadata = this.heartbeats.get(ws);

    if (!metadata) {
      return false;
    }

    // Check if pong was received recently
    const timeSinceLastPong = Date.now() - metadata.lastPongAt.getTime();
    return timeSinceLastPong <= this.config.pingInterval + this.config.pongTimeout;
  }

  /**
   * Get number of monitored connections
   */
  getMonitoredConnectionCount(): number {
    return this.heartbeats.size;
  }

  /**
   * Stop all heartbeat monitoring
   */
  stopAll(): void {
    for (const ws of this.heartbeats.keys()) {
      this.stopHeartbeat(ws);
    }
  }
}

/**
 * Heartbeat statistics for a connection
 */
export interface HeartbeatStats {
  lastPingAt: Date;
  lastPongAt: Date;
  missedPongs: number;
  latency: number;
  isHealthy: boolean;
}
