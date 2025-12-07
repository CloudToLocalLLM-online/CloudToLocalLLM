import { test, expect } from '@playwright/test';

test('successful login and home screen load', async ({ page }) => {
  await page.goto('https://app.cloudtolocalllm.online');

  // Click the "Sign In" button
  await page.click('text=Sign In');

  // Wait for navigation to the Google login page
  await page.waitForURL(/accounts\.google\.com/);

  // Enter email (replace with your test user's email)
  await page.fill('input[type="email"]', 'test.user@cloudtolocalllm.online');
  await page.click('text=Next');

  // Enter password (replace with your test user's password)
  // NOTE: Playwright might not be able to interact with password fields if Google has advanced security.
  // You might need to manually log in once to bypass this or use a different authentication method.
  await page.waitForSelector('input[type="password"]', { state: 'visible' });
  await page.fill('input[type="password"]', 'your_test_password'); // Replace with actual password
  await page.click('text=Next');

  // Wait for the application to redirect back after successful login
  await page.waitForURL('https://app.cloudtolocalllm.online/');

  // Verify that the home screen is displayed and not stuck in a loading state
  // This assumes HomeScreen has a unique element, e.g., a header or a chat input field
  await page.waitForSelector('text=Welcome to CloudToLocalLLM', { state: 'hidden' }); // Ensure login screen is gone
  await expect(page.locator('text=Manage and run powerful Large Language Models')).toBeVisible(); // Example element on home screen
  await expect(page.locator('text=Loading application modules...')).not.toBeVisible(); // Ensure no loading message
});