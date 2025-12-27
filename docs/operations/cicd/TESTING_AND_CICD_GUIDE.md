# CloudToLocalLLM Testing & CI/CD Guide

This comprehensive guide covers the complete testing strategy and CI/CD pipeline for CloudToLocalLLM, including local test execution, automated testing, and deployment workflows.

## 📋 Table of Contents

- [Overview](#overview)
- [Test Suite Architecture](#test-suite-architecture)
- [Local Testing](#local-testing)
- [CI/CD Pipeline](#cicd-pipeline)
- [Test Categories](#test-categories)
- [Quality Gates](#quality-gates)
- [Deployment Integration](#deployment-integration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🎯 Overview

CloudToLocalLLM employs a comprehensive testing strategy that ensures code quality, functionality, and deployment reliability through multiple layers of automated testing:

- **Flutter/Dart Tests**: Unit tests, widget tests, and static analysis
- **Node.js/Jest Tests**: API backend testing with security validation
- **PowerShell Tests**: Deployment script validation and infrastructure testing
- **Playwright E2E Tests**: End-to-end user journey validation

## 🏗️ Test Suite Architecture

```
test/
├── flutter_test_config.dart          # Flutter test configuration
├── test_config.dart                  # Shared test utilities
├── api-backend/                      # Node.js API tests
│   ├── security/                     # Security-focused tests
│   ├── tunnel-*.test.js              # Tunnel functionality tests
│   └── admin-*.test.js               # Admin functionality tests
├── powershell/                       # PowerShell deployment tests
│   ├── CI-TestRunner.ps1             # CI-optimized test runner
│   ├── Deploy-CloudToLocalLLM.Tests.ps1
│   ├── BuildEnvironmentUtilities.Tests.ps1
│   └── Integration/                  # Integration tests
└── e2e/                             # Playwright E2E tests
    ├── ci-health-check.spec.js       # CI health validation
    ├── auth-loop-analysis.spec.js    # Authentication testing
    └── tunnel-*.spec.js              # Tunnel functionality E2E
```

## 🧪 Local Testing

### Prerequisites

Ensure you have the following tools installed:

```bash
# Flutter SDK
flutter --version  # Should be 3.24.0+

# Node.js and npm
node --version     # Should be 18+
npm --version

# PowerShell Core
pwsh --version     # Should be 7+

# Playwright (for E2E tests)
npx playwright --version
```

### Running Individual Test Suites

#### Flutter Tests

```bash
# Run all Flutter tests
flutter test

# Run with coverage
flutter test --coverage

# Run static analysis
flutter analyze --fatal-infos --fatal-warnings

# Run targeted smoke test without bundling binary assets (avoids AV false positives on chisel binaries)
flutter test --no-test-assets test/theme_extensions_test.dart

# Test build process
flutter build web --release
```

> **Environment note:** the full test suite includes network-bound integration tests that return HTTP 400 under the default `TestWidgetsFlutterBinding`. Use `--no-test-assets` and focused test targets when running on CI runners without external network access.

#### Node.js API Tests

```bash
# Navigate to API backend
cd services/api-backend

# Install dependencies
npm ci

# Run all tests
npm test

# Run specific test categories
npm run test:security
npm run test:auth
npm run test:user-isolation

# Run with verbose output
npm run test:security:verbose

# Run linting
npm run lint
```

#### PowerShell Tests

```bash
# Run all PowerShell tests
pwsh -File test/powershell/CI-TestRunner.ps1

# Run with coverage and detailed output
pwsh -File test/powershell/CI-TestRunner.ps1 -CodeCoverage -OutputFormat Detailed

# Run specific test files
pwsh -File test/powershell/Run-Tests.ps1 -TestPath "Deploy-CloudToLocalLLM.Tests.ps1"
```

#### Playwright E2E Tests

```bash
# Install browsers (first time only)
npx playwright install --with-deps

# Run all E2E tests
npx playwright test

# Run specific test
npx playwright test test/e2e/ci-health-check.spec.js

# Run in headed mode (see browser)
npx playwright test --headed

# Debug mode
npx playwright test --debug
```

### Running Complete Test Suite Locally

Use the integrated deployment script to run all tests:

```bash
# PowerShell (Windows)
.\scripts\deploy\Deploy-WithTests.ps1 -DryRun

# Bash (Linux/macOS)
./scripts/deploy/deploy-with-tests.sh --dry-run

# Skip specific test types
.\scripts\deploy\Deploy-WithTests.ps1 -SkipE2ETests -DryRun

# Include E2E tests (slower)
.\scripts\deploy\Deploy-WithTests.ps1 -IncludeE2ETests -DryRun
```

## 🚀 CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline is defined in `.github/workflows/ci-cd.yml` and includes:

#### 1. **Test Phase** (Parallel Execution)
- **Flutter Tests**: Static analysis, unit tests, build verification
- **Node.js Tests**: Linting, unit tests, security tests
- **PowerShell Tests**: Deployment script validation
- **Playwright Tests**: E2E functionality validation

#### 2. **Quality Gates**
- All tests must pass for deployment to proceed
- Critical failures block deployment completely
- Non-critical failures generate warnings but may allow deployment

#### 3. **Deployment Phase**
- Only executes if all quality gates pass
- Includes rollback mechanisms on failure
- Post-deployment verification

#### 4. **Reporting**
- Comprehensive test result summaries
- Coverage reports for all test types
- Artifact collection for debugging

### Triggering the Pipeline

```bash
# Automatic triggers
git push origin master        # Triggers full pipeline
git push origin feature-*     # Triggers tests only (no deployment)

# Manual triggers
# Use GitHub Actions UI with custom parameters:
# - skip_tests: Skip test execution (emergency)
# - deploy_environment: Target environment (production/staging)
```

### Pipeline Configuration

Key environment variables:
- `FLUTTER_VERSION`: Flutter SDK version (3.24.0)
- `NODE_VERSION`: Node.js version (18)
- `DEPLOYMENT_URL`: Target deployment URL
- `CI`: Automatically set to 'true' in CI environment

## 📊 Test Categories

### Unit Tests
- **Flutter**: Widget tests, business logic validation
- **Node.js**: API endpoint testing, middleware validation
- **PowerShell**: Function-level testing with mocks

### Integration Tests
- **API Integration**: Cross-service communication testing
- **Deployment Integration**: End-to-end deployment workflow testing
- **Authentication Integration**: Supabase Auth integration validation

### End-to-End Tests
- **User Journey Testing**: Complete user workflows
- **Cross-Browser Testing**: Chrome, Firefox, Safari compatibility
- **Performance Testing**: Load time and responsiveness validation

### Security Tests
- **Authentication Testing**: JWT validation, session management
- **Authorization Testing**: Role-based access control
- **Input Validation**: SQL injection, XSS prevention
- **User Isolation**: Multi-tenant data separation

## 🛡️ Quality Gates

### Critical Quality Gates (Block Deployment)
1. **Flutter static analysis** must pass with zero errors/warnings
2. **Node.js security tests** must pass completely
3. **PowerShell deployment tests** must pass (deployment safety)
4. **Build compilation** must succeed for all components

### Warning Quality Gates (Generate Warnings)
1. **E2E test failures** (may indicate UI issues)
2. **Performance degradation** beyond baseline thresholds
3. **Code coverage** below target thresholds

### Quality Metrics
- **Code Coverage Targets**:
  - Flutter: 80%+ line coverage
  - Node.js: 70%+ line coverage
  - PowerShell: 70%+ line coverage
- **Performance Targets**:
  - Page load time: <10 seconds
  - API response time: <2 seconds
  - Build time: <5 minutes

## 🔄 Deployment Integration

### Pre-Deployment Testing

The deployment scripts automatically run tests before deployment:

```bash
# Full deployment with tests
.\scripts\deploy\Deploy-WithTests.ps1

# Emergency deployment (skip tests)
.\scripts\deploy\Deploy-WithTests.ps1 -SkipTests

# Deployment with specific test configuration
.\scripts\deploy\Deploy-WithTests.ps1 -SkipE2ETests -ContinueOnTestFailure
```

### Post-Deployment Verification

After deployment, the pipeline runs verification tests:
1. **Health check endpoints** validation
2. **Authentication flow** verification
3. **Core functionality** smoke tests
4. **Performance baseline** validation

### Rollback Procedures

If deployment fails or post-deployment verification fails:
1. **Automatic rollback** to previous version
2. **Notification** to development team
3. **Artifact preservation** for debugging
4. **Incident logging** for post-mortem analysis

## 🔧 Troubleshooting

### Common Test Failures

#### Flutter Test Failures
```bash
# Clear Flutter cache
flutter clean
flutter pub get

# Update dependencies
flutter pub upgrade

# Check Flutter doctor
flutter doctor -v
```

#### Node.js Test Failures
```bash
# Clear npm cache
npm cache clean --force

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Check Node.js version
node --version  # Should be 18+
```

#### PowerShell Test Failures
```bash
# Update Pester module
Install-Module -Name Pester -Force -SkipPublisherCheck

# Check PowerShell version
pwsh --version  # Should be 7+

# Run with verbose output
.\test\powershell\CI-TestRunner.ps1 -Verbose
```

#### Playwright Test Failures
```bash
# Reinstall browsers
npx playwright install --with-deps

# Clear browser cache
npx playwright test --project=chromium --headed

# Check browser installation
npx playwright install-deps
```

### CI/CD Pipeline Issues

#### Pipeline Stuck or Slow
1. Check GitHub Actions status page
2. Review resource usage in workflow logs
3. Consider splitting large test suites
4. Optimize test parallelization

#### Test Flakiness
1. Review test logs for timing issues
2. Increase timeouts for CI environment
3. Add retry mechanisms for network-dependent tests
4. Use test isolation and cleanup

#### Deployment Failures
1. Check VPS connectivity and credentials
2. Verify deployment script permissions
3. Review rollback logs for recovery status
4. Validate environment configuration

### Getting Help

1. **Check Documentation**: Review this guide and related docs
2. **Review Logs**: Examine CI/CD pipeline logs for specific errors
3. **Test Locally**: Reproduce issues in local environment
4. **Create Issues**: Report bugs with detailed reproduction steps

## 🤝 Contributing

### Adding New Tests

1. **Choose appropriate test category** based on functionality
2. **Follow existing patterns** and naming conventions
3. **Include both positive and negative test cases**
4. **Add documentation** for complex test scenarios
5. **Update CI/CD pipeline** if new test categories are added

### Test Best Practices

1. **Write descriptive test names** that explain the scenario
2. **Use proper setup and teardown** to ensure test isolation
3. **Mock external dependencies** to ensure test reliability
4. **Include edge cases** and error conditions
5. **Maintain test performance** to keep CI/CD pipeline fast

### Updating the Pipeline

1. **Test changes locally** before committing
2. **Use feature branches** for pipeline modifications
3. **Document breaking changes** in commit messages
4. **Monitor pipeline performance** after changes
5. **Maintain backward compatibility** when possible

---

## 📚 Quick Reference

### Essential Commands

```bash
# Run all tests locally
.\scripts\deploy\Deploy-WithTests.ps1 -DryRun

# Run specific test suites
flutter test                                    # Flutter tests
npm test --prefix services/api-backend          # Node.js tests
pwsh test/powershell/CI-TestRunner.ps1         # PowerShell tests
npx playwright test                             # E2E tests

# CI/CD pipeline
git push origin master                          # Trigger full pipeline
git push origin feature-branch                 # Trigger tests only
```

### Test Status Indicators

| Symbol | Meaning | Action Required |
|--------|---------|-----------------|
| ✅ | All tests passed | Ready for deployment |
| ⚠️ | Non-critical failures | Review warnings, may proceed |
| ❌ | Critical failures | Fix issues before deployment |
| 🚨 | Deployment failed | Rollback initiated |

### Emergency Procedures

```bash
# Emergency deployment (skip tests)
.\scripts\deploy\Deploy-WithTests.ps1 -SkipTests -Force

# Manual rollback
.\scripts\deploy\rollback.sh --to-previous

# Check deployment status
curl -f https://app.cloudtolocalllm.online/health
```

For more information, see:
- [Development Workflow Guide](DEVELOPMENT_WORKFLOW.md)
- [Deployment Validation Guide](DEPLOYMENT/VALIDATION_TESTING_GUIDE.md)
- [PowerShell Testing Framework](../test/powershell/README.md)
