#!/usr/bin/env node

// CloudToLocalLLM Comprehensive Tunnel Diagnosis Runner
// Executes all tunnel tests and generates a consolidated diagnostic report

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
  DEPLOYMENT_URL: process.env.DEPLOYMENT_URL || 'https://app.cloudtolocalllm.online',
  OUTPUT_DIR: 'test-results',
  REPORT_FILE: 'tunnel-diagnosis-consolidated-report.json',
  HTML_REPORT_FILE: 'tunnel-diagnosis-report.html',
  TIMEOUT: 300000, // 5 minutes per test suite
};

// Test suites to run
const TEST_SUITES = [
  {
    name: 'Comprehensive Diagnosis',
    file: 'tunnel-comprehensive-diagnosis.spec.js',
    description: 'Deep analysis of tunnel functionality with network monitoring and console logging'
  },
  {
    name: 'Performance Analysis',
    file: 'tunnel-performance-analysis.spec.js',
    description: 'Performance metrics, connection timing, and load testing'
  },
  {
    name: 'Authentication Integration',
    file: 'tunnel-auth-integration.spec.js',
    description: 'Complete authentication flow and tunnel establishment integration'
  }
];

class TunnelDiagnosisRunner {
  constructor() {
    this.results = {
      timestamp: new Date().toISOString(),
      deploymentUrl: CONFIG.DEPLOYMENT_URL,
      testSuites: [],
      summary: {
        totalTests: 0,
        passedTests: 0,
        failedTests: 0,
        skippedTests: 0,
        totalDuration: 0
      },
      consolidatedIssues: [],
      consolidatedRecommendations: [],
      overallResult: 'UNKNOWN'
    };
  }

  async run() {
    console.log('🚀 CloudToLocalLLM Comprehensive Tunnel Diagnosis');
    console.log('================================================');
    console.log(`Deployment URL: ${CONFIG.DEPLOYMENT_URL}`);
    console.log(`Timestamp: ${this.results.timestamp}`);
    console.log('');

    // Ensure output directory exists
    if (!fs.existsSync(CONFIG.OUTPUT_DIR)) {
      fs.mkdirSync(CONFIG.OUTPUT_DIR, { recursive: true });
    }

    const overallStart = Date.now();

    // Run each test suite
    for (const suite of TEST_SUITES) {
      await this.runTestSuite(suite);
    }

    this.results.summary.totalDuration = Date.now() - overallStart;

    // Generate consolidated report
    await this.generateConsolidatedReport();
    await this.generateHTMLReport();

    // Print summary
    this.printSummary();

    // Exit with appropriate code
    process.exit(this.results.summary.failedTests > 0 ? 1 : 0);
  }

  async runTestSuite(suite) {
    console.log(`📋 Running: ${suite.name}`);
    console.log(`   ${suite.description}`);
    console.log('');

    const suiteStart = Date.now();
    const suiteResult = {
      name: suite.name,
      file: suite.file,
      description: suite.description,
      startTime: new Date().toISOString(),
      duration: 0,
      status: 'UNKNOWN',
      output: '',
      error: null,
      reportFiles: []
    };

    try {
      // Set environment variables
      const env = {
        ...process.env,
        DEPLOYMENT_URL: CONFIG.DEPLOYMENT_URL
      };

      // Run Playwright test
      const command = `npx playwright test test/e2e/${suite.file} --reporter=json`;
      console.log(`   Executing: ${command}`);

      const output = execSync(command, {
        env: env,
        timeout: CONFIG.TIMEOUT,
        encoding: 'utf8',
        cwd: process.cwd()
      });

      suiteResult.output = output;
      suiteResult.status = 'PASSED';
      this.results.summary.passedTests++;

      console.log(`   ✅ ${suite.name} completed successfully`);

    } catch (error) {
      suiteResult.error = error.message;
      suiteResult.output = error.stdout || error.message;
      suiteResult.status = 'FAILED';
      this.results.summary.failedTests++;

      console.log(`   ❌ ${suite.name} failed: ${error.message}`);
    }

    suiteResult.duration = Date.now() - suiteStart;
    suiteResult.endTime = new Date().toISOString();

    // Look for generated report files
    suiteResult.reportFiles = this.findReportFiles(suite.name);

    this.results.testSuites.push(suiteResult);
    this.results.summary.totalTests++;

    console.log(`   Duration: ${suiteResult.duration}ms`);
    console.log('');
  }

