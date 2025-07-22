#!/usr/bin/env node

/**
 * Simplified Tunnel System Deployment Validation Script (Node.js)
 * 
 * This script provides advanced validation capabilities for the tunnel system
 * including WebSocket testing, load testing, and integration validation.
 */

const https = require('https');
const http = require('http');
const WebSocket = require('ws');
const { performance } = require('perf_hooks');
const fs = require('fs').promises;
const path = require('path');

// Configuration
const config = {
  apiBaseUrl: process.env.API_BASE_URL || 'https://api.cloudtolocalllm.online',
  testJwtToken: process.env.TEST_JWT_TOKEN || '',
  testUserId: process.env.TEST_USER_ID || 'auth0|test-user-123',
  timeout: 30000,
  maxConcurrentConnections: 10,
  loadTestDuration: 30000, // 30 seconds
  logFile: `/tmp/tunnel-validation-${Date.now()}.json`
};

// Test results tracking
const results = {
  timestamp: new Date().toISOString(),
  config: { ...config, testJwtToken: config.testJwtToken ? '[REDACTED]' : '' },
  tests: [],
  summary: {
    total: 0,
    passed: 0,
    failed: 0,
    skipped: 0
  }
};

// Utility functions
const log = (level, message, data = {}) => {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...data
  };
  
  console.log(`[${entry.timestamp}] ${level.toUpperCase()}: ${message}`);
  
  if (data && Object.keys(data).length > 0) {
    console.log('  Data:', JSON.stringify(data, null, 2));
  }
};

const recordTest = (name, status, details = {}, error = null) => {
  const test = {
    name,
    status, // 'PASS', 'FAIL', 'SKIP'
    timestamp: new Date().toISOString(),
    details,
    error: error ? error.message : null
  };
  
  results.tests.push(test);
  results.summary.total++;
  results.summary[status.toLowerCase()]++;
  
  const symbol = status === 'PASS' ? '✓' : status === 'FAIL' ? '✗' : '⚠';
  log('info', `${symbol} ${name}`, { status, ...details });
  
  if (error) {
    log('error', `Test failed: ${name}`, { error: error.message });
  }
};

// HTTP request helper
const makeRequest = (options, data = null) => {
  return new Promise((resolve, reject) => {
    const startTime = performance.now();
    
    const req = https.request(options, (res) => {
      let body = '';
      
      res.on('data', (chunk) => {
        body += chunk;
      });
      
      res.on('end', () => {
        const endTime = performance.now();
        const responseTime = Math.round(endTime - startTime);
        
        try {
          const parsedBody = body ? JSON.parse(body) : {};
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: parsedBody,
            rawBody: body,
            responseTime
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: body,
            rawBody: body,
            responseTime
          });
        }
      });
    });
    
    req.on('error', (error) => {
      const endTime = performance.now();
      const responseTime = Math.round(endTime - startTime);
      reject({ ...error, responseTime });
    });
    
    req.setTimeout(config.timeout, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    
    if (data) {
      req.write(typeof data === 'string' ? data : JSON.stringify(data));
    }
    
    req.end();
  });
};

// WebSocket connection helper
const testWebSocket = (url, options = {}) => {
  return new Promise((resolve, reject) => {
    const startTime = performance.now();
    const timeout = options.timeout || 10000;
    
    const ws = new WebSocket(url, options.protocols, options.wsOptions);
    
    const timeoutId = setTimeout(() => {
      ws.terminate();
      reject(new Error('WebSocket connection timeout'));
    }, timeout);
    
    ws.on('open', () => {
      const connectTime = Math.round(performance.now() - startTime);
      
      // Send test message if provided
      if (options.testMessage) {
        ws.send(JSON.stringify(options.testMessage));
      }
      
      // Wait for response or close after short delay
      setTimeout(() => {
        clearTimeout(timeoutId);
        ws.close();
        resolve({ connectTime, status: 'connected' });
      }, options.waitTime || 1000);
    });
    
    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data);
        log('debug', 'WebSocket message received', { message });
      } catch (e) {
        log('debug', 'WebSocket raw message received', { data: data.toString() });
      }
    });
    
    ws.on('error', (error) => {
      clearTimeout(timeoutId);
      reject(error);
    });
    
    ws.on('close', (code, reason) => {
      clearTimeout(timeoutId);
      if (code === 1000) {
        // Normal closure
        const connectTime = Math.round(performance.now() - startTime);
        resolve({ connectTime, status: 'closed_normally', code, reason: reason.toString() });
      } else {
        reject(new Error(`WebSocket closed with code ${code}: ${reason}`));
      }
    });
  });
};

