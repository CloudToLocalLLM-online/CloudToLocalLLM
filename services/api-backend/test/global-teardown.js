// Global teardown for Jest tests
// Runs once after all tests

export default async function globalTeardown() {
  console.log('🧹 Cleaning up global test environment...');

  // Clean up any global resources
  // Close database connections, stop test servers, etc.

  console.log('✅ Global test cleanup completed');
}