  findReportFiles(suiteName) {
    const reportFiles = [];
    
    try {
      const files = fs.readdirSync(CONFIG.OUTPUT_DIR);
      const pattern = new RegExp(`tunnel.*${Date.now().toString().slice(0, -3)}.*\\.json$`, 'i');
      
      for (const file of files) {
        if (file.includes('tunnel') && file.endsWith('.json')) {
          const filePath = path.join(CONFIG.OUTPUT_DIR, file);
          const stats = fs.statSync(filePath);
          
          // Check if file was created recently (within last 10 minutes)
          if (Date.now() - stats.mtime.getTime() < 600000) {
            reportFiles.push(file);
          }
        }
      }
    } catch (error) {
      console.log(`   Warning: Could not scan for report files: ${error.message}`);
    }

    return reportFiles;
  }

  async generateConsolidatedReport() {
    console.log('📊 Generating consolidated report...');

    // Collect all issues and recommendations from individual reports
    for (const suite of this.results.testSuites) {
      for (const reportFile of suite.reportFiles) {
        try {
          const reportPath = path.join(CONFIG.OUTPUT_DIR, reportFile);
          const reportData = JSON.parse(fs.readFileSync(reportPath, 'utf8'));

          if (reportData.issues) {
            this.results.consolidatedIssues.push(...reportData.issues.map(issue => ({
              source: suite.name,
              issue: issue
            })));
          }

          if (reportData.recommendations) {
            this.results.consolidatedRecommendations.push(...reportData.recommendations.map(rec => ({
              source: suite.name,
              recommendation: rec
            })));
          }
        } catch (error) {
          console.log(`   Warning: Could not parse report file ${reportFile}: ${error.message}`);
        }
      }
    }

    // Determine overall result
    if (this.results.summary.failedTests === 0) {
      if (this.results.consolidatedIssues.length === 0) {
        this.results.overallResult = 'EXCELLENT';
      } else if (this.results.consolidatedIssues.length <= 5) {
        this.results.overallResult = 'GOOD';
      } else {
        this.results.overallResult = 'NEEDS_ATTENTION';
      }
    } else {
      this.results.overallResult = 'CRITICAL_ISSUES';
    }

    // Save consolidated report
    const reportPath = path.join(CONFIG.OUTPUT_DIR, CONFIG.REPORT_FILE);
    fs.writeFileSync(reportPath, JSON.stringify(this.results, null, 2));

    console.log(`   ✅ Consolidated report saved to: ${reportPath}`);
  }