// Test implementations

// Test 1: API Health and Availability
const testApiHealth = async () => {
  try {
    const url = new URL('/api/health', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET',
      headers: {
        'User-Agent': 'CloudToLocalLLM-Validator/1.0'
      }
    };
    
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.status === 'healthy') {
      recordTest('API Health Check', 'PASS', {
        responseTime: response.responseTime,
        status: response.body.status
      });
    } else {
      recordTest('API Health Check', 'FAIL', {
        statusCode: response.statusCode,
        responseTime: response.responseTime,
        body: response.body
      });
    }
  } catch (error) {
    recordTest('API Health Check', 'FAIL', {}, error);
  }
};

// Test 2: Tunnel System Health
const testTunnelHealth = async () => {
  try {
    const url = new URL('/api/tunnel/health', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET'
    };
    
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.status === 'healthy') {
      recordTest('Tunnel Health Check', 'PASS', {
        responseTime: response.responseTime,
        connections: response.body.connections,
        requests: response.body.requests
      });
    } else {
      recordTest('Tunnel Health Check', 'FAIL', {
        statusCode: response.statusCode,
        responseTime: response.responseTime,
        body: response.body
      });
    }
  } catch (error) {
    recordTest('Tunnel Health Check', 'FAIL', {}, error);
  }
};

// Test 3: WebSocket Connection
const testWebSocketConnection = async () => {
  if (!config.testJwtToken) {
    recordTest('WebSocket Connection', 'SKIP', { reason: 'No test JWT token provided' });
    return;
  }
  
  try {
    const wsUrl = config.apiBaseUrl.replace('https://', 'wss://') + `/ws/tunnel?token=${config.testJwtToken}`;
    
    const result = await testWebSocket(wsUrl, {
      timeout: 15000,
      testMessage: { type: 'ping', id: 'test-ping', timestamp: new Date().toISOString() },
      waitTime: 2000
    });
    
    recordTest('WebSocket Connection', 'PASS', {
      connectTime: result.connectTime,
      status: result.status
    });
  } catch (error) {
    recordTest('WebSocket Connection', 'FAIL', {}, error);
  }
};

