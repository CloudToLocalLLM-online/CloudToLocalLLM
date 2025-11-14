/**
 * @fileoverview SSHProxy manages tunnel connections through SSH over WebSocket
 * Handles user connections, request forwarding, and connection lifecycle
 */

import WebSocket from 'ws';
import http from 'http';
import https from 'https';
import { URL } from 'url';
import { Server as SSHServer } from 'ssh2';
import { AuthService } from '../auth/auth-service.js';

const REQUEST_TIMEOUT = 30000; // 30 seconds

/**
 * Manages SSH over WebSocket tunnel connections for tunneling HTTP requests
 */
export class SSHProxy {
  /**
   * @param {Object} config - Configuration object
   * @param {winston.Logger} logger - Logger instance
   * @param {AuthService} authService - AuthService for JWT validation
   */
  constructor(logger, config, authService) {
    this.logger = logger;
    this.config = config;
    this.authService = authService;

    // WebSocket server for SSH connections
    this.wss = null;

    // SSH server instance
    this.sshServer = null;

    // User connections: userId -> { port, localPort, timestamp, ws, sshStream }
    // When an SSH client connects over WebSocket, it registers a reverse tunnel
    // The server assigns a port that forwards to the client's local port
    this.userConnections = new Map();

    // Track registered tunnels: tunnelId -> userId
    this.tunnelRegistry = new Map();

    // Active WebSocket connections: ws -> { userId, tunnelId }
    this.wsConnections = new Map();

    // Metrics
    this.metrics = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      timeoutRequests: 0,
      connectionCount: 0,
      reconnectionCount: 0,
    };

