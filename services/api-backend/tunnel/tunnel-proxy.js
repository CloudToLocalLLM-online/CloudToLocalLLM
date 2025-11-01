/**
 * @fileoverview Manages WebSocket connections from desktop clients and proxies requests.
 */

import { WebSocket } from 'ws';
import { v4 as uuidv4 } from 'uuid';
import winston from 'winston';
import { MessageProtocol, MESSAGE_TYPES } from './message-protocol.js';
import { TunnelLogger, ERROR_CODES } from '../utils/logger.js';

const REQUEST_TIMEOUT = 30000; // 30 seconds
const PING_INTERVAL = 30000; // 30 seconds
const PONG_TIMEOUT = 10000; // 10 seconds

/**
 * @typedef {Object} TunnelConnection
 * @property {string} userId
 * @property {WebSocket} websocket
 * @property {boolean} isConnected
 * @property {Date} lastPing
 * @property {Map<string, PendingRequest>} pendingRequests
 */

/**
 * @typedef {Object} PendingRequest
 * @property {string} id
 * @property {Date} timestamp
 * @property {NodeJS.Timeout} timeout
 * @property {Function} resolve
 * @property {Function} reject
 */

export class TunnelProxy {
  /**
   * @param {winston.Logger} [logger]
   */
  constructor(logger = winston.createLogger()) {
    this.logger = logger instanceof TunnelLogger ? logger : new TunnelLogger('tunnel-proxy');
    /** @type {Map<string, TunnelConnection>} */
    this.connections = new Map(); // connectionId -> TunnelConnection
    /** @type {Map<string, TunnelConnection>} */
    this.userConnections = new Map(); // userId -> TunnelConnection

    this.pingIntervals = new Map();
    this.pongTimeouts = new Map();

    this.metrics = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      timeoutRequests: 0,
      connectionCount: 0,
      reconnectionCount: 0,
    };
  }

  /**
   * @param {WebSocket} ws
   * @param {string} userId
   * @returns {string} Connection ID
   */
  handleConnection(ws, userId) {
    const connectionId = uuidv4();

    // If a user reconnects, clean up their old connection
    if (this.userConnections.has(userId)) {
      this.logger.info(`User ${userId} reconnected, cleaning up old connection.`);
      const oldConnection = this.userConnections.get(userId);
      // Find connectionId for oldConnection
      for (const [id, conn] of this.connections.entries()) {
        if (conn === oldConnection) {
          this.handleDisconnection(id);
          break;
        }
      }
      this.metrics.reconnectionCount++;
    }

    const connection = {
      userId,
      websocket: ws,
      isConnected: true,
      lastPing: new Date(),
      pendingRequests: new Map(),
    };

    this.connections.set(connectionId, connection);
    this.userConnections.set(userId, connection);
    this.metrics.connectionCount++;
    this.logger.info(`New connection: ${connectionId} for user: ${userId}. Total connections: ${this.connections.size}`);

    ws.on('message', (data) => this.handleMessage(connectionId, data));
    ws.on('close', () => this.handleDisconnection(connectionId));
    ws.on('error', (error) => {
      this.logger.error(`WebSocket error on connection ${connectionId}: ${error.message}`);
      this.handleDisconnection(connectionId);
    });

    this.startPingInterval(connectionId);
    return connectionId;
  }

  /**
   * @param {string} connectionId
   */
  handleDisconnection(connectionId) {
    const connection = this.connections.get(connectionId);
    if (!connection) return;

    this.logger.info(`Connection disconnected: ${connectionId}`);
    connection.isConnected = false;
    this.stopPingInterval(connectionId);

    // Reject all pending requests
    for (const [requestId, pendingRequest] of connection.pendingRequests.entries()) {
      clearTimeout(pendingRequest.timeout);
      const error = new Error('Connection closed');
      error.code = ERROR_CODES.CONNECTION_LOST;
      pendingRequest.reject(error);
      this.metrics.failedRequests++;
      this.logger.warn(`Request ${requestId} failed due to disconnection.`);
    }

    this.connections.delete(connectionId);
    if (this.userConnections.get(connection.userId) === connection) {
      this.userConnections.delete(connection.userId);
    }
  }

  /**
   * @param {string} connectionId
   * @param {Buffer} data
   */
  handleMessage(connectionId, data) {
    const connection = this.connections.get(connectionId);
    if (!connection) return;

    try {
      const message = MessageProtocol.deserialize(data.toString());
      switch (message.type) {
        case MESSAGE_TYPES.HTTP_RESPONSE:
          this.handleHttpResponse(connection, message);
          break;
        case MESSAGE_TYPES.PONG:
          this.handlePong(connectionId);
          break;
        case MESSAGE_TYPES.ERROR:
          this.handleError(connection, message);
          break;
        default:
          this.logger.warn(`Unknown message type: ${message.type}`);
      }
    } catch (error) {
      this.logger.error(`Failed to handle message from ${connectionId}: ${error.message}`);
    }
  }

  /**
   * @param {TunnelConnection} connection
   * @param {any} message
   */
  handleHttpResponse(connection, message) {
    const pendingRequest = connection.pendingRequests.get(message.id);
    if (!pendingRequest) {
      this.logger.warn(`Received response for unknown request ID: ${message.id}`);
      return;
    }

    clearTimeout(pendingRequest.timeout);
    connection.pendingRequests.delete(message.id);

    try {
      const httpResponse = MessageProtocol.extractHttpResponse(message);
      pendingRequest.resolve(httpResponse);
      this.metrics.successfulRequests++;
    } catch (error) {
      this.metrics.failedRequests++;
      pendingRequest.reject(new Error(`Invalid response format: ${error.message}`));
    }
  }

  /**
   * @param {string} connectionId
   */
  handlePong(connectionId) {
    const connection = this.connections.get(connectionId);
    if (connection) {
      connection.lastPing = new Date();
      const pongTimeout = this.pongTimeouts.get(connectionId);
      if (pongTimeout) {
        clearTimeout(pongTimeout);
        this.pongTimeouts.delete(connectionId);
      }
    }
  }

  /**
   * @param {TunnelConnection} connection
   * @param {any} message
   */
  handleError(connection, message) {
    const pendingRequest = connection.pendingRequests.get(message.id);
    if (!pendingRequest) {
      this.logger.warn(`Received error for unknown request ID: ${message.id}`);
      return;
    }

    clearTimeout(pendingRequest.timeout);
    connection.pendingRequests.delete(message.id);
    this.metrics.failedRequests++;

    const error = new Error(message.error || 'An unknown error occurred in the desktop client.');
    error.code = message.code;
    pendingRequest.reject(error);
  }

  /**
   * @param {string} userId
   * @param {object} httpRequest
   * @returns {Promise<object>}
   */
  async forwardRequest(userId, httpRequest) {
    const connection = this.userConnections.get(userId);
    if (!connection || !connection.isConnected || connection.websocket.readyState !== WebSocket.OPEN) {
      const error = new Error('Desktop client not connected');
      error.code = ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED;
      throw error;
    }

    this.metrics.totalRequests++;
    const requestMessage = MessageProtocol.createRequestMessage(httpRequest);

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        connection.pendingRequests.delete(requestMessage.id);
        this.metrics.timeoutRequests++;
        this.metrics.failedRequests++;
        const error = new Error('Request timed out');
        error.code = ERROR_CODES.REQUEST_TIMEOUT;
        reject(error);
      }, REQUEST_TIMEOUT);

      connection.pendingRequests.set(requestMessage.id, {
        id: requestMessage.id,
        timestamp: new Date(),
        timeout,
        resolve,
        reject,
      });

      try {
        const serializedMessage = MessageProtocol.serialize(requestMessage);
        connection.websocket.send(serializedMessage);
      } catch (error) {
        clearTimeout(timeout);
        connection.pendingRequests.delete(requestMessage.id);
        this.metrics.failedRequests++;
        this.logger.error(`Failed to send request ${requestMessage.id} to user ${userId}: ${error.message}`);
        const sendError = new Error('Failed to send request to desktop client');
        sendError.code = ERROR_CODES.WEBSOCKET_SEND_FAILED;
        reject(sendError);
      }
    });
  }

  /**
   * @param {string} userId
   * @returns {boolean}
   */
  isUserConnected(userId) {
    const connection = this.userConnections.get(userId);
    return !!connection && connection.isConnected && connection.websocket.readyState === WebSocket.OPEN;
  }

  /**
   * @param {string} userId
   * @returns {object}
   */
  getUserConnectionStatus(userId) {
    const connection = this.userConnections.get(userId);
    if (!connection) {
      return { connected: false, pendingRequests: 0, lastPing: null };
    }
    return {
      connected: connection.isConnected,
      pendingRequests: connection.pendingRequests.size,
      lastPing: connection.lastPing,
    };
  }

  /**
   * @returns {object}
   */
  getStats() {
    const totalPendingRequests = Array.from(this.connections.values())
      .reduce((sum, conn) => sum + conn.pendingRequests.size, 0);

    return {
      connections: {
        total: this.connections.size,
        connectedUsers: this.userConnections.size,
      },
      requests: {
        total: this.metrics.totalRequests,
        successful: this.metrics.successfulRequests,
        failed: this.metrics.failedRequests,
        timeout: this.metrics.timeoutRequests,
        pending: totalPendingRequests,
      },
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * @returns {object}
   */
  getHealthStatus() {
    // The system is healthy if the process is running.
    // In a real-world scenario, this might check dependencies like Redis or a DB.
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      ...this.getStats(),
    };
  }

  /**
   * @param {string} connectionId
   */
  startPingInterval(connectionId) {
    this.stopPingInterval(connectionId); // Ensure no duplicate intervals
    const interval = setInterval(() => {
      const connection = this.connections.get(connectionId);
      if (!connection || connection.websocket.readyState !== WebSocket.OPEN) {
        this.handleDisconnection(connectionId);
        return;
      }

      try {
        const pingMessage = MessageProtocol.createPingMessage();
        connection.websocket.send(MessageProtocol.serialize(pingMessage));

        const pongTimeout = setTimeout(() => {
          this.logger.warn(`Pong timeout for connection ${connectionId}. Disconnecting.`);
          this.handleDisconnection(connectionId);
        }, PONG_TIMEOUT);
        this.pongTimeouts.set(connectionId, pongTimeout);

      } catch (error) {
        this.logger.error(`Failed to send ping to ${connectionId}: ${error.message}`);
        this.handleDisconnection(connectionId);
      }
    }, PING_INTERVAL);
    this.pingIntervals.set(connectionId, interval);
  }

  /**
   * @param {string} connectionId
   */
  stopPingInterval(connectionId) {
    const interval = this.pingIntervals.get(connectionId);
    if (interval) {
      clearInterval(interval);
      this.pingIntervals.delete(connectionId);
    }
    const pongTimeout = this.pongTimeouts.get(connectionId);
    if (pongTimeout) {
      clearTimeout(pongTimeout);
      this.pongTimeouts.delete(connectionId);
    }
  }

  cleanup() {
    for (const interval of this.pingIntervals.values()) {
      clearInterval(interval);
    }
    this.pingIntervals.clear();
    for (const timeout of this.pongTimeouts.values()) {
      clearTimeout(timeout);
    }
    this.pongTimeouts.clear();
    for (const connectionId of this.connections.keys()) {
      this.handleDisconnection(connectionId);
    }
    this.connections.clear();
    this.userConnections.clear();
    this.logger.info('TunnelProxy cleaned up.');
  }
}
