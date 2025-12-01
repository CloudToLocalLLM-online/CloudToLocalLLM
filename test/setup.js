// Jest setup file for CloudToLocalLLM API Backend tests
// Configures test environment and global mocks

import { jest, afterEach } from '@jest/globals';

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-key';
process.env.JWT_ISSUER_DOMAIN = 'test.jwt.com';
process.env.JWT_AUDIENCE = 'test-audience';
process.env.LOG_LEVEL = 'error'; // Reduce log noise in tests

// Global test timeout
jest.setTimeout(30000);

// Mock external dependencies that shouldn't be called in tests
jest.mock('winston', () => ({
  createLogger: jest.fn(() => ({
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn(),
    debug: jest.fn(),
    log: jest.fn(),
    add: jest.fn(),
  })),
  format: {
    combine: jest.fn((...args) => args),
    timestamp: jest.fn(),
    errors: jest.fn(),
    json: jest.fn(),
    colorize: jest.fn(),
    simple: jest.fn(),
    printf: jest.fn((formatter) => formatter),
  },
  transports: {
    Console: jest.fn(),
    File: jest.fn(),
  },
}));

// Cleanup after each test
afterEach(() => {
  jest.clearAllMocks();
});

console.info('Test environment setup completed');
