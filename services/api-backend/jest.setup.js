// Jest global setup for API backend tests
// - Mocks external dependencies (Firebase Admin, network)
// - Sets up JUnit reporter output directory if needed

// Mock firebase-admin to avoid real Firebase calls in CI
jest.mock('firebase-admin', () => {
  return {
    initializeApp: jest.fn(() => ({})),
    auth: () => ({
      verifyIdToken: jest.fn().mockResolvedValue({ uid: 'test-user', email: 'test@example.com' }),
      getUser: jest.fn().mockResolvedValue({ uid: 'test-user' }),
    }),
    credential: {
      applicationDefault: jest.fn(() => ({})),
    },
  };
});

// Disable real network calls by default (you can switch to msw if needed)
const nock = require('nock');

beforeAll(() => {
  nock.disableNetConnect();
  // Allow localhost if needed for tests
  nock.enableNetConnect(host => host.includes('127.0.0.1') || host.includes('localhost'));
});

afterAll(() => {
  nock.cleanAll();
  nock.restore();
});

