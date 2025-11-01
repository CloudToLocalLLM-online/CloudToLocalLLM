// CloudToLocalLLM Tunnel Performance Analysis Test
// Focuses on performance metrics, connection timing, and load testing

const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Performance test configuration
const CONFIG = {
  DEPLOYMENT_URL: process.env.DEPLOYMENT_URL || 'https://app.cloudtolocalllm.online',
  PERFORMANCE_TIMEOUT: 120000, // 2 minutes for performance tests
  CONNECTION_ATTEMPTS: 5, // Number of connection attempts to test
  LOAD_TEST_DURATION: 30000, // 30 seconds of load testing
  ACCEPTABLE_RESPONSE_TIME: 5000, // 5 seconds max response time
  ACCEPTABLE_CONNECTION_TIME: 10000, // 10 seconds max connection time
};

test.describe('Tunnel Performance Analysis', () => {
  let performanceReport = {
    timestamp: new Date().toISOString(),
    testId: `tunnel-performance-${Date.now()}`,
    connectionMetrics: [],
    responseTimeMetrics: [],
    networkPerformance: [],
    loadTestResults: [],
    performanceIssues: [],
    recommendations: [],
    result: 'UNKNOWN'
  };

  test.beforeEach(async ({ page }) => {
    console.log('⚡ Setting up tunnel performance analysis...');
    
    // Reset performance report
    performanceReport = {
      timestamp: new Date().toISOString(),
      testId: `tunnel-performance-${Date.now()}`,
      connectionMetrics: [],
      responseTimeMetrics: [],
      networkPerformance: [],
      loadTestResults: [],
      performanceIssues: [],
      recommendations: [],
      result: 'UNKNOWN'
    };

    // Monitor network performance
    page.on('response', async response => {
      const timing = response.timing;
      if (timing) {
        const performanceData = {
          timestamp: new Date().toISOString(),
          url: response.url(),
          status: response.status(),
          timing: {
            domainLookupStart: timing.domainLookupStart,
            domainLookupEnd: timing.domainLookupEnd,
            connectStart: timing.connectStart,
            connectEnd: timing.connectEnd,
            requestStart: timing.requestStart,
            responseStart: timing.responseStart,
            responseEnd: timing.responseEnd
          },
          totalTime: timing.responseEnd - timing.domainLookupStart,
          connectionTime: timing.connectEnd - timing.connectStart,
          responseTime: timing.responseEnd - timing.responseStart
        };
        
        performanceReport.networkPerformance.push(performanceData);
        
        // Flag slow responses
        if (performanceData.totalTime > CONFIG.ACCEPTABLE_RESPONSE_TIME) {
          performanceReport.performanceIssues.push(
            `Slow response: ${response.url()} took ${performanceData.totalTime}ms`
          );
        }
        
        // Flag slow connections
        if (performanceData.connectionTime > CONFIG.ACCEPTABLE_CONNECTION_TIME) {
          performanceReport.performanceIssues.push(
            `Slow connection: ${response.url()} connection took ${performanceData.connectionTime}ms`
          );
        }
      }
    });

    // Monitor console for performance-related messages
    page.on('console', msg => {
      if (msg.text().includes('performance') || 
          msg.text().includes('slow') || 
          msg.text().includes('timeout') ||
          msg.text().includes('latency')) {
        performanceReport.performanceIssues.push(`Console: ${msg.text()}`);
      }
    });
  });

  test.afterEach(async ({ page }) => {
    // Generate performance report
    const reportPath = path.join('test-results', `tunnel-performance-${performanceReport.testId}.json`);
    
    // Ensure test-results directory exists
    const testResultsDir = 'test-results';
    if (!fs.existsSync(testResultsDir)) {
      fs.mkdirSync(testResultsDir, { recursive: true });
    }
    
    // Calculate performance statistics
    if (performanceReport.networkPerformance.length > 0) {
      const responseTimes = performanceReport.networkPerformance.map(p => p.totalTime);
      const connectionTimes = performanceReport.networkPerformance.map(p => p.connectionTime);
      
      performanceReport.statistics = {
        averageResponseTime: responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length,
        maxResponseTime: Math.max(...responseTimes),
        minResponseTime: Math.min(...responseTimes),
        averageConnectionTime: connectionTimes.reduce((a, b) => a + b, 0) / connectionTimes.length,
        maxConnectionTime: Math.max(...connectionTimes),
        minConnectionTime: Math.min(...connectionTimes),
        totalRequests: performanceReport.networkPerformance.length
      };
    }
    
    // Write performance report
    fs.writeFileSync(reportPath, JSON.stringify(performanceReport, null, 2));
    console.log(` Performance report saved to: ${reportPath}`);
    
    // Print performance summary
    console.log('\n=== TUNNEL PERFORMANCE SUMMARY ===');
    console.log(`Test Result: ${performanceReport.result}`);
    if (performanceReport.statistics) {
      console.log(`Average Response Time: ${performanceReport.statistics.averageResponseTime.toFixed(2)}ms`);
      console.log(`Max Response Time: ${performanceReport.statistics.maxResponseTime}ms`);
      console.log(`Average Connection Time: ${performanceReport.statistics.averageConnectionTime.toFixed(2)}ms`);
      console.log(`Total Requests: ${performanceReport.statistics.totalRequests}`);
    }
    console.log(`Performance Issues: ${performanceReport.performanceIssues.length}`);
    
    if (performanceReport.performanceIssues.length > 0) {
      console.log('\n=== PERFORMANCE ISSUES ===');
      performanceReport.performanceIssues.slice(0, 10).forEach((issue, index) => {
        console.log(`${index + 1}. ${issue}`);
      });
      if (performanceReport.performanceIssues.length > 10) {
        console.log(`... and ${performanceReport.performanceIssues.length - 10} more issues`);
      }
    }
  });

  test('tunnel connection performance analysis', async ({ page }) => {
    console.log(' Starting tunnel connection performance analysis...');
    
    const testStart = Date.now();
    
    try {
      // Test 1: Initial page load performance
      console.log('� Test 1: Measuring initial page load performance...');
      const loadStart = Date.now();
      
      await page.goto(CONFIG.DEPLOYMENT_URL, { 
        waitUntil: 'networkidle',
        timeout: CONFIG.PERFORMANCE_TIMEOUT 
      });
      
      const loadTime = Date.now() - loadStart;
      performanceReport.connectionMetrics.push({
        test: 'INITIAL_PAGE_LOAD',
        duration: loadTime,
        timestamp: new Date().toISOString()
      });
      
      console.log(` Initial page load: ${loadTime}ms`);
      
      if (loadTime > CONFIG.ACCEPTABLE_RESPONSE_TIME) {
        performanceReport.performanceIssues.push(`Slow initial page load: ${loadTime}ms`);
        performanceReport.recommendations.push('Optimize initial page load time');
      }
      
      // Test 2: Multiple connection attempts
      console.log('� Test 2: Testing multiple connection attempts...');
      
      for (let i = 0; i < CONFIG.CONNECTION_ATTEMPTS; i++) {
        console.log(` Connection attempt ${i + 1}/${CONFIG.CONNECTION_ATTEMPTS}`);
        
        const attemptStart = Date.now();
        
        try {
          // Reload page to test connection establishment
          await page.reload({ waitUntil: 'networkidle', timeout: 30000 });
          
          // Wait for services to initialize
          await page.waitForTimeout(3000);
          
          const attemptTime = Date.now() - attemptStart;
          performanceReport.connectionMetrics.push({
            test: 'CONNECTION_ATTEMPT',
            attempt: i + 1,
            duration: attemptTime,
            timestamp: new Date().toISOString(),
            success: true
          });
          
          console.log(` Attempt ${i + 1}: ${attemptTime}ms`);
          
        } catch (error) {
          const attemptTime = Date.now() - attemptStart;
          performanceReport.connectionMetrics.push({
            test: 'CONNECTION_ATTEMPT',
            attempt: i + 1,
            duration: attemptTime,
            timestamp: new Date().toISOString(),
            success: false,
            error: error.message
          });
          
          performanceReport.performanceIssues.push(`Connection attempt ${i + 1} failed: ${error.message}`);
          console.log(` Attempt ${i + 1} failed: ${error.message}`);
        }
        
        // Brief pause between attempts
        await page.waitForTimeout(1000);
      }
      
      // Test 3: WebSocket connection performance
      console.log('� Test 3: Testing WebSocket connection performance...');
      
      const wsTestStart = Date.now();
      let wsConnected = false;
      let wsAttempts = 0;
      const maxWsAttempts = 30; // 30 seconds
      
      // Monitor for WebSocket connections
      while (wsAttempts < maxWsAttempts && !wsConnected) {
        await page.waitForTimeout(1000);
        wsAttempts++;
        
        // Check network requests for WebSocket connections
        const wsRequests = performanceReport.networkPerformance.filter(req => 
          req.url.includes('ws://') || 
          req.url.includes('wss://') || 
          req.url.includes('websocket')
        );
        
        if (wsRequests.length > 0) {
          wsConnected = true;
          const wsConnectionTime = Date.now() - wsTestStart;
          
          performanceReport.connectionMetrics.push({
            test: 'WEBSOCKET_CONNECTION',
            duration: wsConnectionTime,
            attempts: wsAttempts,
            timestamp: new Date().toISOString(),
            success: true
          });
          
          console.log(` WebSocket connection established in ${wsConnectionTime}ms (${wsAttempts} attempts)`);
          break;
        }
      }
      
      if (!wsConnected) {
        const wsConnectionTime = Date.now() - wsTestStart;
        performanceReport.connectionMetrics.push({
          test: 'WEBSOCKET_CONNECTION',
          duration: wsConnectionTime,
          attempts: wsAttempts,
          timestamp: new Date().toISOString(),
          success: false
        });
        
        performanceReport.performanceIssues.push('WebSocket connection not established within timeout');
        performanceReport.recommendations.push('Check WebSocket configuration and connectivity');
        console.log(` WebSocket connection failed after ${wsAttempts} attempts`);
      }
      
      // Test 4: Load testing simulation
      console.log('� Test 4: Running load testing simulation...');
      
      const loadTestStart = Date.now();
      const loadTestRequests = [];
      
      // Simulate multiple rapid requests
      const requestPromises = [];
      for (let i = 0; i < 10; i++) {
        const requestPromise = page.evaluate(() => {
          return fetch(window.location.href, { method: 'GET' })
            .then(response => ({
              status: response.status,
              ok: response.ok,
              timing: performance.now()
            }))
            .catch(error => ({
              error: error.message,
              timing: performance.now()
            }));
        });
        
        requestPromises.push(requestPromise);
      }
      
      try {
        const results = await Promise.all(requestPromises);
        const loadTestTime = Date.now() - loadTestStart;
        
        performanceReport.loadTestResults.push({
          test: 'CONCURRENT_REQUESTS',
          duration: loadTestTime,
          requestCount: results.length,
          successCount: results.filter(r => r.ok).length,
          errorCount: results.filter(r => r.error).length,
          timestamp: new Date().toISOString()
        });
        
        console.log(` Load test completed: ${results.length} requests in ${loadTestTime}ms`);
        
        if (loadTestTime > CONFIG.LOAD_TEST_DURATION) {
          performanceReport.performanceIssues.push(`Load test took longer than expected: ${loadTestTime}ms`);
          performanceReport.recommendations.push('Optimize server response time under load');
        }
        
      } catch (loadError) {
        performanceReport.performanceIssues.push(`Load test failed: ${loadError.message}`);
        performanceReport.recommendations.push('Check server stability under concurrent load');
      }
      
      // Determine overall result
      const totalIssues = performanceReport.performanceIssues.length;
      if (totalIssues === 0) {
        performanceReport.result = 'EXCELLENT_PERFORMANCE';
      } else if (totalIssues <= 2) {
        performanceReport.result = 'GOOD_PERFORMANCE';
      } else if (totalIssues <= 5) {
        performanceReport.result = 'ACCEPTABLE_PERFORMANCE';
      } else {
        performanceReport.result = 'POOR_PERFORMANCE';
      }
      
      console.log(` Performance analysis completed with result: ${performanceReport.result}`);
      
    } catch (error) {
      performanceReport.result = 'PERFORMANCE_TEST_FAILED';
      performanceReport.performanceIssues.push(`Performance test failed: ${error.message}`);
      throw error;
    }
    
    const totalTestTime = Date.now() - testStart;
    performanceReport.totalTestDuration = totalTestTime;
    
    // Performance assertions
    expect(performanceReport.result).not.toBe('PERFORMANCE_TEST_FAILED');
    
    if (performanceReport.result === 'POOR_PERFORMANCE') {
      console.log(' Poor performance detected - investigation recommended');
    }
  });
});
