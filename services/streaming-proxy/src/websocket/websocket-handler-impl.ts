/**
 * WebSocket Handler Implementation
 * Manages WebSocket connection lifecycle, heartbeat monitoring, and message routing
 * Integrates with AuthMiddleware and RateLimiter for security
 */

import { IncomingMessage } from 'http';
import { Socket } from 'net';
import { WebSocket, WebSocketServer } from 'ws';
import { WebSocketHandler, HealthStatus } from '../interfaces/websocket-handler';
import { AuthMiddleware } from '../interfaces/auth-middleware';
import { RateLimiter } from '../interfaces/rate-limiter';

interface ConnectionMetadata {
  id: string;
  userId?: string;
  connectedAt: Date;
  lastActivityAt: Date;
  lastPongAt: Date;
  messageCount: number;
  latency: number;
  isHealthy: boolean;
  heartbeatTimer?: NodeJS.Timeout;
  ip: string;
}

interface WebSocketMessage {
  type: 'request' | 'ping' | 'pong' | 'close';
  requestId?: string;
  payload?: any;
  timestamp: number;
}

/**
 * WebSocket Handler Implementation
 * Handles WebSocket connections with authentication, rate limiting, and heartbeat monitoring
 */
export class WebSocketHandlerImpl implements WebSocketHandler {
  private readonly wss: WebSocketServer;
  private readonly authMiddleware: AuthMiddleware;
  private readonly rateLimiter: RateLimiter;
  private readonly connections: Map<WebSocket, ConnectionMetadata> = new Map();
  private readonly pingInterval = 30000; // 30 seconds
  private readonly pongTimeout = 5000; // 5 seconds
  private readonly maxFrameSize = 1024 * 1024; // 1MB
  private connectionIdCounter = 0;

  constructor(
    wss: WebSocketServer,
    authMiddleware: AuthMiddleware,
    rateLimiter: RateLimiter
  ) {
    this.wss = wss;
    this.authMiddleware = authMiddleware;
    this.rateLimiter = rateLimiter;

    // Configure WebSocket server
    this.configureWebSocketServer();
  }

  /**
   * Configure WebSocket server settings
   */
  private configureWebSocketServer(): void {
    this.wss.on('connection', (ws: WebSocket, req: IncomingMessage) => {
      this.handleConnection(ws, req).catch((error) => {
        console.error('Error handling connection:', error);
        ws.close(1011, 'Internal server error');
      });
    });

    this.wss.on('error', (error) => {
      console.error('WebSocket server error:', error);
    });
  }

  /**
   * Handle WebSocket upgrade request
   */
  async handleUpgrade(req: IncomingMessage, socket: Socket, head: Buffer): Promise<void> {
    try {
      // Extract token from query string or headers
      const token = this.extractToken(req);
      
      if (!token) {
        socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
        socket.destroy();
        return;
      }

      // Validate token
      const validation = await this.authMiddleware.validateToken(token);
      
      if (!validation.valid) {
        const reason = validation.error === 'Token expired' ? 'Token expired' : 'Invalid token';
        socket.write(`HTTP/1.1 401 Unauthorized\r\n\r\n${reason}`);
        socket.destroy();
        
        if (validation.userId) {
          this.authMiddleware.logAuthAttempt(validation.userId, false, validation.error);
        }
        return;
      }

      // Get user context
      const userContext = await this.authMiddleware.getUserContext(token);
      
      // Check rate limit
      const ip = this.getClientIp(req);
      const rateLimitResult = await this.rateLimiter.checkLimit(userContext.userId, ip);
      
      if (!rateLimitResult.allowed) {
        socket.write(`HTTP/1.1 429 Too Many Requests\r\nRetry-After: ${rateLimitResult.retryAfter}\r\n\r\n`);
        socket.destroy();
        return;
      }

      // Upgrade connection
      this.wss.handleUpgrade(req, socket, head, (ws) => {
        // Store user context in WebSocket object
        (ws as any).userId = userContext.userId;
        (ws as any).userTier = userContext.tier;
        
        this.wss.emit('connection', ws, req);
        
        this.authMiddleware.logAuthAttempt(userContext.userId, true, 'WebSocket connection established');
      });
    } catch (error) {
      console.error('Error during WebSocket upgrade:', error);
      socket.write('HTTP/1.1 500 Internal Server Error\r\n\r\n');
      socket.destroy();
    }
  }

