// Jest configuration for CloudToLocalLLM API Backend
// Optimized for CI/CD pipeline execution

export default {
  // Test environment
  testEnvironment: 'node',

  // Test file patterns
  testMatch: ["<rootDir>/../test/api-backend/**/*.js"],

  // Files to ignore
  testPathIgnorePatterns: [
    '/node_modules/',
    '/build/',
    '/dist/',
  ],

  // Coverage configuration
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: [
    'text',
    'lcov',
    'html',
    'json',
    'cobertura',
  ],

  // Coverage thresholds
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },

  // Files to collect coverage from
  collectCoverageFrom: [
    '**/*.js',
    '!**/node_modules/**',
    '!**/test/**',
    '!**/coverage/**',
    '!jest.config.js',
    '!eslint.config.js',
  ],

  // Setup files
  setupFilesAfterEnv: ['<rootDir>/test/setup.js'],

  // Module file extensions
  moduleFileExtensions: ['js', 'json'],

  // Transform configuration (for ES modules)
  transform: {},
  

  // Test timeout (increased for CI)
  testTimeout: 30000,

  // Reporters for CI
  reporters: [
    'default',
    ['jest-junit', {
      outputDirectory: 'test-results',
      outputName: 'junit.xml',
      classNameTemplate: '{classname}',
      titleTemplate: '{title}',
      ancestorSeparator: ' › ',
      usePathForSuiteName: true,
    }],
  ],

  // Verbose output for CI
  verbose: process.env.CI === 'true',

  // Bail on first test failure in CI
  bail: process.env.CI === 'true' ? 1 : 0,

  // Force exit after tests complete
  forceExit: true,

  // Clear mocks between tests
  clearMocks: true,

  // Restore mocks after each test
  restoreMocks: true,

  // Global setup/teardown
  globalSetup: '<rootDir>/test/global-setup.js',
  globalTeardown: '<rootDir>/test/global-teardown.js',

  // Environment variables for testing
  testEnvironmentOptions: {
    NODE_ENV: 'test',
  },
};
