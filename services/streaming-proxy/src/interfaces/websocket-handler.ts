/**
 * WebSocket Handler Interface
 * Manages WebSocket connection lifecycle and message handling
 */

import { IncomingMessage } from 'http';
import { Socket } from 'net';
import { WebSocket } from 'ws';

export interface HealthStatus {
  activeConnections: number;
  healthyConnections: number;
  unhealthyConnections: number;
  averageLatency: number;
}

export interface WebSocketHandler {
  /**
   * Handle WebSocket upgrade request
   */
  handleUpgrade(req: IncomingMessage, socket: Socket, head: Buffer): Promise<void>;

  /**
   * Handle new WebSocket connection
   */
  handleConnection(ws: WebSocket, req: IncomingMessage): Promise<void>;

  /**
   * Handle WebSocket disconnection
   */
  handleDisconnect(ws: WebSocket, code: number, reason: string): Promise<void>;

  /**
   * Handle incoming WebSocket message
   */
  handleMessage(ws: WebSocket, message: Buffer): Promise<void>;

  /**
   * Handle ping frame
   */
  handlePing(ws: WebSocket): void;

  /**
   * Handle pong frame
   */
  handlePong(ws: WebSocket): void;

  /**
   * Start heartbeat monitoring for connection
   */
  startHeartbeat(ws: WebSocket): void;

  /**
   * Stop heartbeat monitoring for connection
   */
  stopHeartbeat(ws: WebSocket): void;

  /**
   * Check overall connection health
   */
  checkConnectionHealth(): Promise<HealthStatus>;
}
