/**
 * Graceful Close Manager
 * Manages graceful WebSocket connection closure with proper handshake
 * Uses appropriate close codes and waits for acknowledgment
 */

import { WebSocket } from 'ws';

/**
 * WebSocket Close Codes (RFC 6455)
 */
export enum CloseCode {
  NORMAL_CLOSURE = 1000, // Normal closure
  GOING_AWAY = 1001, // Server going away or browser navigating away
  PROTOCOL_ERROR = 1002, // Protocol error
  UNSUPPORTED_DATA = 1003, // Unsupported data type
  RESERVED = 1004, // Reserved
  NO_STATUS_RECEIVED = 1005, // No status code received (internal use only)
  ABNORMAL_CLOSURE = 1006, // Abnormal closure (internal use only)
  INVALID_FRAME_PAYLOAD = 1007, // Invalid frame payload data
  POLICY_VIOLATION = 1008, // Policy violation
  MESSAGE_TOO_BIG = 1009, // Message too big
  MANDATORY_EXTENSION = 1010, // Mandatory extension missing
  INTERNAL_ERROR = 1011, // Internal server error
  SERVICE_RESTART = 1012, // Service restart
  TRY_AGAIN_LATER = 1013, // Try again later
  BAD_GATEWAY = 1014, // Bad gateway
  TLS_HANDSHAKE = 1015, // TLS handshake failure (internal use only)
}

interface CloseOptions {
  code: CloseCode;
  reason: string;
  timeout?: number; // Timeout in ms to wait for close acknowledgment
  force?: boolean; // Force close without waiting for acknowledgment
}

interface CloseMetadata {
  initiatedAt: Date;
  code: CloseCode;
  reason: string;
  acknowledged: boolean;
  completedAt?: Date;
  duration?: number;
}

/**
 * Graceful Close Manager
 * Handles graceful WebSocket connection closure
 */
export class GracefulCloseManager {
  private readonly closingConnections: Map<WebSocket, CloseMetadata> = new Map();
  private readonly defaultTimeout = 5000; // 5 seconds

  /**
   * Close WebSocket connection gracefully
   */
  async closeGracefully(ws: WebSocket, options: Partial<CloseOptions> = {}): Promise<void> {
    const closeOptions: CloseOptions = {
      code: options.code || CloseCode.NORMAL_CLOSURE,
      reason: options.reason || 'Normal closure',
      timeout: options.timeout || this.defaultTimeout,
      force: options.force || false,
    };

    // Check if already closing
    if (this.closingConnections.has(ws)) {
      console.warn('Connection already closing');
      return;
    }

    // Check if already closed
    if (ws.readyState === WebSocket.CLOSED || ws.readyState === WebSocket.CLOSING) {
      console.warn('Connection already closed or closing');
      return;
    }

    // Create close metadata
    const metadata: CloseMetadata = {
      initiatedAt: new Date(),
      code: closeOptions.code,
      reason: closeOptions.reason,
      acknowledged: false,
    };

    this.closingConnections.set(ws, metadata);

    // Log close initiation
    console.log(JSON.stringify({
      type: 'connection_close_initiated',
      code: closeOptions.code,
      reason: closeOptions.reason,
      timestamp: new Date().toISOString(),
    }));

    if (closeOptions.force) {
      // Force close immediately
      ws.terminate();
      this.completeClose(ws, metadata);
      return;
    }

    // Wait for close acknowledgment
    await this.waitForCloseAcknowledgment(ws, metadata, closeOptions);
  }

  /**
   * Wait for close acknowledgment from client
   */
  private async waitForCloseAcknowledgment(
    ws: WebSocket,
    metadata: CloseMetadata,
    options: CloseOptions
  ): Promise<void> {
    return new Promise<void>((resolve) => {
      let timeoutHandle: NodeJS.Timeout | undefined;

      // Set up close event handler
      const closeHandler = () => {
        if (timeoutHandle) {
          clearTimeout(timeoutHandle);
        }
        metadata.acknowledged = true;
        this.completeClose(ws, metadata);
        resolve();
      };

      ws.once('close', closeHandler);

      // Send close frame
      try {
        ws.close(options.code, options.reason);
      } catch (error) {
        console.error('Error sending close frame:', error);
        ws.terminate();
        this.completeClose(ws, metadata);
        resolve();
        return;
      }

      // Set timeout for close acknowledgment
      timeoutHandle = setTimeout(() => {
        ws.removeListener('close', closeHandler);

        console.warn(JSON.stringify({
          type: 'connection_close_timeout',
          code: options.code,
          reason: options.reason,
          timeout: options.timeout,
          timestamp: new Date().toISOString(),
        }));

        // Force close after timeout
        ws.terminate();
        this.completeClose(ws, metadata);
        resolve();
      }, options.timeout);
    });
  }

  /**
   * Complete close operation
   */
  private completeClose(ws: WebSocket, metadata: CloseMetadata): void {
    metadata.completedAt = new Date();
    metadata.duration = metadata.completedAt.getTime() - metadata.initiatedAt.getTime();

    // Log close completion
    console.log(JSON.stringify({
      type: 'connection_close_completed',
      code: metadata.code,
      reason: metadata.reason,
      acknowledged: metadata.acknowledged,
      duration: metadata.duration,
      timestamp: new Date().toISOString(),
    }));

    // Remove from closing connections
    this.closingConnections.delete(ws);
  }