  async generateHTMLReport() {
    console.log('📄 Generating HTML report...');

    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CloudToLocalLLM Tunnel Diagnosis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .status-excellent { color: #28a745; }
        .status-good { color: #17a2b8; }
        .status-needs-attention { color: #ffc107; }
        .status-critical { color: #dc3545; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: #f8f9fa; padding: 15px; border-radius: 5px; text-align: center; }
        .test-suite { margin-bottom: 20px; border: 1px solid #dee2e6; border-radius: 5px; }
        .test-suite-header { background: #e9ecef; padding: 10px; font-weight: bold; }
        .test-suite-content { padding: 15px; }
        .status-passed { color: #28a745; }
        .status-failed { color: #dc3545; }
        .issues-section, .recommendations-section { margin-top: 30px; }
        .issue-item, .recommendation-item { background: #f8f9fa; margin: 5px 0; padding: 10px; border-left: 4px solid #007bff; }
        .issue-item { border-left-color: #dc3545; }
        .recommendation-item { border-left-color: #28a745; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 CloudToLocalLLM Tunnel Diagnosis Report</h1>
            <p><strong>Deployment URL:</strong> ${this.results.deploymentUrl}</p>
            <p><strong>Test Date:</strong> ${new Date(this.results.timestamp).toLocaleString()}</p>
            <h2 class="status-${this.results.overallResult.toLowerCase().replace('_', '-')}">
                Overall Result: ${this.results.overallResult}
            </h2>
        </div>

        <div class="summary">
            <div class="summary-card">
                <h3>Total Tests</h3>
                <p style="font-size: 2em; margin: 0;">${this.results.summary.totalTests}</p>
            </div>
            <div class="summary-card">
                <h3>Passed</h3>
                <p style="font-size: 2em; margin: 0; color: #28a745;">${this.results.summary.passedTests}</p>
            </div>
            <div class="summary-card">
                <h3>Failed</h3>
                <p style="font-size: 2em; margin: 0; color: #dc3545;">${this.results.summary.failedTests}</p>
            </div>
            <div class="summary-card">
                <h3>Duration</h3>
                <p style="font-size: 1.5em; margin: 0;">${Math.round(this.results.summary.totalDuration / 1000)}s</p>
            </div>
        </div>

        <h2>Test Suites</h2>
        ${this.results.testSuites.map(suite => `
            <div class="test-suite">
                <div class="test-suite-header">
                    <span class="status-${suite.status.toLowerCase()}">${suite.status}</span>
                    ${suite.name}
                </div>
                <div class="test-suite-content">
                    <p><strong>Description:</strong> ${suite.description}</p>
                    <p><strong>Duration:</strong> ${Math.round(suite.duration / 1000)}s</p>
                    <p><strong>Report Files:</strong> ${suite.reportFiles.length > 0 ? suite.reportFiles.join(', ') : 'None'}</p>
                    ${suite.error ? `<p><strong>Error:</strong> <code>${suite.error}</code></p>` : ''}
                </div>
            </div>
        `).join('')}

        ${this.results.consolidatedIssues.length > 0 ? `
            <div class="issues-section">
                <h2>🚨 Issues Detected (${this.results.consolidatedIssues.length})</h2>
                ${this.results.consolidatedIssues.map(item => `
                    <div class="issue-item">
                        <strong>[${item.source}]</strong> ${item.issue}
                    </div>
                `).join('')}
            </div>
        ` : ''}

        ${this.results.consolidatedRecommendations.length > 0 ? `
            <div class="recommendations-section">
                <h2>💡 Recommendations (${this.results.consolidatedRecommendations.length})</h2>
                ${this.results.consolidatedRecommendations.map(item => `
                    <div class="recommendation-item">
                        <strong>[${item.source}]</strong> ${item.recommendation}
                    </div>
                `).join('')}
            </div>
        ` : ''}
    </div>
</body>
</html>`;

    const htmlPath = path.join(CONFIG.OUTPUT_DIR, CONFIG.HTML_REPORT_FILE);
    fs.writeFileSync(htmlPath, html);

    console.log(`   ✅ HTML report saved to: ${htmlPath}`);
  }

  printSummary() {
    console.log('');
    console.log('🎯 TUNNEL DIAGNOSIS SUMMARY');
    console.log('===========================');
    console.log(`Overall Result: ${this.results.overallResult}`);
    console.log(`Total Tests: ${this.results.summary.totalTests}`);
    console.log(`Passed: ${this.results.summary.passedTests}`);
    console.log(`Failed: ${this.results.summary.failedTests}`);
    console.log(`Total Duration: ${Math.round(this.results.summary.totalDuration / 1000)}s`);
    console.log(`Issues Found: ${this.results.consolidatedIssues.length}`);
    console.log(`Recommendations: ${this.results.consolidatedRecommendations.length}`);
    console.log('');

    if (this.results.consolidatedIssues.length > 0) {
      console.log('🚨 TOP ISSUES:');
      this.results.consolidatedIssues.slice(0, 5).forEach((item, index) => {
        console.log(`   ${index + 1}. [${item.source}] ${item.issue}`);
      });
      if (this.results.consolidatedIssues.length > 5) {
        console.log(`   ... and ${this.results.consolidatedIssues.length - 5} more issues`);
      }
      console.log('');
    }

    if (this.results.consolidatedRecommendations.length > 0) {
      console.log('💡 TOP RECOMMENDATIONS:');
      this.results.consolidatedRecommendations.slice(0, 3).forEach((item, index) => {
        console.log(`   ${index + 1}. [${item.source}] ${item.recommendation}`);
      });
      console.log('');
    }

    console.log(`📊 Detailed reports available in: ${CONFIG.OUTPUT_DIR}/`);
    console.log(`📄 HTML report: ${CONFIG.OUTPUT_DIR}/${CONFIG.HTML_REPORT_FILE}`);
  }
}

// Run the diagnosis if this script is executed directly
if (require.main === module) {
  const runner = new TunnelDiagnosisRunner();
  runner.run().catch(error => {
    console.error('❌ Tunnel diagnosis failed:', error);
    process.exit(1);
  });
}

module.exports = TunnelDiagnosisRunner;
