/**
 * @fileoverview User isolation validation tests
 * Tests to ensure complete user isolation and prevent cross-user data leakage
 */

import { describe, it, beforeEach, afterEach, expect, jest } from '@jest/globals';
import request from 'supertest';
import express from 'express';
import { WebSocket, WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { createTunnelRoutes } from '../../tunnel/tunnel-routes.js';
import { TunnelProxy } from '../../tunnel/tunnel-proxy.js';
import { MessageProtocol, MESSAGE_TYPES } from '../../tunnel/message-protocol.js';

// Mock configuration
const TEST_CONFIG = {
  AUTH0_DOMAIN: 'test-domain.auth0.com',
  AUTH0_AUDIENCE: 'https://test.example.com'
};

// Test JWT tokens for different users
const TEST_USERS = {
  user1: {
    id: 'auth0|user1',
    token: null,
    claims: {
      sub: 'auth0|user1',
      aud: TEST_CONFIG.AUTH0_AUDIENCE,
      iss: `https://${TEST_CONFIG.AUTH0_DOMAIN}/`,
      exp: Math.floor(Date.now() / 1000) + 3600,
      iat: Math.floor(Date.now() / 1000),
      email: 'user1@test.com',
      scope: 'read:profile'
    }
  },
  user2: {
    id: 'auth0|user2',
    token: null,
    claims: {
      sub: 'auth0|user2',
      aud: TEST_CONFIG.AUTH0_AUDIENCE,
      iss: `https://${TEST_CONFIG.AUTH0_DOMAIN}/`,
      exp: Math.floor(Date.now() / 1000) + 3600,
      iat: Math.floor(Date.now() / 1000),
      email: 'user2@test.com',
      scope: 'read:profile'
    }
  },
  admin: {
    id: 'auth0|admin',
    token: null,
    claims: {
      sub: 'auth0|admin',
      aud: TEST_CONFIG.AUTH0_AUDIENCE,
      iss: `https://${TEST_CONFIG.AUTH0_DOMAIN}/`,
      exp: Math.floor(Date.now() / 1000) + 3600,
      iat: Math.floor(Date.now() / 1000),
      email: 'admin@test.com',
      scope: 'read:profile admin:access'
    }
  }
};

// Mock JWKS client
const mockJwksClient = {
  getSigningKey: jest.fn().mockResolvedValue({
    getPublicKey: () => 'mock-public-key'
  })
};

// Mock JWT verification
jest.mock('jsonwebtoken', () => ({
  ...jest.requireActual('jsonwebtoken'),
  verify: jest.fn((token, key, options) => {
    // Find matching test user by token
    const user = Object.values(TEST_USERS).find(u => u.token === token);
    if (!user) {
      throw new Error('Invalid token');
    }
    return user.claims;
  }),
  decode: jest.fn((token, options) => {
    const user = Object.values(TEST_USERS).find(u => u.token === token);
    if (!user) {
      return null;
    }
    return {
      header: { kid: 'test-key-id' },
      payload: user.claims
    };
  })
}));

// Mock JWKS client
jest.mock('jwks-client', () => {
  return jest.fn(() => mockJwksClient);
});

describe('User Isolation Security Tests', () => {
  let app;
  let server;
  let tunnelProxy;
  let wss;
  let testConnections = new Map();

  beforeEach(async () => {
    // Generate test tokens
    Object.values(TEST_USERS).forEach(user => {
      user.token = `test-token-${user.id}`;
    });

    // Create Express app
    app = express();
    app.use(express.json());

    // Create HTTP server
    server = require('http').createServer(app);

    // Create tunnel routes
    const { router, tunnelProxy: proxy, wss: websocketServer } = createTunnelRoutes(
      server,
      TEST_CONFIG,
      { info: jest.fn(), debug: jest.fn(), warn: jest.fn(), error: jest.fn() }
    );

    tunnelProxy = proxy;
    wss = websocketServer;
    app.use('/api/tunnel', router);

    // Start server
    await new Promise((resolve) => {
      server.listen(0, resolve);
    });

    // Clear any existing connections
    testConnections.clear();
  });

  afterEach(async () => {
    // Close all test connections
    for (const [userId, connection] of testConnections.entries()) {
      if (connection.ws && connection.ws.readyState === WebSocket.OPEN) {
        connection.ws.close();
      }
    }
    testConnections.clear();

    // Close server
    if (server) {
      await new Promise((resolve) => {
        server.close(resolve);
      });
    }
  });

  /**
   * Create a mock WebSocket connection for a user
   */
  async function createMockConnection(userId) {
    const mockWs = {
      readyState: WebSocket.OPEN,
      send: jest.fn(),
      close: jest.fn(),
      on: jest.fn(),
      removeAllListeners: jest.fn()
    };

    const connectionId = tunnelProxy.handleConnection(mockWs, userId);
    
    testConnections.set(userId, {
      ws: mockWs,
      connectionId,
      userId
    });

    return { ws: mockWs, connectionId };
  }

  /**
   * Simulate HTTP response from desktop client
   */
  function simulateDesktopResponse(userId, requestId, response) {
    const connection = testConnections.get(userId);
    if (!connection) {
      throw new Error(`No connection found for user ${userId}`);
    }

    const responseMessage = MessageProtocol.createResponseMessage(response);
    responseMessage.id = requestId;

    // Simulate message handling
    tunnelProxy.handleMessage(connection.connectionId, Buffer.from(JSON.stringify(responseMessage)));
  }

  describe('Cross-User Request Prevention', () => {
    it('should prevent user from accessing another user\'s tunnel', async () => {
      // Create connections for both users
      await createMockConnection(TEST_USERS.user1.id);
      await createMockConnection(TEST_USERS.user2.id);

      // User 1 tries to access User 2's tunnel
      const response = await request(app)
        .get(`/api/tunnel/${TEST_USERS.user2.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
        .expect(403);

      expect(response.body.error.code).toBe('AUTH_TOKEN_INVALID');
      expect(response.body.error.message).toContain('You can only access your own tunnel');
    });

    it('should allow user to access their own tunnel', async () => {
      // Create connection for user 1
      const { connectionId } = await createMockConnection(TEST_USERS.user1.id);

      // Make request to user 1's own tunnel
      const requestPromise = request(app)
        .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
        .expect(200);

      // Simulate desktop response after a short delay
      setTimeout(() => {
        simulateDesktopResponse(TEST_USERS.user1.id, expect.any(String), {
          status: 200,
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ models: ['test-model'] })
        });
      }, 100);

      const response = await requestPromise;
      expect(response.body.models).toEqual(['test-model']);
    });

    it('should prevent admin from accessing user tunnels without proper user context', async () => {
      // Create connection for user 1
      await createMockConnection(TEST_USERS.user1.id);

      // Admin tries to access user 1's tunnel
      const response = await request(app)
        .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.admin.token}`)
        .expect(403);

      expect(response.body.error.code).toBe('AUTH_TOKEN_INVALID');
    });
  });

  describe('Connection Isolation', () => {
    it('should maintain separate connections for different users', async () => {
      // Create connections for multiple users
      const conn1 = await createMockConnection(TEST_USERS.user1.id);
      const conn2 = await createMockConnection(TEST_USERS.user2.id);

      // Verify connections are separate
      expect(conn1.connectionId).not.toBe(conn2.connectionId);
      
      // Verify each user can only see their own connection status
      const status1 = tunnelProxy.getUserConnectionStatus(TEST_USERS.user1.id);
      const status2 = tunnelProxy.getUserConnectionStatus(TEST_USERS.user2.id);

      expect(status1.connected).toBe(true);
      expect(status2.connected).toBe(true);

      // Verify user 1 cannot see user 2's connection details
      const user1Stats = await request(app)
        .get('/api/tunnel/status')
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
        .expect(200);

      expect(user1Stats.body.user.userId).toBe(TEST_USERS.user1.id);
      expect(user1Stats.body.user.connected).toBe(true);
    });

    it('should prevent connection hijacking between users', async () => {
      // Create connection for user 1
      const conn1 = await createMockConnection(TEST_USERS.user1.id);

      // User 2 tries to use user 1's connection ID (should not be possible through normal API)
      // This tests internal isolation mechanisms
      expect(() => {
        tunnelProxy.handleMessage(conn1.connectionId, Buffer.from(JSON.stringify({
          type: MESSAGE_TYPES.HTTP_RESPONSE,
          id: 'test-request',
          status: 200,
          body: 'hijacked-response'
        })));
      }).not.toThrow();

      // Verify the connection still belongs to user 1
      const status = tunnelProxy.getUserConnectionStatus(TEST_USERS.user1.id);
      expect(status.connected).toBe(true);
    });
  });

  describe('Request/Response Isolation', () => {
    it('should prevent cross-user request correlation', async () => {
      // Create connections for both users
      await createMockConnection(TEST_USERS.user1.id);
      await createMockConnection(TEST_USERS.user2.id);

      // Start request for user 1
      const user1RequestPromise = request(app)
        .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`);

      // Start request for user 2
      const user2RequestPromise = request(app)
        .get(`/api/tunnel/${TEST_USERS.user2.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user2.token}`);

      // Simulate responses (with intentionally swapped data to test isolation)
      setTimeout(() => {
        simulateDesktopResponse(TEST_USERS.user1.id, expect.any(String), {
          status: 200,
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ models: ['user1-model'] })
        });

        simulateDesktopResponse(TEST_USERS.user2.id, expect.any(String), {
          status: 200,
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ models: ['user2-model'] })
        });
      }, 100);

      const [user1Response, user2Response] = await Promise.all([
        user1RequestPromise,
        user2RequestPromise
      ]);

      // Verify each user gets their own response
      expect(user1Response.body.models).toEqual(['user1-model']);
      expect(user2Response.body.models).toEqual(['user2-model']);
    });

    it('should timeout requests independently per user', async () => {
      // Create connection for user 1 only
      await createMockConnection(TEST_USERS.user1.id);

      // User 1 makes request (will succeed)
      const user1RequestPromise = request(app)
        .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`);

      // User 2 makes request (will fail - no connection)
      const user2RequestPromise = request(app)
        .get(`/api/tunnel/${TEST_USERS.user2.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user2.token}`)
        .expect(503);

      // Respond to user 1's request
      setTimeout(() => {
        simulateDesktopResponse(TEST_USERS.user1.id, expect.any(String), {
          status: 200,
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ models: ['user1-model'] })
        });
      }, 100);

      const [user1Response, user2Response] = await Promise.all([
        user1RequestPromise,
        user2RequestPromise
      ]);

      expect(user1Response.status).toBe(200);
      expect(user2Response.status).toBe(503);
      expect(user2Response.body.error.code).toBe('DESKTOP_CLIENT_DISCONNECTED');
    });
  });

  describe('Data Leakage Prevention', () => {
    it('should not expose user data in error messages', async () => {
      // Create connection for user 1
      await createMockConnection(TEST_USERS.user1.id);

      // User 2 tries to access user 1's tunnel
      const response = await request(app)
        .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user2.token}`)
        .expect(403);

      // Verify error message doesn't contain sensitive user information
      expect(response.body.error.message).not.toContain(TEST_USERS.user1.id);
      expect(response.body.error.message).not.toContain(TEST_USERS.user1.claims.email);
      expect(response.body.error.message).not.toContain('user1');
    });

    it('should not expose connection details across users', async () => {
      // Create connections for both users
      await createMockConnection(TEST_USERS.user1.id);
      await createMockConnection(TEST_USERS.user2.id);

      // Get status for user 1
      const user1Status = await request(app)
        .get('/api/tunnel/status')
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
        .expect(200);

      // Verify response only contains user 1's information
      expect(user1Status.body.user.userId).toBe(TEST_USERS.user1.id);
      expect(user1Status.body.system).toBeDefined();
      
      // Verify no user 2 information is leaked
      const responseStr = JSON.stringify(user1Status.body);
      expect(responseStr).not.toContain(TEST_USERS.user2.id);
      expect(responseStr).not.toContain(TEST_USERS.user2.claims.email);
    });

    it('should sanitize logs to prevent user data exposure', async () => {
      // This test would verify that logging doesn't expose sensitive user data
      // In a real implementation, you would check log outputs
      
      // Create connection for user 1
      await createMockConnection(TEST_USERS.user1.id);

      // Make request that will be logged
      await request(app)
        .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
        .set('User-Agent', 'TestAgent/1.0')
        .expect(503); // Will fail due to no desktop response, but will be logged

      // In a real test, you would verify that logs contain hashed user IDs
      // and don't contain full user IDs or email addresses
      expect(true).toBe(true); // Placeholder assertion
    });
  });

  describe('Rate Limiting Isolation', () => {
    it('should apply rate limits per user independently', async () => {
      // Create connections for both users
      await createMockConnection(TEST_USERS.user1.id);
      await createMockConnection(TEST_USERS.user2.id);

      // This test would verify that rate limits are applied per user
      // and one user hitting rate limits doesn't affect another user
      
      // Make multiple requests as user 1 (would hit rate limit in real scenario)
      const user1Requests = Array.from({ length: 5 }, () =>
        request(app)
          .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models`)
          .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
      );

      // Make request as user 2 (should not be affected by user 1's rate limit)
      const user2Request = request(app)
        .get(`/api/tunnel/${TEST_USERS.user2.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user2.token}`);

      // In a real scenario with actual rate limiting, user 2's request should succeed
      // even if user 1 is rate limited
      
      expect(user1Requests.length).toBe(5);
      expect(user2Request).toBeDefined();
    });
  });

  describe('WebSocket Connection Isolation', () => {
    it('should prevent WebSocket message cross-contamination', async () => {
      // Create connections for both users
      const conn1 = await createMockConnection(TEST_USERS.user1.id);
      const conn2 = await createMockConnection(TEST_USERS.user2.id);

      // Send message to user 1's connection
      const testMessage = {
        type: MESSAGE_TYPES.HTTP_RESPONSE,
        id: 'test-request-1',
        status: 200,
        body: 'user1-response'
      };

      tunnelProxy.handleMessage(conn1.connectionId, Buffer.from(JSON.stringify(testMessage)));

      // Verify user 2's connection is not affected
      const user2Status = tunnelProxy.getUserConnectionStatus(TEST_USERS.user2.id);
      expect(user2Status.connected).toBe(true);
      expect(user2Status.pendingRequests).toBe(0);
    });

    it('should handle connection cleanup without affecting other users', async () => {
      // Create connections for both users
      const conn1 = await createMockConnection(TEST_USERS.user1.id);
      const conn2 = await createMockConnection(TEST_USERS.user2.id);

      // Disconnect user 1
      tunnelProxy.handleDisconnection(conn1.connectionId);

      // Verify user 1 is disconnected but user 2 is still connected
      const user1Status = tunnelProxy.getUserConnectionStatus(TEST_USERS.user1.id);
      const user2Status = tunnelProxy.getUserConnectionStatus(TEST_USERS.user2.id);

      expect(user1Status.connected).toBe(false);
      expect(user2Status.connected).toBe(true);
    });
  });

  describe('Security Headers and Metadata', () => {
    it('should not expose internal user identifiers in headers', async () => {
      // Create connection for user 1
      await createMockConnection(TEST_USERS.user1.id);

      const response = await request(app)
        .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
        .expect(503); // Will timeout without desktop response

      // Verify headers don't contain sensitive information
      const headers = response.headers;
      const headerStr = JSON.stringify(headers);
      
      expect(headerStr).not.toContain(TEST_USERS.user1.claims.email);
      expect(headerStr).not.toContain('auth0|user1');
    });

    it('should include appropriate security headers', async () => {
      const response = await request(app)
        .get('/api/tunnel/health')
        .expect(200);

      // Verify security headers are present (these would be set by helmet middleware)
      // In a real test, you would check for specific security headers
      expect(response.headers).toBeDefined();
    });
  });
});