  /**
   * Close connection with normal closure code
   */
  async closeNormal(ws: WebSocket, reason: string = 'Normal closure'): Promise<void> {
    return this.closeGracefully(ws, {
      code: CloseCode.NORMAL_CLOSURE,
      reason,
    });
  }

  /**
   * Close connection due to server going away
   */
  async closeGoingAway(ws: WebSocket, reason: string = 'Server going away'): Promise<void> {
    return this.closeGracefully(ws, {
      code: CloseCode.GOING_AWAY,
      reason,
    });
  }

  /**
   * Close connection due to protocol error
   */
  async closeProtocolError(ws: WebSocket, reason: string = 'Protocol error'): Promise<void> {
    return this.closeGracefully(ws, {
      code: CloseCode.PROTOCOL_ERROR,
      reason,
    });
  }

  /**
   * Close connection due to policy violation
   */
  async closePolicyViolation(ws: WebSocket, reason: string = 'Policy violation'): Promise<void> {
    return this.closeGracefully(ws, {
      code: CloseCode.POLICY_VIOLATION,
      reason,
    });
  }

  /**
   * Close connection due to message too big
   */
  async closeMessageTooBig(ws: WebSocket, reason: string = 'Message too big'): Promise<void> {
    return this.closeGracefully(ws, {
      code: CloseCode.MESSAGE_TOO_BIG,
      reason,
    });
  }

  /**
   * Close connection due to internal error
   */
  async closeInternalError(ws: WebSocket, reason: string = 'Internal error'): Promise<void> {
    return this.closeGracefully(ws, {
      code: CloseCode.INTERNAL_ERROR,
      reason,
    });
  }

  /**
   * Close connection due to service restart
   */
  async closeServiceRestart(ws: WebSocket, reason: string = 'Service restart'): Promise<void> {
    return this.closeGracefully(ws, {
      code: CloseCode.SERVICE_RESTART,
      reason,
    });
  }

  /**
   * Close all connections gracefully
   */
  async closeAll(
    connections: WebSocket[],
    options: Partial<CloseOptions> = {}
  ): Promise<void> {
    const closePromises = connections.map((ws) => this.closeGracefully(ws, options));
    await Promise.all(closePromises);
  }

  /**
   * Check if connection is closing
   */
  isClosing(ws: WebSocket): boolean {
    return this.closingConnections.has(ws);
  }

  /**
   * Get close metadata for connection
   */
  getCloseMetadata(ws: WebSocket): CloseMetadata | undefined {
    return this.closingConnections.get(ws);
  }

  /**
   * Get number of connections currently closing
   */
  getClosingCount(): number {
    return this.closingConnections.size;
  }

  /**
   * Get human-readable close code description
   */
  static getCloseCodeDescription(code: number): string {
    switch (code) {
      case CloseCode.NORMAL_CLOSURE:
        return 'Normal closure';
      case CloseCode.GOING_AWAY:
        return 'Going away';
      case CloseCode.PROTOCOL_ERROR:
        return 'Protocol error';
      case CloseCode.UNSUPPORTED_DATA:
        return 'Unsupported data';
      case CloseCode.NO_STATUS_RECEIVED:
        return 'No status received';
      case CloseCode.ABNORMAL_CLOSURE:
        return 'Abnormal closure';
      case CloseCode.INVALID_FRAME_PAYLOAD:
        return 'Invalid frame payload';
      case CloseCode.POLICY_VIOLATION:
        return 'Policy violation';
      case CloseCode.MESSAGE_TOO_BIG:
        return 'Message too big';
      case CloseCode.MANDATORY_EXTENSION:
        return 'Mandatory extension';
      case CloseCode.INTERNAL_ERROR:
        return 'Internal error';
      case CloseCode.SERVICE_RESTART:
        return 'Service restart';
      case CloseCode.TRY_AGAIN_LATER:
        return 'Try again later';
      case CloseCode.BAD_GATEWAY:
        return 'Bad gateway';
      case CloseCode.TLS_HANDSHAKE:
        return 'TLS handshake failure';
      default:
        return `Unknown code: ${code}`;
    }
  }

  /**
   * Check if close code indicates a normal closure
   */
  static isNormalClosure(code: number): boolean {
    return code === CloseCode.NORMAL_CLOSURE || code === CloseCode.GOING_AWAY;
  }

  /**
   * Check if close code indicates an error
   */
  static isErrorClosure(code: number): boolean {
    return code >= CloseCode.PROTOCOL_ERROR && code !== CloseCode.NORMAL_CLOSURE;
  }

  /**
   * Get appropriate close code for error
   */
  static getCloseCodeForError(error: Error): CloseCode {
    const errorMessage = error.message.toLowerCase();

    if (errorMessage.includes('protocol')) {
      return CloseCode.PROTOCOL_ERROR;
    }

    if (errorMessage.includes('too big') || errorMessage.includes('too large')) {
      return CloseCode.MESSAGE_TOO_BIG;
    }

    if (errorMessage.includes('policy') || errorMessage.includes('violation')) {
      return CloseCode.POLICY_VIOLATION;
    }

    if (errorMessage.includes('unsupported')) {
      return CloseCode.UNSUPPORTED_DATA;
    }

    // Default to internal error
    return CloseCode.INTERNAL_ERROR;
  }
}