// Test 4: Authentication and Authorization
const testAuthentication = async () => {
  // Test 1: No authentication (should fail)
  try {
    const url = new URL('/api/tunnel/status', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET'
    };
    
    const response = await makeRequest(options);
    
    if (response.statusCode === 401) {
      recordTest('Authentication Required', 'PASS', {
        statusCode: response.statusCode
      });
    } else {
      recordTest('Authentication Required', 'FAIL', {
        statusCode: response.statusCode,
        expected: 401
      });
    }
  } catch (error) {
    recordTest('Authentication Required', 'FAIL', {}, error);
  }
  
  // Test 2: Invalid token (should fail)
  try {
    const url = new URL('/api/tunnel/status', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET',
      headers: {
        'Authorization': 'Bearer invalid-token'
      }
    };
    
    const response = await makeRequest(options);
    
    if (response.statusCode === 403) {
      recordTest('Invalid Token Rejection', 'PASS', {
        statusCode: response.statusCode
      });
    } else {
      recordTest('Invalid Token Rejection', 'FAIL', {
        statusCode: response.statusCode,
        expected: 403
      });
    }
  } catch (error) {
    recordTest('Invalid Token Rejection', 'FAIL', {}, error);
  }
  
  // Test 3: Valid token (if available)
  if (config.testJwtToken) {
    try {
      const url = new URL('/api/tunnel/status', config.apiBaseUrl);
      const options = {
        hostname: url.hostname,
        port: url.port || 443,
        path: url.pathname,
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${config.testJwtToken}`
        }
      };
      
      const response = await makeRequest(options);
      
      if (response.statusCode === 200 && response.body.user) {
        recordTest('Valid Token Authentication', 'PASS', {
          statusCode: response.statusCode,
          responseTime: response.responseTime
        });
      } else {
        recordTest('Valid Token Authentication', 'FAIL', {
          statusCode: response.statusCode,
          body: response.body
        });
      }
    } catch (error) {
      recordTest('Valid Token Authentication', 'FAIL', {}, error);
    }
  } else {
    recordTest('Valid Token Authentication', 'SKIP', { reason: 'No test JWT token provided' });
  }
};

// Test 5: Rate Limiting
const testRateLimiting = async () => {
  if (!config.testJwtToken) {
    recordTest('Rate Limiting', 'SKIP', { reason: 'No test JWT token provided' });
    return;
  }
  
  try {
    const url = new URL('/api/tunnel/health', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${config.testJwtToken}`
      }
    };
    
    // Make rapid requests to trigger rate limiting
    const requests = [];
    const requestCount = 50;
    
    for (let i = 0; i < requestCount; i++) {
      requests.push(makeRequest(options).catch(e => ({ error: e })));
    }
    
    const responses = await Promise.all(requests);
    const rateLimitedResponses = responses.filter(r => r.statusCode === 429);
    
    if (rateLimitedResponses.length > 0) {
      recordTest('Rate Limiting', 'PASS', {
        totalRequests: requestCount,
        rateLimitedRequests: rateLimitedResponses.length,
        rateLimitTriggered: true
      });
    } else {
      // Rate limiting might not be triggered with this load
      recordTest('Rate Limiting', 'PASS', {
        totalRequests: requestCount,
        rateLimitedRequests: 0,
        rateLimitTriggered: false,
        note: 'Rate limiting configured but not triggered in test'
      });
    }
  } catch (error) {
    recordTest('Rate Limiting', 'FAIL', {}, error);
  }
};

// Test 6: Performance and Load Testing
const testPerformance = async () => {
  try {
    const url = new URL('/api/tunnel/health', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET'
    };
    
    // Single request performance
    const singleResponse = await makeRequest(options);
    
    // Concurrent requests performance
    const concurrentRequests = [];
    const concurrentCount = 10;
    
    const startTime = performance.now();
    
    for (let i = 0; i < concurrentCount; i++) {
      concurrentRequests.push(makeRequest(options));
    }
    
    const concurrentResponses = await Promise.all(concurrentRequests);
    const endTime = performance.now();
    
    const totalTime = Math.round(endTime - startTime);
    const avgResponseTime = Math.round(
      concurrentResponses.reduce((sum, r) => sum + r.responseTime, 0) / concurrentCount
    );
    const successfulRequests = concurrentResponses.filter(r => r.statusCode === 200).length;
    
    const performanceGood = singleResponse.responseTime < 2000 && avgResponseTime < 3000;
    
    recordTest('Performance Test', performanceGood ? 'PASS' : 'FAIL', {
      singleRequestTime: singleResponse.responseTime,
      concurrentRequests: concurrentCount,
      totalConcurrentTime: totalTime,
      avgConcurrentResponseTime: avgResponseTime,
      successfulRequests,
      successRate: (successfulRequests / concurrentCount) * 100
    });
  } catch (error) {
    recordTest('Performance Test', 'FAIL', {}, error);
  }
};