  /**
   * Handle new WebSocket connection
   */
  async handleConnection(ws: WebSocket, req: IncomingMessage): Promise<void> {
    const connectionId = `ws-${++this.connectionIdCounter}-${Date.now()}`;
    const userId = (ws as any).userId;
    const ip = this.getClientIp(req);

    // Create connection metadata
    const metadata: ConnectionMetadata = {
      id: connectionId,
      userId,
      connectedAt: new Date(),
      lastActivityAt: new Date(),
      lastPongAt: new Date(),
      messageCount: 0,
      latency: 0,
      isHealthy: true,
      ip,
    };

    this.connections.set(ws, metadata);

    // Log connection
    console.log(JSON.stringify({
      type: 'connection_established',
      connectionId,
      userId,
      ip,
      timestamp: new Date().toISOString(),
    }));

    // Configure WebSocket
    ws.binaryType = 'nodebuffer';

    // Set up event handlers
    ws.on('message', (data: Buffer) => {
      this.handleMessage(ws, data).catch((error) => {
        console.error('Error handling message:', error);
      });
    });

    ws.on('ping', () => {
      this.handlePing(ws);
    });

    ws.on('pong', () => {
      this.handlePong(ws);
    });

    ws.on('close', (code: number, reason: Buffer) => {
      this.handleDisconnect(ws, code, reason.toString()).catch((error) => {
        console.error('Error handling disconnect:', error);
      });
    });

    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
      metadata.isHealthy = false;
    });

    // Start heartbeat monitoring
    this.startHeartbeat(ws);
  }

  /**
   * Handle WebSocket disconnection
   */
  async handleDisconnect(ws: WebSocket, code: number, reason: string): Promise<void> {
    const metadata = this.connections.get(ws);
    
    if (!metadata) {
      return;
    }

    // Stop heartbeat
    this.stopHeartbeat(ws);

    // Calculate connection duration
    const duration = Date.now() - metadata.connectedAt.getTime();

    // Log disconnection
    console.log(JSON.stringify({
      type: 'connection_closed',
      connectionId: metadata.id,
      userId: metadata.userId,
      code,
      reason,
      duration,
      messageCount: metadata.messageCount,
      timestamp: new Date().toISOString(),
    }));

    // Remove connection
    this.connections.delete(ws);
  }

  /**
   * Handle incoming WebSocket message
   */
  async handleMessage(ws: WebSocket, data: Buffer): Promise<void> {
    const metadata = this.connections.get(ws);
    
    if (!metadata) {
      ws.close(1011, 'Connection not found');
      return;
    }

    // Check frame size
    if (data.length > this.maxFrameSize) {
      console.error(JSON.stringify({
        type: 'frame_size_violation',
        connectionId: metadata.id,
        userId: metadata.userId,
        size: data.length,
        maxSize: this.maxFrameSize,
        timestamp: new Date().toISOString(),
      }));
      
      ws.close(1009, 'Message too large');
      return;
    }

    // Update activity
    metadata.lastActivityAt = new Date();
    metadata.messageCount++;

    // Check rate limit
    const rateLimitResult = await this.rateLimiter.checkLimit(
      metadata.userId || 'anonymous',
      metadata.ip
    );

    if (!rateLimitResult.allowed) {
      const errorMessage = JSON.stringify({
        type: 'error',
        error: 'Rate limit exceeded',
        retryAfter: rateLimitResult.retryAfter,
      });
      
      ws.send(errorMessage);
      return;
    }

    // Record request for rate limiting
    this.rateLimiter.recordRequest(metadata.userId || 'anonymous', metadata.ip);

    try {
      // Parse message
      const message: WebSocketMessage = JSON.parse(data.toString());

      // Route message based on type
      switch (message.type) {
        case 'ping':
          this.handlePing(ws);
          break;
        
        case 'pong':
          this.handlePong(ws);
          break;
        
        case 'request':
          // Forward to request handler (to be implemented in integration)
          await this.handleForwardRequest(ws, message);
          break;
        
        case 'close':
          ws.close(1000, 'Normal closure');
          break;
        
        default:
          console.warn(`Unknown message type: ${message.type}`);
      }
    } catch (error) {
      console.error('Error parsing message:', error);
      
      const errorMessage = JSON.stringify({
        type: 'error',
        error: 'Invalid message format',
      });
      
      ws.send(errorMessage);
    }
  }

  /**
   * Handle ping frame
   */
  handlePing(ws: WebSocket): void {
    const metadata = this.connections.get(ws);
    
    if (!metadata) {
      return;
    }

    // Send pong response
    ws.pong();
    
    metadata.lastActivityAt = new Date();
  }

  /**
   * Handle pong frame
   */
  handlePong(ws: WebSocket): void {
    const metadata = this.connections.get(ws);
    
    if (!metadata) {
      return;
    }

    // Update last pong time
    metadata.lastPongAt = new Date();
    metadata.lastActivityAt = new Date();
    
    // Calculate latency
    const now = Date.now();
    const lastPing = now - this.pingInterval;
    metadata.latency = now - lastPing;
    
    // Mark as healthy
    metadata.isHealthy = true;
  }

  /**
   * Start heartbeat monitoring for connection
   */
  startHeartbeat(ws: WebSocket): void {
    const metadata = this.connections.get(ws);
    
    if (!metadata) {
      return;
    }

    // Send ping every pingInterval
    metadata.heartbeatTimer = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        // Check if last pong was received
        const timeSinceLastPong = Date.now() - metadata.lastPongAt.getTime();
        
        if (timeSinceLastPong > this.pingInterval + this.pongTimeout) {
          // Connection is dead
          console.warn(JSON.stringify({
            type: 'connection_timeout',
            connectionId: metadata.id,
            userId: metadata.userId,
            timeSinceLastPong,
            timestamp: new Date().toISOString(),
          }));
          
          metadata.isHealthy = false;
          ws.close(1001, 'Connection timeout');
          return;
        }

        // Send ping
        ws.ping();
      }
    }, this.pingInterval);
  }

  /**
   * Stop heartbeat monitoring for connection
   */
  stopHeartbeat(ws: WebSocket): void {
    const metadata = this.connections.get(ws);
    
    if (!metadata || !metadata.heartbeatTimer) {
      return;
    }

    clearInterval(metadata.heartbeatTimer);
    metadata.heartbeatTimer = undefined;
  }

  /**
   * Check overall connection health
   */
  async checkConnectionHealth(): Promise<HealthStatus> {
    let healthyCount = 0;
    let unhealthyCount = 0;
    let totalLatency = 0;
    let latencyCount = 0;

    for (const [ws, metadata] of this.connections.entries()) {
      if (ws.readyState === WebSocket.OPEN) {
        if (metadata.isHealthy) {
          healthyCount++;
        } else {
          unhealthyCount++;
        }

        if (metadata.latency > 0) {
          totalLatency += metadata.latency;
          latencyCount++;
        }
      } else {
        unhealthyCount++;
      }
    }

    const averageLatency = latencyCount > 0 ? totalLatency / latencyCount : 0;

    return {
      activeConnections: this.connections.size,
      healthyConnections: healthyCount,
      unhealthyConnections: unhealthyCount,
      averageLatency,
    };
  }

  /**
   * Handle forward request (placeholder for integration)
   */
  private async handleForwardRequest(ws: WebSocket, message: WebSocketMessage): Promise<void> {
    // This will be implemented during integration with ConnectionPool and SSH forwarding
    // For now, just echo back
    const response = {
      type: 'response',
      requestId: message.requestId,
      payload: { status: 'received' },
      timestamp: Date.now(),
    };

    ws.send(JSON.stringify(response));
  }

  /**
   * Extract authentication token from request
   */
  private extractToken(req: IncomingMessage): string | null {
    // Check query string
    const url = new URL(req.url || '', `http://${req.headers.host}`);
    const tokenFromQuery = url.searchParams.get('token');
    
    if (tokenFromQuery) {
      return tokenFromQuery;
    }

    // Check Authorization header
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    return null;
  }

  /**
   * Get client IP address from request
   */
  private getClientIp(req: IncomingMessage): string {
    // Check X-Forwarded-For header (for proxies)
    const forwardedFor = req.headers['x-forwarded-for'];
    
    if (forwardedFor) {
      const ips = Array.isArray(forwardedFor) ? forwardedFor[0] : forwardedFor;
      return ips.split(',')[0].trim();
    }

    // Check X-Real-IP header
    const realIp = req.headers['x-real-ip'];
    
    if (realIp) {
      return Array.isArray(realIp) ? realIp[0] : realIp;
    }

    // Fall back to socket address
    return req.socket.remoteAddress || 'unknown';
  }

  /**
   * Get all active connections
   */
  getActiveConnections(): number {
    return this.connections.size;
  }

  /**
   * Get connection by user ID
   */
  getConnectionsByUserId(userId: string): WebSocket[] {
    const connections: WebSocket[] = [];
    
    for (const [ws, metadata] of this.connections.entries()) {
      if (metadata.userId === userId && ws.readyState === WebSocket.OPEN) {
        connections.push(ws);
      }
    }

    return connections;
  }

  /**
   * Close all connections gracefully
   */
  async closeAllConnections(reason: string = 'Server shutdown'): Promise<void> {
    const closePromises: Promise<void>[] = [];

    for (const [ws, metadata] of this.connections.entries()) {
      if (ws.readyState === WebSocket.OPEN) {
        closePromises.push(
          new Promise((resolve) => {
            ws.once('close', () => resolve());
            ws.close(1001, reason);
            
            // Force close after timeout
            setTimeout(() => {
              if (ws.readyState !== WebSocket.CLOSED) {
                ws.terminate();
              }
              resolve();
            }, 5000);
          })
        );
      }
    }

    await Promise.all(closePromises);
  }
}