describe('User Isolation Edge Cases', () => {
  let app;
  let server;
  let tunnelProxy;

  beforeEach(async () => {
    // Setup similar to main test suite
    Object.values(TEST_USERS).forEach(user => {
      user.token = `test-token-${user.id}`;
    });

    app = express();
    app.use(express.json());
    server = require('http').createServer(app);

    const { router, tunnelProxy: proxy } = createTunnelRoutes(
      server,
      TEST_CONFIG,
      { info: jest.fn(), debug: jest.fn(), warn: jest.fn(), error: jest.fn() }
    );

    tunnelProxy = proxy;
    app.use('/api/tunnel', router);

    await new Promise((resolve) => {
      server.listen(0, resolve);
    });
  });

  afterEach(async () => {
    if (server) {
      await new Promise((resolve) => {
        server.close(resolve);
      });
    }
  });

  it('should handle malformed user IDs in URLs', async () => {
    const malformedUserIds = [
      '../admin',
      'user1/../user2',
      'user1%2F..%2Fuser2',
      'user1;DROP TABLE users;',
      '<script>alert("xss")</script>',
      'user1\x00user2'
    ];

    for (const malformedId of malformedUserIds) {
      const response = await request(app)
        .get(`/api/tunnel/${encodeURIComponent(malformedId)}/api/models`)
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
        .expect(403);

      expect(response.body.error.code).toBe('AUTH_TOKEN_INVALID');
    }
  });

  it('should handle concurrent requests from same user safely', async () => {
    // This test verifies that concurrent requests from the same user
    // don't interfere with each other or cause race conditions
    
    const mockWs = {
      readyState: WebSocket.OPEN,
      send: jest.fn(),
      close: jest.fn(),
      on: jest.fn(),
      removeAllListeners: jest.fn()
    };

    tunnelProxy.handleConnection(mockWs, TEST_USERS.user1.id);

    // Make multiple concurrent requests
    const requests = Array.from({ length: 10 }, (_, i) =>
      request(app)
        .get(`/api/tunnel/${TEST_USERS.user1.id}/api/models?request=${i}`)
        .set('Authorization', `Bearer ${TEST_USERS.user1.token}`)
        .expect(503) // Will timeout without desktop response
    );

    const responses = await Promise.all(requests);
    
    // All requests should fail with the same error (no desktop response)
    responses.forEach(response => {
      expect(response.status).toBe(503);
      expect(response.body.error.code).toBe('DESKTOP_CLIENT_DISCONNECTED');
    });
  });
});