    // Connection timeout cleanup
    this.connectionTimeouts = new Map();
  }

  /**
   * Start SSH WebSocket server
   * @returns {Promise<void>}
   */
  async start() {
    try {
      const port = this.config.sshPort || 8080;

      // Create HTTP server for WebSocket upgrade
      const server = http.createServer();

      // Create WebSocket server
      this.wss = new WebSocket.Server({
        server,
        path: '/ssh',
        perMessageDeflate: false,
      });

      // Create SSH server
      this.sshServer = new SSHServer({
        hostKeys: [], // We'll handle auth via JWT, not host keys
      }, (client) => {
        this._handleSSHClient(client);
      });

      // Handle WebSocket connections
      this.wss.on('connection', (ws, request) => {
        this._handleWebSocketConnection(ws, request);
      });

      // Start HTTP server
      await new Promise((resolve, reject) => {
        server.listen(port, (err) => {
          if (err) reject(err);
          else resolve();
        });
      });

      this.logger.info('SSHProxy started successfully', {
        port,
        websocketPath: '/ssh',
      });
    } catch (error) {
      this.logger.error('Failed to start SSHProxy', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Stop SSH WebSocket server and cleanup
   * @returns {Promise<void>}
   */
  async stop() {
    // Close all WebSocket connections
    if (this.wss) {
      this.wss.clients.forEach(client => {
        client.close();
      });
      this.wss.close();
    }

    // Close SSH server
    if (this.sshServer) {
      this.sshServer.close();
    }

    // Clear all connections
    this.userConnections.clear();
    this.tunnelRegistry.clear();
    this.wsConnections.clear();

    this.logger.info('SSHProxy stopped');
  }

  /**
   * Handle new WebSocket connection
   * @param {WebSocket} ws - WebSocket connection
   * @param {http.IncomingMessage} request - HTTP request
   */
  _handleWebSocketConnection(ws, request) {
    try {
      // Extract JWT from query parameters
      const url = new URL(request.url, `http://${request.headers.host}`);
      const token = url.searchParams.get('token');
      const userId = url.searchParams.get('userId');

      if (!token || !userId) {
        this.logger.warn('WebSocket connection missing token or userId');
        ws.close(1008, 'Missing authentication');
        return;
      }

      // Validate JWT
      const decoded = this.authService.verifyToken(token);
      if (!decoded || decoded.sub !== userId) {
        this.logger.warn('WebSocket connection with invalid JWT', { userId });
        ws.close(1008, 'Invalid authentication');
        return;
      }

      // Store WebSocket connection
      this.wsConnections.set(ws, { userId, token });

      // Set up WebSocket handlers
      ws.on('message', (data) => {
        this._handleWebSocketMessage(ws, data);
      });

      ws.on('close', () => {
        this._handleWebSocketClose(ws);
      });

      ws.on('error', (error) => {
        this.logger.error('WebSocket error', { error: error.message, userId });
        this._handleWebSocketClose(ws);
      });

      this.logger.info('WebSocket SSH connection established', { userId });

      // Set up SSH connection after WebSocket is established
      this._handleSSHConnection(ws);

    } catch (error) {
      this.logger.error('WebSocket connection error', { error: error.message });
      ws.close(1011, 'Internal error');
    }
  }

  /**
   * Handle WebSocket messages (SSH protocol data)
   * @param {WebSocket} ws - WebSocket connection
   * @param {Buffer} data - Message data
   */
  _handleWebSocketMessage(ws, data) {
    const connection = this.wsConnections.get(ws);
    if (!connection) {
      this.logger.warn('Received WebSocket message for unknown connection');
      return;
    }

    const { userId } = connection;

    // Forward WebSocket data to SSH stream
    if (connection.sshStream) {
      connection.sshStream.write(data);
    } else {
      this.logger.debug('WebSocket message received (no SSH stream yet)', {
        userId,
        length: data.length
      });
    }
  }

  /**
   * Handle WebSocket connection close
   * @param {WebSocket} ws - WebSocket connection
   */
  _handleWebSocketClose(ws) {
    const connection = this.wsConnections.get(ws);
    if (connection) {
      const { userId } = connection;

      // Clean up user connection
      this.userConnections.delete(userId);

      // Clean up tunnel registry
      for (const [tunnelId, connUserId] of this.tunnelRegistry.entries()) {
        if (connUserId === userId) {
          this.tunnelRegistry.delete(tunnelId);
          break;
        }
      }

      this.wsConnections.delete(ws);

      this.logger.info('WebSocket SSH connection closed', { userId });
    }
  }

  /**
   * Handle SSH client connection (from WebSocket)
   * @param {WebSocket} ws - WebSocket connection
   */
  _handleSSHConnection(ws) {
    const connection = this.wsConnections.get(ws);
    if (!connection) return;

    const { userId } = connection;

    // Set up bi-directional data flow between WebSocket and SSH stream
    connection.sshStream = {
      write: (data) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(data);
        }
      }
    };

    // Handle data from WebSocket to SSH
    ws.on('message', (data) => {
      this._handleSSHData(userId, data, connection);
    });

    this.logger.info('SSH connection established for WebSocket client', { userId });
  }

  /**
   * Handle SSH data from WebSocket
   * @param {string} userId - User ID
   * @param {Buffer} data - SSH protocol data
   * @param {Object} connection - Connection object
   */
  _handleSSHData(userId, data, connection) {
    try {
      // Parse SSH protocol and handle forwarding requests
      // This is a simplified implementation - in production you'd use a proper SSH library

      // For now, handle basic port forwarding setup
      const dataStr = data.toString();

      if (dataStr.includes('tcpip-forward')) {
        // Extract port forwarding request
        const portMatch = dataStr.match(/tcpip-forward[^:]*:(\d+)/);
        if (portMatch) {
          const localPort = parseInt(portMatch[1]);
          this._setupPortForwarding(userId, localPort, connection);
        }
      }

      // Forward data through the tunnel (simplified)
      if (connection.forwardStream) {
        connection.forwardStream.write(data);
      }

    } catch (error) {
      this.logger.error('Error handling SSH data', {
        userId,
        error: error.message
      });
    }
  }

  /**
   * Set up port forwarding for SSH tunnel
   * @param {string} userId - User ID
   * @param {number} localPort - Local port to forward
   * @param {Object} connection - Connection object
   */
  _setupPortForwarding(userId, localPort, connection) {
    try {
      // Assign a server port for this tunnel
      const serverPort = this._assignServerPort();

      // Register the tunnel
      const tunnelId = `ssh_tunnel_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      this.userConnections.set(userId, {
        userId,
        tunnelId,
        localPort, // Client's local port (e.g., 11434 for Ollama)
        port: serverPort, // Server's assigned port
        timestamp: new Date(),
        ws: this.wsConnections.keys().find(ws => this.wsConnections.get(ws).userId === userId),
      });

      this.tunnelRegistry.set(tunnelId, userId);
      this.metrics.connectionCount++;

      // Set connection timeout
      this._setConnectionTimeout(userId);

      this.logger.info('SSH reverse tunnel established', {
        userId,
        tunnelId,
        localPort,
        serverPort,
      });

    } catch (error) {
      this.logger.error('Port forwarding setup error', {
        userId,
        localPort,
        error: error.message
      });
    }
  }

  /**
   * Assign a server port for tunnel
   * @returns {number} Assigned port
   */
  _assignServerPort() {
    // Simple port assignment - find next available port
    const basePort = 9000; // Start from 9000
    let port = basePort;

    while (Array.from(this.userConnections.values()).some(conn => conn.port === port)) {
      port++;
    }

    return port;
  }

  /**
   * Set connection timeout for cleanup
   * @param {string} userId - User ID
   */
  _setConnectionTimeout(userId) {
    // Clear existing timeout
    if (this.connectionTimeouts.has(userId)) {
      clearTimeout(this.connectionTimeouts.get(userId));
    }

    // Set new timeout (5 minutes)
    const timeout = setTimeout(() => {
      this.logger.info('Connection timeout, cleaning up', { userId });
      this._cleanupConnection(userId);
    }, 5 * 60 * 1000);

    this.connectionTimeouts.set(userId, timeout);
  }

  /**
   * Clean up connection
   * @param {string} userId - User ID
   */
  _cleanupConnection(userId) {
    const connection = this.userConnections.get(userId);
    if (connection) {
      try {
        if (connection.stream) {
          connection.stream.end();
        }
      } catch (e) {
        // Ignore cleanup errors
      }

      this.userConnections.delete(userId);
      this.metrics.connectionCount--;

      // Clean up tunnel registry
      for (const [tunnelId, connUserId] of this.tunnelRegistry.entries()) {
        if (connUserId === userId) {
          this.tunnelRegistry.delete(tunnelId);
          break;
        }
      }
    }

    // Clear timeout
    if (this.connectionTimeouts.has(userId)) {
      clearTimeout(this.connectionTimeouts.get(userId));
      this.connectionTimeouts.delete(userId);
    }
  }

  /**
   * Register a client connection
   * Called when a client registers via the API
   *
   * @param {string} userId - User ID from JWT
   * @param {string} tunnelId - SSH tunnel identifier
   * @param {number} localPort - Local port on client (typically 11434 for Ollama)
   * @param {number} [serverPort] - Server-assigned port (if provided)
   * @returns {number} Server port assigned to this tunnel
   */
  registerClient(userId, tunnelId, localPort = 11434, serverPort = null) {
    // Clean up old connection if exists
    if (this.userConnections.has(userId)) {
      const oldConnection = this.userConnections.get(userId);
      this.logger.info('User reconnected, cleaning up old connection', {
        userId,
        oldPort: oldConnection.port,
      });
      this.metrics.reconnectionCount++;
    }

    // Assign port if not provided
    const assignedPort = serverPort || this._assignServerPort();

    const connection = {
      userId,
      tunnelId,
      localPort,
      port: assignedPort,
      timestamp: new Date(),
    };

    this.userConnections.set(userId, connection);
    this.tunnelRegistry.set(tunnelId, userId);
    this.metrics.connectionCount++;

    // Set connection timeout (cleanup after 5 minutes of inactivity)
    this._setConnectionTimeout(userId);

    this.logger.info('SSH client registered', {
      userId,
      tunnelId,
      localPort,
      serverPort: assignedPort,
      totalConnections: this.userConnections.size,
    });

    return assignedPort;
  }

  /**
   * Unregister a client connection
   * @param {string} userId - User ID
   */
  unregisterClient(userId) {
    this._cleanupConnection(userId);
    this.logger.info('SSH client unregistered', { userId });
  }

  /**
   * Check if user is connected
   * @param {string} userId - User ID
   * @returns {boolean} True if connected
   */
  isUserConnected(userId) {
    return this.userConnections.has(userId);
  }

  /**
   * Get user connection info
   * @param {string} userId - User ID
   * @returns {Object|null} Connection info or null
   */
  getUserConnection(userId) {
    return this.userConnections.get(userId) || null;
  }

  /**
   * Forward HTTP request through tunnel
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @returns {Promise<Object>} HTTP response
   */
  async forwardRequest(userId, httpRequest) {
    this.metrics.totalRequests++;

    const connection = this.userConnections.get(userId);
    if (!connection) {
      throw new Error(`No tunnel connection found for user ${userId}`);
    }

    try {
      // Create HTTP request data to send through the tunnel
      const requestData = {
        id: httpRequest.id || `req_${Date.now()}`,
        method: httpRequest.method,
        path: httpRequest.path,
        headers: httpRequest.headers || {},
        body: httpRequest.body,
        timestamp: new Date().toISOString(),
      };

      // Serialize the request
      const requestJson = JSON.stringify(requestData);

      // Send request through WebSocket to SSH client
      const ws = connection.ws;
      if (!ws || ws.readyState !== WebSocket.OPEN) {
        throw new Error('WebSocket connection not available');
      }

      // Send the HTTP request through the SSH tunnel
      ws.send(Buffer.from(requestJson, 'utf8'));

      // Wait for response (simplified - in production you'd need proper async handling)
      // For now, simulate a response from Ollama
      this.metrics.successfulRequests++;

      // Simulate Ollama API response
      return {
        status: 200,
        headers: {
          'content-type': 'application/json',
          'access-control-allow-origin': '*',
        },
        body: JSON.stringify({
          message: {
            role: 'assistant',
            content: 'Hello! I am responding through the SSH tunnel. This is a simulated response.',
          },
          done: true,
        }),
      };

    } catch (error) {
      this.metrics.failedRequests++;
      this.logger.error('Request forwarding failed', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get metrics
   * @returns {Object} Metrics object
   */
  getMetrics() {
    return { ...this.metrics };
  }
}
