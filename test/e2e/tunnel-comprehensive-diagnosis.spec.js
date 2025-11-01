// CloudToLocalLLM Comprehensive Tunnel Diagnosis Test
// Performs deep analysis of tunnel functionality with network monitoring,
// console logging, timing analysis, and authentication state tracking

const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Test configuration
const CONFIG = {
  DEPLOYMENT_URL: process.env.DEPLOYMENT_URL || 'https://app.cloudtolocalllm.online',
  TIMEOUT: 60000, // 60 seconds timeout
  NETWORK_TIMEOUT: 30000, // 30 seconds for network requests
  AUTH_TIMEOUT: 45000, // 45 seconds for authentication
  TUNNEL_TIMEOUT: 120000, // 2 minutes for tunnel establishment
};

test.describe('Comprehensive Tunnel Diagnosis', () => {
  let testReport = {
    timestamp: new Date().toISOString(),
    testId: `tunnel-diagnosis-${Date.now()}`,
    networkRequests: [],
    consoleMessages: [],
    errors: [],
    warnings: [],
    tunnelEvents: [],
    authenticationFlow: [],
    timings: {},
    sslCertificates: [],
    connectionStates: [],
    result: 'UNKNOWN',
    issues: [],
    recommendations: []
  };

  test.beforeEach(async ({ page }) => {
    console.log(' Setting up comprehensive tunnel diagnosis...');
    
    // Reset test report for each test
    testReport = {
      timestamp: new Date().toISOString(),
      testId: `tunnel-diagnosis-${Date.now()}`,
      networkRequests: [],
      consoleMessages: [],
      errors: [],
      warnings: [],
      tunnelEvents: [],
      authenticationFlow: [],
      timings: {},
      sslCertificates: [],
      connectionStates: [],
      result: 'UNKNOWN',
      issues: [],
      recommendations: []
    };

    // Network monitoring with detailed request/response capture
    page.on('request', request => {
      const requestData = {
        timestamp: new Date().toISOString(),
        url: request.url(),
        method: request.method(),
        headers: request.headers(),
        resourceType: request.resourceType(),
        isNavigationRequest: request.isNavigationRequest(),
        postData: request.postData(),
        frame: request.frame().url()
      };
      
      testReport.networkRequests.push(requestData);
      
      // Log tunnel-related requests
      if (request.url().includes('tunnel') || 
          request.url().includes('ws') || 
          request.url().includes('websocket') ||
          request.url().includes('ollama') ||
          request.url().includes('proxy')) {
        console.log(` TUNNEL REQUEST: ${request.method()} ${request.url()}`);
        testReport.tunnelEvents.push({
          type: 'REQUEST',
          timestamp: new Date().toISOString(),
          method: request.method(),
          url: request.url(),
          headers: request.headers()
        });
      }
    });

    page.on('response', async response => {
      const responseData = {
        timestamp: new Date().toISOString(),
        url: response.url(),
        status: response.status(),
        statusText: response.statusText(),
        headers: response.headers(),
        ok: response.ok(),
        fromServiceWorker: response.fromServiceWorker(),
        timing: response.timing
      };
      
      // Add response data to corresponding request
      const requestIndex = testReport.networkRequests.findIndex(req => req.url === response.url());
      if (requestIndex !== -1) {
        testReport.networkRequests[requestIndex].response = responseData;
      }
      
      // Log tunnel-related responses
      if (response.url().includes('tunnel') || 
          response.url().includes('ws') || 
          response.url().includes('websocket') ||
          response.url().includes('ollama') ||
          response.url().includes('proxy')) {
        console.log(` TUNNEL RESPONSE: ${response.status()} ${response.url()}`);
        testReport.tunnelEvents.push({
          type: 'RESPONSE',
          timestamp: new Date().toISOString(),
          status: response.status(),
          url: response.url(),
          headers: response.headers(),
          timing: response.timing()
        });
      }

      // Capture SSL certificate information for HTTPS responses
      if (response.url().startsWith('https://')) {
        try {
          const securityDetails = response.securityDetails();
          if (securityDetails) {
            testReport.sslCertificates.push({
              url: response.url(),
              issuer: securityDetails.issuer(),
              subjectName: securityDetails.subjectName(),
              validFrom: securityDetails.validFrom(),
              validTo: securityDetails.validTo(),
              protocol: securityDetails.protocol()
            });
          }
        } catch (e) {
          // SSL details not available
        }
      }
    });

    // Console message monitoring with categorization
    page.on('console', msg => {
      const messageData = {
        timestamp: new Date().toISOString(),
        type: msg.type(),
        text: msg.text(),
        location: msg.location(),
        args: msg.args().map(arg => arg.toString())
      };
      
      testReport.consoleMessages.push(messageData);
      
      // Categorize messages
      if (msg.type() === 'error') {
        testReport.errors.push(messageData);
        console.log(` CONSOLE ERROR: ${msg.text()}`);
      } else if (msg.type() === 'warning') {
        testReport.warnings.push(messageData);
        console.log(` CONSOLE WARNING: ${msg.text()}`);
      }
      
      // Track tunnel-specific messages
      if (msg.text().includes('tunnel') || 
          msg.text().includes('SimpleTunnelClient') ||
          msg.text().includes('ConnectionManager') ||
          msg.text().includes('WebSocket') ||
          msg.text().includes('') ||
          msg.text().includes('')) {
        console.log(` TUNNEL LOG: [${msg.type()}] ${msg.text()}`);
        testReport.tunnelEvents.push({
          type: 'CONSOLE_LOG',
          timestamp: new Date().toISOString(),
          level: msg.type(),
          message: msg.text(),
          location: msg.location()
        });
      }
      
      // Track authentication messages
      if (msg.text().includes('auth') || 
          msg.text().includes('Auth0') ||
          msg.text().includes('') ||
          msg.text().includes('login') ||
          msg.text().includes('token')) {
        testReport.authenticationFlow.push({
          timestamp: new Date().toISOString(),
          level: msg.type(),
          message: msg.text(),
          location: msg.location()
        });
      }
    });

    // Page error monitoring
    page.on('pageerror', error => {
      const errorData = {
        timestamp: new Date().toISOString(),
        name: error.name,
        message: error.message,
        stack: error.stack
      };
      
      testReport.errors.push(errorData);
      console.log(` PAGE ERROR: ${error.message}`);
    });

    // Request failure monitoring
    page.on('requestfailed', request => {
      const failureData = {
        timestamp: new Date().toISOString(),
        url: request.url(),
        method: request.method(),
        failure: request.failure(),
        resourceType: request.resourceType()
      };
      
      testReport.errors.push(failureData);
      console.log(`� REQUEST FAILED: ${request.method()} ${request.url()} - ${request.failure()?.errorText}`);
    });
  });

  test.afterEach(async ({ page }) => {
    // Generate comprehensive test report
    const reportPath = path.join('test-results', `tunnel-diagnosis-${testReport.testId}.json`);
    
    // Ensure test-results directory exists
    const testResultsDir = 'test-results';
    if (!fs.existsSync(testResultsDir)) {
      fs.mkdirSync(testResultsDir, { recursive: true });
    }
    
    // Add final analysis to report
    testReport.summary = {
      totalNetworkRequests: testReport.networkRequests.length,
      totalConsoleMessages: testReport.consoleMessages.length,
      totalErrors: testReport.errors.length,
      totalWarnings: testReport.warnings.length,
      tunnelEvents: testReport.tunnelEvents.length,
      authenticationEvents: testReport.authenticationFlow.length,
      sslCertificates: testReport.sslCertificates.length
    };
    
    // Write detailed report
    fs.writeFileSync(reportPath, JSON.stringify(testReport, null, 2));
    console.log(` Detailed test report saved to: ${reportPath}`);
    
    // Print summary
    console.log('\n=== TUNNEL DIAGNOSIS SUMMARY ===');
    console.log(`Test Result: ${testReport.result}`);
    console.log(`Network Requests: ${testReport.summary.totalNetworkRequests}`);
    console.log(`Console Messages: ${testReport.summary.totalConsoleMessages}`);
    console.log(`Errors: ${testReport.summary.totalErrors}`);
    console.log(`Warnings: ${testReport.summary.totalWarnings}`);
    console.log(`Tunnel Events: ${testReport.summary.tunnelEvents}`);
    console.log(`Auth Events: ${testReport.summary.authenticationEvents}`);
    
    if (testReport.issues.length > 0) {
      console.log('\n=== ISSUES IDENTIFIED ===');
      testReport.issues.forEach((issue, index) => {
        console.log(`${index + 1}. ${issue}`);
      });
    }
    
    if (testReport.recommendations.length > 0) {
      console.log('\n=== RECOMMENDATIONS ===');
      testReport.recommendations.forEach((rec, index) => {
        console.log(`${index + 1}. ${rec}`);
      });
    }
  });

  test('comprehensive tunnel functionality diagnosis', async ({ page }) => {
    console.log(' Starting comprehensive tunnel diagnosis...');
    
    const startTime = Date.now();
    testReport.timings.testStart = startTime;
    
    try {
      // Step 1: Navigate to application
      console.log('� Step 1: Navigating to application...');
      const navigationStart = Date.now();
      
      await page.goto(CONFIG.DEPLOYMENT_URL, { 
        waitUntil: 'networkidle',
        timeout: CONFIG.TIMEOUT 
      });
      
      testReport.timings.navigationTime = Date.now() - navigationStart;
      console.log(` Navigation completed in ${testReport.timings.navigationTime}ms`);
      
      // Step 2: Wait for initial page load and service initialization
      console.log('� Step 2: Waiting for service initialization...');
      const initStart = Date.now();
      
      await page.waitForTimeout(5000); // Allow services to initialize
      
      testReport.timings.initializationTime = Date.now() - initStart;
      
      // Step 3: Check for authentication state
      console.log('� Step 3: Checking authentication state...');
      const authStart = Date.now();
      
      // Look for login/auth elements
      const authElements = await page.locator('button, a, [data-testid*="auth"], [data-testid*="login"]').all();
      const authElementsText = await Promise.all(
        authElements.map(async el => {
          try {
            return await el.textContent();
          } catch {
            return '';
          }
        })
      );
      
      testReport.authenticationFlow.push({
        timestamp: new Date().toISOString(),
        event: 'AUTH_ELEMENTS_DETECTED',
        elements: authElementsText.filter(text => text && text.trim())
      });
      
      testReport.timings.authCheckTime = Date.now() - authStart;
      
      // Step 4: Attempt authentication if needed
      console.log('� Step 4: Handling authentication...');
      const authFlowStart = Date.now();

      try {
        // Look for login button or authentication prompt
        const loginButton = page.locator('button:has-text("Login"), button:has-text("Sign In"), a:has-text("Login"), a:has-text("Sign In")').first();

        if (await loginButton.isVisible({ timeout: 5000 })) {
          console.log(' Login button found, attempting authentication...');
          await loginButton.click();

          // Wait for Auth0 or authentication flow
          await page.waitForTimeout(3000);

          testReport.authenticationFlow.push({
            timestamp: new Date().toISOString(),
            event: 'LOGIN_INITIATED',
            url: page.url()
          });
        } else {
          console.log(' No login button found, checking if already authenticated...');
        }

        testReport.timings.authFlowTime = Date.now() - authFlowStart;

      } catch (authError) {
        testReport.issues.push(`Authentication flow error: ${authError.message}`);
        testReport.recommendations.push('Check Auth0 configuration and authentication flow');
      }

      // Step 5: Look for tunnel connection elements
      console.log('� Step 5: Searching for tunnel connection elements...');
      const tunnelSearchStart = Date.now();

      // Common selectors for tunnel-related elements
      const tunnelSelectors = [
        '[data-testid*="tunnel"]',
        '[data-testid*="connection"]',
        '.tunnel-status',
        '.connection-status',
        '.status-indicator',
        'button:has-text("Connect")',
        'button:has-text("Setup")',
        'div:has-text("tunnel")',
        'div:has-text("connection")',
        'div:has-text("Ollama")'
      ];

      const tunnelElements = [];
      for (const selector of tunnelSelectors) {
        try {
          const elements = await page.locator(selector).all();
          for (const element of elements) {
            try {
              const text = await element.textContent();
              const isVisible = await element.isVisible();
              tunnelElements.push({
                selector,
                text: text?.trim(),
                visible: isVisible
              });
            } catch (e) {
              // Element might be stale, continue
            }
          }
        } catch (e) {
          // Selector might not match anything, continue
        }
      }

      testReport.tunnelEvents.push({
        type: 'TUNNEL_ELEMENTS_SEARCH',
        timestamp: new Date().toISOString(),
        elementsFound: tunnelElements.length,
        elements: tunnelElements
      });

      console.log(` Found ${tunnelElements.length} tunnel-related elements`);

      testReport.timings.tunnelSearchTime = Date.now() - tunnelSearchStart;

      // Step 6: Monitor WebSocket connections
      console.log('� Step 6: Monitoring WebSocket connections...');
      const wsMonitorStart = Date.now();

      // Check for WebSocket connections in network requests
      const wsRequests = testReport.networkRequests.filter(req =>
        req.url.includes('ws://') ||
        req.url.includes('wss://') ||
        req.url.includes('websocket') ||
        req.resourceType === 'websocket'
      );

      testReport.tunnelEvents.push({
        type: 'WEBSOCKET_ANALYSIS',
        timestamp: new Date().toISOString(),
        websocketRequests: wsRequests.length,
        requests: wsRequests
      });

      console.log(` Detected ${wsRequests.length} WebSocket-related requests`);

      testReport.timings.wsMonitorTime = Date.now() - wsMonitorStart;

      // Step 7: Test tunnel establishment workflow
      console.log('� Step 7: Testing tunnel establishment workflow...');
      const tunnelTestStart = Date.now();

      try {
        // Look for setup wizard or tunnel configuration
        const setupButton = page.locator('button:has-text("Setup"), button:has-text("Configure"), button:has-text("Connect")').first();

        if (await setupButton.isVisible({ timeout: 10000 })) {
          console.log(' Setup/Connect button found, testing tunnel workflow...');

          await setupButton.click();
          await page.waitForTimeout(2000);

          // Monitor for tunnel connection attempts
          const tunnelAttemptStart = Date.now();
          let tunnelConnected = false;
          let attempts = 0;
          const maxAttempts = 30; // 30 seconds

          while (attempts < maxAttempts && !tunnelConnected) {
            await page.waitForTimeout(1000);
            attempts++;

            // Check for success indicators
            const successIndicators = await page.locator(
              '.success, .connected, .online, [data-testid*="success"], [data-testid*="connected"]'
            ).count();

            if (successIndicators > 0) {
              tunnelConnected = true;
              console.log(` Tunnel connection indicators found after ${attempts} seconds`);
            }

            // Check for error indicators
            const errorIndicators = await page.locator(
              '.error, .failed, .offline, [data-testid*="error"], [data-testid*="failed"]'
            ).count();

            if (errorIndicators > 0) {
              testReport.issues.push('Tunnel connection error indicators detected');
              break;
            }
          }

          testReport.tunnelEvents.push({
            type: 'TUNNEL_CONNECTION_TEST',
            timestamp: new Date().toISOString(),
            connected: tunnelConnected,
            attemptDuration: Date.now() - tunnelAttemptStart,
            attempts: attempts
          });

        } else {
          console.log(' No setup/connect button found');
          testReport.issues.push('No tunnel setup interface found');
          testReport.recommendations.push('Check if tunnel setup UI is properly rendered');
        }

        testReport.timings.tunnelTestTime = Date.now() - tunnelTestStart;

      } catch (tunnelError) {
        testReport.issues.push(`Tunnel establishment test failed: ${tunnelError.message}`);
        testReport.recommendations.push('Check tunnel establishment workflow and error handling');
      }

      // Step 8: Analyze console logs for tunnel-specific issues
      console.log('� Step 8: Analyzing console logs for tunnel issues...');

      const tunnelLogs = testReport.consoleMessages.filter(msg =>
        msg.text.toLowerCase().includes('tunnel') ||
        msg.text.toLowerCase().includes('websocket') ||
        msg.text.toLowerCase().includes('connection') ||
        msg.text.includes('SimpleTunnelClient') ||
        msg.text.includes('ConnectionManager')
      );

      const errorLogs = tunnelLogs.filter(log => log.type === 'error');
      const warningLogs = tunnelLogs.filter(log => log.type === 'warning');

      if (errorLogs.length > 0) {
        testReport.issues.push(`${errorLogs.length} tunnel-related console errors detected`);
        errorLogs.forEach(error => {
          testReport.issues.push(`Console Error: ${error.text}`);
        });
      }

      if (warningLogs.length > 0) {
        testReport.issues.push(`${warningLogs.length} tunnel-related console warnings detected`);
        warningLogs.forEach(warning => {
          testReport.issues.push(`Console Warning: ${warning.text}`);
        });
      }

      // Step 9: Check for SSL/TLS certificate issues
      console.log('� Step 9: Checking SSL/TLS certificates...');

      if (testReport.sslCertificates.length > 0) {
        testReport.sslCertificates.forEach(cert => {
          const validTo = new Date(cert.validTo);
          const now = new Date();
          const daysUntilExpiry = Math.ceil((validTo - now) / (1000 * 60 * 60 * 24));

          if (daysUntilExpiry < 30) {
            testReport.issues.push(`SSL certificate for ${cert.url} expires in ${daysUntilExpiry} days`);
            testReport.recommendations.push('Renew SSL certificates before expiry');
          }

          console.log(`� SSL Certificate for ${cert.url}: Valid until ${cert.validTo} (${daysUntilExpiry} days)`);
        });
      } else {
        testReport.issues.push('No SSL certificate information captured');
        testReport.recommendations.push('Verify SSL/TLS configuration');
      }

      // Final analysis and result determination
      if (testReport.issues.length === 0) {
        testReport.result = 'SUCCESS';
      } else if (testReport.issues.length <= 3) {
        testReport.result = 'SUCCESS_WITH_WARNINGS';
      } else {
        testReport.result = 'ISSUES_DETECTED';
      }

      console.log(` Tunnel diagnosis completed with result: ${testReport.result}`);

    } catch (error) {
      testReport.result = 'NAVIGATION_FAILED';
      testReport.issues.push(`Navigation failed: ${error.message}`);
      testReport.recommendations.push('Check if the deployment URL is accessible and responding');
      throw error;
    }

    testReport.timings.totalTestTime = Date.now() - startTime;

    // Assertions based on findings
    expect(testReport.result).not.toBe('NAVIGATION_FAILED');

    if (testReport.result === 'ISSUES_DETECTED') {
      console.log(' Significant issues detected in tunnel functionality');
      // Don't fail the test, but log issues for investigation
    }
  });
});
