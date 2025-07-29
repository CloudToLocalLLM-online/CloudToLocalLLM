/**
 * @fileoverview Comprehensive test suite for TunnelServer
 * Tests WebSocket functionality, authentication, connection management, and security
 */

import { jest } from '@jest/globals';
import WebSocket from 'ws';
import http from 'http';
import { TunnelServer } from '../../../services/api-backend/tunnel/tunnel-server.js';
import { AuthService } from '../../../services/api-backend/auth/auth-service.js';

// Mock dependencies
jest.mock('../../../services/api-backend/auth/auth-service.js');
jest.mock('../../../services/api-backend/utils/logger.js', () => ({
  TunnelLogger: jest.fn().mockImplementation(() => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
    generateCorrelationId: jest.fn(() => 'test-correlation-id')
  }))
}));

describe('TunnelServer', () => {
  let server;
  let httpServer;
  let tunnelServer;
  let mockAuthService;
  
  beforeEach(async () => {
    // Create HTTP server
    httpServer = http.createServer();
    
    // Mock Auth0 configuration
    const config = {
      AUTH0_DOMAIN: 'test.auth0.com',
      AUTH0_AUDIENCE: 'test-audience',
      maxConnections: 10,
      heartbeatInterval: 1000,
      compressionEnabled: false
    };
    
    // Create tunnel server
    tunnelServer = new TunnelServer(httpServer, config);
    
    // Mock authentication service
    mockAuthService = new AuthService();
    
    // Start server on random port
    await new Promise((resolve) => {
      httpServer.listen(0, resolve);
    });
    
    const port = httpServer.address().port;
    server = `ws://localhost:${port}`;
  });
  
  afterEach(async () => {
    if (tunnelServer) {
      tunnelServer.stop();
    }
    
    if (httpServer) {
      await new Promise((resolve) => {
        httpServer.close(resolve);
      });
    }
  });
  
  describe('Server Initialization', () => {
    test('should start tunnel server successfully', () => {
      expect(() => tunnelServer.start()).not.toThrow();
      expect(tunnelServer.wss).toBeDefined();
    });
    
    test('should stop tunnel server gracefully', () => {
      tunnelServer.start();
      expect(() => tunnelServer.stop()).not.toThrow();
      expect(tunnelServer.wss).toBeNull();
    });
    
    test('should emit started event when server starts', (done) => {
      tunnelServer.on('started', () => {
        done();
      });
      tunnelServer.start();
    });
    
    test('should emit stopped event when server stops', (done) => {
      tunnelServer.start();
      tunnelServer.on('stopped', () => {
        done();
      });
      tunnelServer.stop();
    });
  });
  
  describe('Connection Management', () => {
    beforeEach(() => {
      tunnelServer.start();
      
      // Mock token validation to always succeed
      tunnelServer.validateToken = jest.fn().mockResolvedValue('test-user-id');
      tunnelServer.extractToken = jest.fn().mockReturnValue('valid-token');
    });
    
    test('should accept valid WebSocket connections', (done) => {
      const ws = new WebSocket(`${server}/ws/tunnel`, {
        headers: {
          'Authorization': 'Bearer valid-token'
        }
      });
      
      ws.on('open', () => {
        expect(tunnelServer.connections.size).toBe(1);
        ws.close();
        done();
      });
      
      ws.on('error', done);
    });
    
    test('should reject connections without valid token', (done) => {
      // Mock token validation to fail
      tunnelServer.validateToken = jest.fn().mockResolvedValue(null);
      
      const ws = new WebSocket(`${server}/ws/tunnel`);
      
      ws.on('error', (error) => {
        expect(error.message).toContain('Unexpected server response');
        done();
      });
      
      ws.on('open', () => {
        done(new Error('Connection should have been rejected'));
      });
    });
    
    test('should handle connection limit', (done) => {
      // Set low connection limit
      tunnelServer.config.maxConnections = 1;
      
      const ws1 = new WebSocket(`${server}/ws/tunnel`, {
        headers: { 'Authorization': 'Bearer valid-token' }
      });
      
      ws1.on('open', () => {
        // Try to open second connection
        const ws2 = new WebSocket(`${server}/ws/tunnel`, {
          headers: { 'Authorization': 'Bearer valid-token' }
        });
        
        ws2.on('error', (error) => {
          expect(error.message).toContain('Unexpected server response');
          ws1.close();
          done();
        });
      });
    });
    
    test('should track connection metrics', (done) => {
      const ws = new WebSocket(`${server}/ws/tunnel`, {
        headers: { 'Authorization': 'Bearer valid-token' }
      });
      
      ws.on('open', () => {
        const stats = tunnelServer.getStats();
        expect(stats.activeConnections).toBe(1);
        expect(stats.maxConnections).toBe(10);
        ws.close();
        done();
      });
    });
  });
  
  describe('Message Handling', () => {
    let ws;
    
    beforeEach((done) => {
      tunnelServer.start();
      tunnelServer.validateToken = jest.fn().mockResolvedValue('test-user-id');
      tunnelServer.extractToken = jest.fn().mockReturnValue('valid-token');
      
      ws = new WebSocket(`${server}/ws/tunnel`, {
        headers: { 'Authorization': 'Bearer valid-token' }
      });
      
      ws.on('open', () => done());
    });
    
    afterEach(() => {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.close();
      }
    });
    
    test('should handle HTTP response messages', (done) => {
      const responseMessage = {
        type: 'http_response',
        id: 'test-request-id',
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"success": true}'
      };
      
      // Set up pending request
      tunnelServer.pendingRequests.set('test-request-id', {
        resolve: (response) => {
          expect(response.status).toBe(200);
          expect(response.body).toBe('{"success": true}');
          done();
        },
        reject: done,
        timeout: setTimeout(() => done(new Error('Timeout')), 1000)
      });
      
      ws.send(JSON.stringify(responseMessage));
    });
    
    test('should handle error messages', (done) => {
      const errorMessage = {
        type: 'error',
        id: 'test-request-id',
        error: 'Request failed'
      };
      
      // Set up pending request
      tunnelServer.pendingRequests.set('test-request-id', {
        resolve: () => done(new Error('Should not resolve')),
        reject: (error) => {
          expect(error.message).toBe('Request failed');
          done();
        },
        timeout: setTimeout(() => done(new Error('Timeout')), 1000)
      });
      
      ws.send(JSON.stringify(errorMessage));
    });
    
    test('should handle malformed messages gracefully', (done) => {
      ws.on('message', (data) => {
        const message = JSON.parse(data);
        if (message.type === 'error') {
          expect(message.error).toBe('Message processing failed');
          done();
        }
      });
      
      ws.send('invalid json');
    });
  });
  
  describe('Security Features', () => {
    beforeEach(() => {
      tunnelServer.start();
    });
    
    test('should validate JWT tokens', async () => {
      const mockToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2lkIn0.eyJzdWIiOiJ0ZXN0LXVzZXIiLCJhdWQiOiJ0ZXN0LWF1ZGllbmNlIiwiaXNzIjoiaHR0cHM6Ly90ZXN0LmF1dGgwLmNvbS8iLCJleHAiOjk5OTk5OTk5OTl9.test-signature';
      
      // Mock JWKS client
      tunnelServer.getSigningKey = jest.fn().mockResolvedValue('test-public-key');
      
      // Mock JWT verification
      const jwt = await import('jsonwebtoken');
      jwt.verify = jest.fn().mockReturnValue({
        sub: 'test-user',
        aud: 'test-audience',
        iss: 'https://test.auth0.com/'
      });
      
      const userId = await tunnelServer.validateToken(mockToken);
      expect(userId).toBe('test-user');
    });
    
    test('should reject invalid tokens', async () => {
      const invalidToken = 'invalid.token.here';
      
      const userId = await tunnelServer.validateToken(invalidToken);
      expect(userId).toBeNull();
    });
    
    test('should enforce origin validation', () => {
      const validInfo = {
        origin: 'https://app.cloudtolocalllm.online',
        req: { socket: { remoteAddress: '127.0.0.1' } }
      };
      
      const invalidInfo = {
        origin: 'https://malicious-site.com',
        req: { socket: { remoteAddress: '127.0.0.1' } }
      };
      
      // Mock security validator
      tunnelServer.securityValidator = jest.fn()
        .mockReturnValueOnce(true)
        .mockReturnValueOnce(false);
      
      tunnelServer.extractToken = jest.fn().mockReturnValue('valid-token');
      tunnelServer.validateToken = jest.fn().mockResolvedValue('test-user');
      
      expect(tunnelServer.verifyClient(validInfo)).resolves.toBe(true);
      expect(tunnelServer.verifyClient(invalidInfo)).resolves.toBe(false);
    });
  });
  
  describe('Performance and Reliability', () => {
    beforeEach(() => {
      tunnelServer.start();
      tunnelServer.validateToken = jest.fn().mockResolvedValue('test-user-id');
      tunnelServer.extractToken = jest.fn().mockReturnValue('valid-token');
    });
    
    test('should handle heartbeat mechanism', (done) => {
      const ws = new WebSocket(`${server}/ws/tunnel`, {
        headers: { 'Authorization': 'Bearer valid-token' }
      });
      
      ws.on('open', () => {
        // Mock heartbeat interval to be very short for testing
        tunnelServer.config.heartbeatInterval = 100;
        tunnelServer.startHeartbeat();
        
        ws.on('ping', () => {
          ws.pong();
          done();
        });
      });
    });
    
    test('should handle connection timeouts', (done) => {
      const ws = new WebSocket(`${server}/ws/tunnel`, {
        headers: { 'Authorization': 'Bearer valid-token' }
      });
      
      ws.on('open', () => {
        // Don't respond to pings to simulate timeout
        ws.on('ping', () => {
          // Don't send pong
        });
        
        ws.on('close', (code) => {
          expect(code).toBe(1001); // Heartbeat timeout
          done();
        });
        
        // Trigger heartbeat check
        tunnelServer.config.heartbeatInterval = 50;
        tunnelServer.startHeartbeat();
      });
    });
    
    test('should provide server statistics', () => {
      const stats = tunnelServer.getStats();
      
      expect(stats).toHaveProperty('activeConnections');
      expect(stats).toHaveProperty('maxConnections');
      expect(stats).toHaveProperty('pendingRequests');
      expect(stats).toHaveProperty('uptime');
      expect(stats).toHaveProperty('memory');
      expect(stats).toHaveProperty('metrics');
    });
  });
});
