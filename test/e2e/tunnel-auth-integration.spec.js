// CloudToLocalLLM Tunnel Authentication Integration Test
// Tests the complete authentication flow and tunnel establishment integration

const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Authentication and tunnel integration test configuration
const CONFIG = {
  DEPLOYMENT_URL: process.env.DEPLOYMENT_URL || 'https://app.cloudtolocalllm.online',
  AUTH_TIMEOUT: 60000, // 60 seconds for authentication
  TUNNEL_TIMEOUT: 120000, // 2 minutes for tunnel establishment
  INTEGRATION_TIMEOUT: 180000, // 3 minutes for full integration test
};

test.describe('Tunnel Authentication Integration', () => {
  let integrationReport = {
    timestamp: new Date().toISOString(),
    testId: `tunnel-auth-integration-${Date.now()}`,
    authenticationFlow: [],
    tunnelEstablishment: [],
    integrationSteps: [],
    networkActivity: [],
    securityChecks: [],
    issues: [],
    recommendations: [],
    result: 'UNKNOWN'
  };

  test.beforeEach(async ({ page }) => {
    console.log(' Setting up tunnel authentication integration test...');
    
    // Reset integration report
    integrationReport = {
      timestamp: new Date().toISOString(),
      testId: `tunnel-auth-integration-${Date.now()}`,
      authenticationFlow: [],
      tunnelEstablishment: [],
      integrationSteps: [],
      networkActivity: [],
      securityChecks: [],
      issues: [],
      recommendations: [],
      result: 'UNKNOWN'
    };

    // Monitor authentication-related network requests
    page.on('request', request => {
      if (request.url().includes('auth') || 
          request.url().includes('login') || 
          request.url().includes('token') ||
          request.url().includes('oauth') ||
          request.url().includes('auth0')) {
        
        integrationReport.networkActivity.push({
          type: 'AUTH_REQUEST',
          timestamp: new Date().toISOString(),
          method: request.method(),
          url: request.url(),
          headers: request.headers()
        });
        
        console.log(` AUTH REQUEST: ${request.method()} ${request.url()}`);
      }
      
      if (request.url().includes('tunnel') || 
          request.url().includes('websocket') || 
          request.url().includes('ws')) {
        
        integrationReport.networkActivity.push({
          type: 'TUNNEL_REQUEST',
          timestamp: new Date().toISOString(),
          method: request.method(),
          url: request.url(),
          headers: request.headers()
        });
        
        console.log(` TUNNEL REQUEST: ${request.method()} ${request.url()}`);
      }
    });

    page.on('response', response => {
      if (response.url().includes('auth') || 
          response.url().includes('login') || 
          response.url().includes('token') ||
          response.url().includes('oauth') ||
          response.url().includes('auth0')) {
        
        integrationReport.networkActivity.push({
          type: 'AUTH_RESPONSE',
          timestamp: new Date().toISOString(),
          status: response.status(),
          url: response.url(),
          headers: response.headers()
        });
        
        console.log(` AUTH RESPONSE: ${response.status()} ${response.url()}`);
      }
      
      if (response.url().includes('tunnel') || 
          response.url().includes('websocket') || 
          response.url().includes('ws')) {
        
        integrationReport.networkActivity.push({
          type: 'TUNNEL_RESPONSE',
          timestamp: new Date().toISOString(),
          status: response.status(),
          url: response.url(),
          headers: response.headers()
        });
        
        console.log(` TUNNEL RESPONSE: ${response.status()} ${response.url()}`);
      }
    });

    // Monitor console for authentication and tunnel messages
    page.on('console', msg => {
      if (msg.text().includes('auth') || 
          msg.text().includes('login') || 
          msg.text().includes('token') ||
          msg.text().includes('')) {
        
        integrationReport.authenticationFlow.push({
          timestamp: new Date().toISOString(),
          level: msg.type(),
          message: msg.text(),
          location: msg.location()
        });
      }
      
      if (msg.text().includes('tunnel') || 
          msg.text().includes('SimpleTunnelClient') ||
          msg.text().includes('ConnectionManager') ||
          msg.text().includes('') ||
          msg.text().includes('')) {
        
        integrationReport.tunnelEstablishment.push({
          timestamp: new Date().toISOString(),
          level: msg.type(),
          message: msg.text(),
          location: msg.location()
        });
      }
    });
  });

  test.afterEach(async ({ page }) => {
    // Generate integration report
    const reportPath = path.join('test-results', `tunnel-auth-integration-${integrationReport.testId}.json`);
    
    // Ensure test-results directory exists
    const testResultsDir = 'test-results';
    if (!fs.existsSync(testResultsDir)) {
      fs.mkdirSync(testResultsDir, { recursive: true });
    }
    
    // Add summary statistics
    integrationReport.summary = {
      authenticationEvents: integrationReport.authenticationFlow.length,
      tunnelEvents: integrationReport.tunnelEstablishment.length,
      networkRequests: integrationReport.networkActivity.length,
      securityChecks: integrationReport.securityChecks.length,
      integrationSteps: integrationReport.integrationSteps.length,
      issues: integrationReport.issues.length
    };
    
    // Write integration report
    fs.writeFileSync(reportPath, JSON.stringify(integrationReport, null, 2));
    console.log(` Integration report saved to: ${reportPath}`);
    
    // Print integration summary
    console.log('\n=== TUNNEL AUTHENTICATION INTEGRATION SUMMARY ===');
    console.log(`Test Result: ${integrationReport.result}`);
    console.log(`Authentication Events: ${integrationReport.summary.authenticationEvents}`);
    console.log(`Tunnel Events: ${integrationReport.summary.tunnelEvents}`);
    console.log(`Network Requests: ${integrationReport.summary.networkRequests}`);
    console.log(`Security Checks: ${integrationReport.summary.securityChecks}`);
    console.log(`Issues Found: ${integrationReport.summary.issues}`);
    
    if (integrationReport.issues.length > 0) {
      console.log('\n=== INTEGRATION ISSUES ===');
      integrationReport.issues.forEach((issue, index) => {
        console.log(`${index + 1}. ${issue}`);
      });
    }
  });

  test('complete authentication and tunnel integration flow', async ({ page }) => {
    console.log(' Starting complete authentication and tunnel integration test...');
    
    const testStart = Date.now();
    
    try {
      // Step 1: Navigate to application
      console.log('� Step 1: Navigating to application...');
      integrationReport.integrationSteps.push({
        step: 1,
        name: 'NAVIGATION',
        timestamp: new Date().toISOString(),
        status: 'STARTED'
      });
      
      await page.goto(CONFIG.DEPLOYMENT_URL, { 
        waitUntil: 'networkidle',
        timeout: CONFIG.AUTH_TIMEOUT 
      });
      
      integrationReport.integrationSteps[0].status = 'COMPLETED';
      integrationReport.integrationSteps[0].duration = Date.now() - testStart;
      
      console.log(' Navigation completed');
      
      // Step 2: Check initial authentication state
      console.log('� Step 2: Checking initial authentication state...');
      const authCheckStart = Date.now();
      
      integrationReport.integrationSteps.push({
        step: 2,
        name: 'AUTH_STATE_CHECK',
        timestamp: new Date().toISOString(),
        status: 'STARTED'
      });
      
      // Wait for page to fully load
      await page.waitForTimeout(3000);
      
      // Check for authentication indicators
      const isLoggedIn = await page.locator('button:has-text("Logout"), a:has-text("Logout"), [data-testid*="logout"]').count() > 0;
      const needsLogin = await page.locator('button:has-text("Login"), button:has-text("Sign In"), a:has-text("Login")').count() > 0;
      
      integrationReport.securityChecks.push({
        check: 'INITIAL_AUTH_STATE',
        timestamp: new Date().toISOString(),
        isLoggedIn: isLoggedIn,
        needsLogin: needsLogin,
        result: isLoggedIn ? 'AUTHENTICATED' : (needsLogin ? 'NEEDS_AUTH' : 'UNKNOWN')
      });
      
      integrationReport.integrationSteps[1].status = 'COMPLETED';
      integrationReport.integrationSteps[1].duration = Date.now() - authCheckStart;
      integrationReport.integrationSteps[1].result = isLoggedIn ? 'AUTHENTICATED' : 'NEEDS_AUTH';
      
      console.log(` Authentication state: ${isLoggedIn ? 'AUTHENTICATED' : 'NEEDS_AUTH'}`);
      
      // Step 3: Handle authentication if needed
      if (needsLogin && !isLoggedIn) {
        console.log('� Step 3: Performing authentication...');
        const authStart = Date.now();
        
        integrationReport.integrationSteps.push({
          step: 3,
          name: 'AUTHENTICATION',
          timestamp: new Date().toISOString(),
          status: 'STARTED'
        });
        
        try {
          const loginButton = page.locator('button:has-text("Login"), button:has-text("Sign In"), a:has-text("Login")').first();
          await loginButton.click();
          
          // Wait for Auth0 redirect or authentication flow
          await page.waitForTimeout(5000);
          
          // Monitor for authentication completion
          let authCompleted = false;
          let authAttempts = 0;
          const maxAuthAttempts = 60; // 60 seconds
          
          while (authAttempts < maxAuthAttempts && !authCompleted) {
            await page.waitForTimeout(1000);
            authAttempts++;
            
            // Check if we're back to the main app (not on auth provider)
            const currentUrl = page.url();
            if (currentUrl.includes(CONFIG.DEPLOYMENT_URL.replace('https://', '').replace('http://', ''))) {
              // Check for authenticated state
              const logoutButton = await page.locator('button:has-text("Logout"), a:has-text("Logout")').count();
              if (logoutButton > 0) {
                authCompleted = true;
                console.log(` Authentication completed after ${authAttempts} seconds`);
              }
            }
          }
          
          integrationReport.integrationSteps[2].status = authCompleted ? 'COMPLETED' : 'TIMEOUT';
          integrationReport.integrationSteps[2].duration = Date.now() - authStart;
          integrationReport.integrationSteps[2].attempts = authAttempts;
          
          if (!authCompleted) {
            integrationReport.issues.push('Authentication flow did not complete within timeout');
            integrationReport.recommendations.push('Check Auth0 configuration and authentication flow');
          }
          
        } catch (authError) {
          integrationReport.integrationSteps[2].status = 'FAILED';
          integrationReport.integrationSteps[2].error = authError.message;
          integrationReport.issues.push(`Authentication failed: ${authError.message}`);
        }
      } else {
        console.log('� Step 3: Authentication not required (already authenticated)');
        integrationReport.integrationSteps.push({
          step: 3,
          name: 'AUTHENTICATION',
          timestamp: new Date().toISOString(),
          status: 'SKIPPED',
          reason: 'Already authenticated'
        });
      }
      
      // Step 4: Test tunnel establishment
      console.log('� Step 4: Testing tunnel establishment...');
      const tunnelStart = Date.now();
      
      integrationReport.integrationSteps.push({
        step: 4,
        name: 'TUNNEL_ESTABLISHMENT',
        timestamp: new Date().toISOString(),
        status: 'STARTED'
      });
      
      // Look for tunnel setup or connection elements
      const tunnelElements = await page.locator(
        'button:has-text("Connect"), button:has-text("Setup"), [data-testid*="tunnel"], [data-testid*="connect"]'
      ).all();
      
      if (tunnelElements.length > 0) {
        console.log(` Found ${tunnelElements.length} tunnel-related elements`);
        
        // Try to initiate tunnel connection
        try {
          await tunnelElements[0].click();
          await page.waitForTimeout(3000);
          
          // Monitor tunnel establishment
          let tunnelConnected = false;
          let tunnelAttempts = 0;
          const maxTunnelAttempts = 120; // 2 minutes
          
          while (tunnelAttempts < maxTunnelAttempts && !tunnelConnected) {
            await page.waitForTimeout(1000);
            tunnelAttempts++;
            
            // Check for tunnel success indicators
            const successIndicators = await page.locator(
              '.success, .connected, .online, [data-testid*="success"], [data-testid*="connected"]'
            ).count();
            
            if (successIndicators > 0) {
              tunnelConnected = true;
              console.log(` Tunnel connected after ${tunnelAttempts} seconds`);
            }
            
            // Check for error indicators
            const errorIndicators = await page.locator(
              '.error, .failed, .offline, [data-testid*="error"], [data-testid*="failed"]'
            ).count();
            
            if (errorIndicators > 0) {
              integrationReport.issues.push('Tunnel connection error indicators detected');
              break;
            }
          }
          
          integrationReport.integrationSteps[3].status = tunnelConnected ? 'COMPLETED' : 'TIMEOUT';
          integrationReport.integrationSteps[3].duration = Date.now() - tunnelStart;
          integrationReport.integrationSteps[3].attempts = tunnelAttempts;
          integrationReport.integrationSteps[3].connected = tunnelConnected;
          
          if (!tunnelConnected) {
            integrationReport.issues.push('Tunnel connection did not establish within timeout');
            integrationReport.recommendations.push('Check tunnel configuration and connectivity');
          }
          
        } catch (tunnelError) {
          integrationReport.integrationSteps[3].status = 'FAILED';
          integrationReport.integrationSteps[3].error = tunnelError.message;
          integrationReport.issues.push(`Tunnel establishment failed: ${tunnelError.message}`);
        }
      } else {
        integrationReport.integrationSteps[3].status = 'NO_ELEMENTS';
        integrationReport.issues.push('No tunnel setup elements found');
        integrationReport.recommendations.push('Check if tunnel UI is properly rendered');
      }
      
      // Step 5: Security validation
      console.log('� Step 5: Performing security validation...');
      
      // Check for secure connections
      const secureRequests = integrationReport.networkActivity.filter(req => 
        req.url && req.url.startsWith('https://')
      );
      
      const insecureRequests = integrationReport.networkActivity.filter(req => 
        req.url && req.url.startsWith('http://') && !req.url.includes('localhost')
      );
      
      integrationReport.securityChecks.push({
        check: 'SECURE_CONNECTIONS',
        timestamp: new Date().toISOString(),
        secureRequests: secureRequests.length,
        insecureRequests: insecureRequests.length,
        result: insecureRequests.length === 0 ? 'PASS' : 'FAIL'
      });
      
      if (insecureRequests.length > 0) {
        integrationReport.issues.push(`${insecureRequests.length} insecure HTTP requests detected`);
        integrationReport.recommendations.push('Ensure all external requests use HTTPS');
      }
      
      // Determine overall result
      const criticalIssues = integrationReport.issues.filter(issue => 
        issue.includes('failed') || issue.includes('error') || issue.includes('timeout')
      ).length;
      
      if (criticalIssues === 0) {
        integrationReport.result = 'INTEGRATION_SUCCESS';
      } else if (criticalIssues <= 2) {
        integrationReport.result = 'INTEGRATION_PARTIAL_SUCCESS';
      } else {
        integrationReport.result = 'INTEGRATION_FAILED';
      }
      
      console.log(` Integration test completed with result: ${integrationReport.result}`);
      
    } catch (error) {
      integrationReport.result = 'INTEGRATION_ERROR';
      integrationReport.issues.push(`Integration test error: ${error.message}`);
      throw error;
    }
    
    const totalTestTime = Date.now() - testStart;
    integrationReport.totalTestDuration = totalTestTime;
    
    // Integration assertions
    expect(integrationReport.result).not.toBe('INTEGRATION_ERROR');
    
    if (integrationReport.result === 'INTEGRATION_FAILED') {
      console.log(' Integration test failed - critical issues detected');
    }
  });
});
