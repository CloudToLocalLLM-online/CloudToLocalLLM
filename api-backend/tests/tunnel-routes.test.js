/**
 * @fileoverview Unit tests for tunnel routes and middleware
 */

import { jest } from '@jest/globals';
import express from 'express';
import request from 'supertest';
import http from 'http';
import jwt from 'jsonwebtoken';

// Mock dependencies before importing
const mockJwksClient = {
  getSigningKey: jest.fn().mockResolvedValue({
    getPublicKey: () => 'mock-public-key'
  })
};

const mockTunnelProxy = {
  isUserConnected: jest.fn(),
  getUserConnectionStatus: jest.fn(),
  getStats: jest.fn(),
  forwardRequest: jest.fn(),
  handleConnection: jest.fn(),
  cleanup: jest.fn()
};

jest.mock('jwks-client', () => jest.fn(() => mockJwksClient));
jest.mock('../tunnel/tunnel-proxy.js', () => ({
  TunnelProxy: jest.fn(() => mockTunnelProxy)
}));

// Import after mocking
import { createTunnelRoutes } from '../tunnel/tunnel-routes.js';

describe('Tunnel Routes', () => {
  let app;
  let server;
  let tunnelProxy;

  const mockConfig = {
    AUTH0_DOMAIN: 'test-domain.auth0.com',
    AUTH0_AUDIENCE: 'https://test-api.example.com'
  };

  const mockUserId = 'auth0|test-user-123';
  const validToken = 'valid-jwt-token';

  beforeEach(() => {
    // Mock jwt.verify
    jest.spyOn(jwt, 'verify').mockReturnValue({ sub: mockUserId });
    jest.spyOn(jwt, 'decode').mockReturnValue({
      header: { kid: 'test-key-id' }
    });

    // Create Express app and server
    app = express();
    app.use(express.json());
    server = http.createServer(app);

    // Create tunnel routes
    const { router, tunnelProxy: proxy } = createTunnelRoutes(server, mockConfig);
    tunnelProxy = proxy;

    app.use('/api/tunnel', router);
  });

  afterEach(() => {
    jest.clearAllMocks();
    if (server && server.listening) {
      server.close();
    }
  });

  describe('Authentication Middleware', () => {
    it('should reject requests without authorization header', async () => {
      const response = await request(app)
        .get('/api/tunnel/status')
        .expect(401);

      expect(response.body).toEqual({
        error: 'Access token required',
        message: 'Authorization header with Bearer token is required'
      });
    });

    it('should reject requests with invalid token format', async () => {
      jwt.decode.mockReturnValueOnce(null);

      const response = await request(app)
        .get('/api/tunnel/status')
        .set('Authorization', 'Bearer invalid-token')
        .expect(403);

      expect(response.body).toEqual({
        error: 'Invalid or expired token',
        message: 'The provided token is invalid or has expired'
      });
    });

    it('should accept requests with valid token', async () => {
      tunnelProxy.getUserConnectionStatus.mockReturnValue({
        connected: true,
        lastPing: new Date(),
        pendingRequests: 0
      });
      tunnelProxy.getStats.mockReturnValue({
        totalConnections: 1,
        connectedUsers: 1,
        totalPendingRequests: 0
      });

      const response = await request(app)
        .get('/api/tunnel/status')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body.user.userId).toBe(mockUserId);
    });
  });

  describe('Health Check Endpoint', () => {
    it('should return user tunnel status', async () => {
      const mockStatus = {
        connected: true,
        lastPing: new Date(),
        pendingRequests: 2
      };
      tunnelProxy.getUserConnectionStatus.mockReturnValue(mockStatus);

      const response = await request(app)
        .get(`/api/tunnel/health/${mockUserId}`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body).toEqual({
        userId: mockUserId,
        ...mockStatus,
        timestamp: expect.any(String)
      });
    });

    it('should reject access to other users tunnel status', async () => {
      const otherUserId = 'auth0|other-user-456';

      const response = await request(app)
        .get(`/api/tunnel/health/${otherUserId}`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(403);

      expect(response.body).toEqual({
        error: 'Access denied',
        message: 'You can only check your own tunnel status'
      });
    });
  });

  describe('Status Endpoint', () => {
    it('should return user and system status', async () => {
      const mockUserStatus = {
        connected: true,
        lastPing: new Date(),
        pendingRequests: 1
      };
      const mockStats = {
        totalConnections: 5,
        connectedUsers: 3,
        totalPendingRequests: 10
      };

      tunnelProxy.getUserConnectionStatus.mockReturnValue(mockUserStatus);
      tunnelProxy.getStats.mockReturnValue(mockStats);

      const response = await request(app)
        .get('/api/tunnel/status')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body).toEqual({
        user: {
          userId: mockUserId,
          ...mockUserStatus
        },
        system: mockStats,
        timestamp: expect.any(String)
      });
    });
  });

  describe('Proxy Middleware', () => {
    beforeEach(() => {
      tunnelProxy.isUserConnected.mockReturnValue(true);
    });

    it('should forward GET request to desktop client', async () => {
      const mockResponse = {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"models": ["llama2"]}'
      };
      tunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const response = await request(app)
        .get(`/api/tunnel/${mockUserId}/api/models`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(tunnelProxy.forwardRequest).toHaveBeenCalledWith(mockUserId, {
        method: 'GET',
        path: '/api/models',
        headers: expect.objectContaining({
          accept: expect.any(String)
        })
      });

      expect(response.body).toEqual({ models: ['llama2'] });
    });

    it('should forward POST request with body', async () => {
      const requestBody = { model: 'llama2', prompt: 'Hello' };
      const mockResponse = {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"response": "Hi there!"}'
      };
      tunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const response = await request(app)
        .post(`/api/tunnel/${mockUserId}/api/chat`)
        .set('Authorization', `Bearer ${validToken}`)
        .send(requestBody)
        .expect(200);

      expect(tunnelProxy.forwardRequest).toHaveBeenCalledWith(mockUserId, {
        method: 'POST',
        path: '/api/chat',
        headers: expect.objectContaining({
          'content-type': 'application/json'
        }),
        body: JSON.stringify(requestBody)
      });

      expect(response.body).toEqual({ response: 'Hi there!' });
    });

    it('should reject access to other users tunnel', async () => {
      const otherUserId = 'auth0|other-user-456';

      const response = await request(app)
        .get(`/api/tunnel/${otherUserId}/api/models`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(403);

      expect(response.body).toEqual({
        error: 'Access denied',
        message: 'You can only access your own tunnel'
      });
    });

    it('should return 503 when desktop client not connected', async () => {
      tunnelProxy.isUserConnected.mockReturnValue(false);

      const response = await request(app)
        .get(`/api/tunnel/${mockUserId}/api/models`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(503);

      expect(response.body).toEqual({
        error: 'Desktop client not connected',
        message: 'Please ensure the CloudToLocalLLM desktop client is running and connected'
      });
    });

    it('should handle desktop client connection error', async () => {
      tunnelProxy.forwardRequest.mockRejectedValue(new Error('Desktop client not connected'));

      const response = await request(app)
        .get(`/api/tunnel/${mockUserId}/api/models`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(503);

      expect(response.body).toEqual({
        error: 'Service unavailable',
        message: 'Desktop client is not connected'
      });
    });

    it('should handle request timeout', async () => {
      tunnelProxy.forwardRequest.mockRejectedValue(new Error('Request timeout'));

      const response = await request(app)
        .get(`/api/tunnel/${mockUserId}/api/models`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(504);

      expect(response.body).toEqual({
        error: 'Gateway timeout',
        message: 'Request timed out after 30 seconds'
      });
    });

    it('should handle general server errors', async () => {
      tunnelProxy.forwardRequest.mockRejectedValue(new Error('Unexpected error'));

      const response = await request(app)
        .get(`/api/tunnel/${mockUserId}/api/models`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(500);

      expect(response.body).toEqual({
        error: 'Internal server error',
        message: 'Failed to process tunnel request'
      });
    });

    it('should handle non-JSON response body', async () => {
      const mockResponse = {
        status: 200,
        headers: { 'content-type': 'text/plain' },
        body: 'Plain text response'
      };
      tunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const response = await request(app)
        .get(`/api/tunnel/${mockUserId}/api/health`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.text).toBe('Plain text response');
    });

    it('should handle empty response body', async () => {
      const mockResponse = {
        status: 204,
        headers: {},
        body: ''
      };
      tunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const response = await request(app)
        .delete(`/api/tunnel/${mockUserId}/api/models/test`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(204);

      expect(response.text).toBe('');
    });

    it('should remove proxy-specific headers', async () => {
      const mockResponse = {
        status: 200,
        headers: { 'content-type': 'application/json' },
        body: '{"success": true}'
      };
      tunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      await request(app)
        .get(`/api/tunnel/${mockUserId}/api/models`)
        .set('Authorization', `Bearer ${validToken}`)
        .set('Host', 'api.example.com')
        .expect(200);

      const forwardedRequest = tunnelProxy.forwardRequest.mock.calls[0][1];
      expect(forwardedRequest.headers).not.toHaveProperty('authorization');
      expect(forwardedRequest.headers).not.toHaveProperty('host');
    });
  });
});