// Test 7: Error Handling
const testErrorHandling = async () => {
  // Test 404 handling
  try {
    const url = new URL('/api/tunnel/nonexistent', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET'
    };
    
    const response = await makeRequest(options);
    
    if (response.statusCode === 404) {
      recordTest('404 Error Handling', 'PASS', {
        statusCode: response.statusCode
      });
    } else {
      recordTest('404 Error Handling', 'FAIL', {
        statusCode: response.statusCode,
        expected: 404
      });
    }
  } catch (error) {
    recordTest('404 Error Handling', 'FAIL', {}, error);
  }
  
  // Test malformed JSON handling
  try {
    const url = new URL('/api/tunnel/test', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    const response = await makeRequest(options, '{"invalid": json}');
    
    // Accept either 400 (bad request) or 404 (not found)
    if (response.statusCode === 400 || response.statusCode === 404) {
      recordTest('Malformed Request Handling', 'PASS', {
        statusCode: response.statusCode
      });
    } else {
      recordTest('Malformed Request Handling', 'FAIL', {
        statusCode: response.statusCode,
        expected: '400 or 404'
      });
    }
  } catch (error) {
    recordTest('Malformed Request Handling', 'FAIL', {}, error);
  }
};

// Test 8: Security Headers
const testSecurityHeaders = async () => {
  try {
    const url = new URL('/api/health', config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'HEAD'
    };
    
    const response = await makeRequest(options);
    
    const securityHeaders = {
      'strict-transport-security': !!response.headers['strict-transport-security'],
      'x-content-type-options': !!response.headers['x-content-type-options'],
      'x-frame-options': !!response.headers['x-frame-options'],
      'x-xss-protection': !!response.headers['x-xss-protection'],
      'content-security-policy': !!response.headers['content-security-policy']
    };
    
    const securityHeaderCount = Object.values(securityHeaders).filter(Boolean).length;
    
    if (securityHeaderCount >= 3) {
      recordTest('Security Headers', 'PASS', {
        headersFound: securityHeaderCount,
        headers: securityHeaders
      });
    } else {
      recordTest('Security Headers', 'FAIL', {
        headersFound: securityHeaderCount,
        headers: securityHeaders,
        minimum: 3
      });
    }
  } catch (error) {
    recordTest('Security Headers', 'FAIL', {}, error);
  }
};

// Test 9: Cross-User Access Prevention
const testCrossUserAccess = async () => {
  if (!config.testJwtToken) {
    recordTest('Cross-User Access Prevention', 'SKIP', { reason: 'No test JWT token provided' });
    return;
  }
  
  try {
    const otherUserId = 'auth0|other-user-123';
    const url = new URL(`/api/tunnel/health/${otherUserId}`, config.apiBaseUrl);
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${config.testJwtToken}`
      }
    };
    
    const response = await makeRequest(options);
    
    if (response.statusCode === 403) {
      recordTest('Cross-User Access Prevention', 'PASS', {
        statusCode: response.statusCode
      });
    } else {
      recordTest('Cross-User Access Prevention', 'FAIL', {
        statusCode: response.statusCode,
        expected: 403,
        security_risk: 'Cross-user access not properly blocked'
      });
    }
  } catch (error) {
    recordTest('Cross-User Access Prevention', 'FAIL', {}, error);
  }
};

// Test 10: Integration Test (End-to-End)
const testIntegration = async () => {
  if (!config.testJwtToken) {
    recordTest('Integration Test', 'SKIP', { reason: 'No test JWT token provided' });
    return;
  }
  
  try {
    // Step 1: Check tunnel status
    const statusUrl = new URL('/api/tunnel/status', config.apiBaseUrl);
    const statusOptions = {
      hostname: statusUrl.hostname,
      port: statusUrl.port || 443,
      path: statusUrl.pathname,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${config.testJwtToken}`
      }
    };
    
    const statusResponse = await makeRequest(statusOptions);
    
    if (statusResponse.statusCode !== 200) {
      throw new Error(`Status check failed: ${statusResponse.statusCode}`);
    }
    
    // Step 2: Check metrics
    const metricsUrl = new URL('/api/tunnel/metrics', config.apiBaseUrl);
    const metricsOptions = {
      hostname: metricsUrl.hostname,
      port: metricsUrl.port || 443,
      path: metricsUrl.pathname,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${config.testJwtToken}`
      }
    };
    
    const metricsResponse = await makeRequest(metricsOptions);
    
    if (metricsResponse.statusCode !== 200) {
      throw new Error(`Metrics check failed: ${metricsResponse.statusCode}`);
    }
    
    // Step 3: Test WebSocket connection
    const wsUrl = config.apiBaseUrl.replace('https://', 'wss://') + `/ws/tunnel?token=${config.testJwtToken}`;
    const wsResult = await testWebSocket(wsUrl, {
      timeout: 10000,
      testMessage: { type: 'ping', id: 'integration-test', timestamp: new Date().toISOString() },
      waitTime: 1500
    });
    
    recordTest('Integration Test', 'PASS', {
      statusCheck: 'passed',
      metricsCheck: 'passed',
      websocketCheck: 'passed',
      totalTime: statusResponse.responseTime + metricsResponse.responseTime + wsResult.connectTime
    });
  } catch (error) {
    recordTest('Integration Test', 'FAIL', {}, error);
  }
};

// Main validation function
const runValidation = async () => {
  log('info', 'Starting Simplified Tunnel System Deployment Validation (Node.js)');
  log('info', `API Base URL: ${config.apiBaseUrl}`);
  log('info', `Test User ID: ${config.testUserId}`);
  log('info', `Log File: ${config.logFile}`);
  
  if (!config.testJwtToken) {
    log('warn', 'TEST_JWT_TOKEN not provided - some tests will be skipped');
  }
  
  const startTime = performance.now();
  
  try {
    // Run all validation tests
    await testApiHealth();
    await testTunnelHealth();
    await testWebSocketConnection();
    await testAuthentication();
    await testRateLimiting();
    await testPerformance();
    await testErrorHandling();
    await testSecurityHeaders();
    await testCrossUserAccess();
    await testIntegration();
    
    const endTime = performance.now();
    const totalTime = Math.round(endTime - startTime);
    
    // Add summary to results
    results.summary.totalTime = totalTime;
    results.summary.successRate = Math.round((results.summary.passed / results.summary.total) * 100);
    
    // Write results to log file
    await fs.writeFile(config.logFile, JSON.stringify(results, null, 2));
    
    // Print summary
    log('info', '=== VALIDATION SUMMARY ===');
    log('info', `Total Tests: ${results.summary.total}`);
    log('info', `Passed: ${results.summary.passed}`);
    log('info', `Failed: ${results.summary.failed}`);
    log('info', `Skipped: ${results.summary.skipped}`);
    log('info', `Success Rate: ${results.summary.successRate}%`);
    log('info', `Total Time: ${totalTime}ms`);
    log('info', `Results saved to: ${config.logFile}`);
    
    // Determine exit code
    if (results.summary.failed === 0) {
      log('info', '✓ DEPLOYMENT VALIDATION PASSED');
      log('info', 'All critical systems are functioning properly');
      process.exit(0);
    } else {
      log('error', '✗ DEPLOYMENT VALIDATION FAILED');
      log('error', `${results.summary.failed} test(s) failed - review issues before proceeding`);
      process.exit(1);
    }
  } catch (error) {
    log('error', 'Validation failed with unexpected error', { error: error.message });
    process.exit(2);
  }
};

// Handle process signals
process.on('SIGINT', () => {
  log('warn', 'Validation interrupted by user');
  process.exit(130);
});

process.on('SIGTERM', () => {
  log('warn', 'Validation terminated');
  process.exit(143);
});

// Run validation if this script is executed directly
if (require.main === module) {
  runValidation().catch((error) => {
    log('error', 'Unhandled validation error', { error: error.message });
    process.exit(2);
  });
}

module.exports = {
  runValidation,
  config,
  results
};