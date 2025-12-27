# CloudToLocalLLM Comprehensive Testing Guide

This guide covers all testing components in the CloudToLocalLLM project, including setup, execution, and integration with the CI/CD pipeline.

## 📁 Test Directory Structure

```
test/
├── COMPREHENSIVE_TESTING_GUIDE.md    # This guide
├── README.md                         # E2E specific documentation
├── flutter_test_config.dart          # Flutter test configuration
├── test_config.dart                  # Shared test utilities
├── api-backend/                      # Node.js API backend tests
│   ├── security/                     # Security-focused tests
│   │   ├── authentication-authorization.test.js
│   │   └── user-isolation.test.js
│   ├── admin-data-flush.test.js
│   ├── message-protocol.test.js
│   ├── tunnel-*.test.js              # Tunnel functionality tests
│   └── tunnel-system-integration.test.js
├── powershell/                       # PowerShell deployment tests
│   ├── CI-TestRunner.ps1             # CI-optimized test runner
│   ├── Run-Tests.ps1                 # Standard test runner
│   ├── TestConfig.ps1                # Test configuration
│   ├── Deploy-CloudToLocalLLM.Tests.ps1
│   ├── BuildEnvironmentUtilities.Tests.ps1
│   ├── Mocks/                        # Mock implementations
│   └── Integration/                  # Integration tests
└── e2e/                             # Playwright E2E tests
    ├── ci-health-check.spec.js       # CI health validation
    ├── auth-loop-analysis.spec.js    # Authentication testing
    ├── tunnel-*.spec.js              # Tunnel functionality E2E
    └── global-setup.js               # E2E test setup
```

## 🧪 Test Categories

### 1. Flutter/Dart Tests
**Location**: Root directory and `test/` (Flutter convention)
**Purpose**: Application logic, widget testing, and static analysis

```bash
# Run all Flutter tests
flutter test

# Run with coverage
flutter test --coverage

# Static analysis
flutter analyze --fatal-infos --fatal-warnings
```

**Key Features**:
- Widget testing for UI components
- Unit testing for business logic
- Integration testing for app flows
- Static analysis for code quality

### 2. Node.js/Jest Tests
**Location**: `test/api-backend/`
**Purpose**: API backend validation, security testing, and service integration

```bash
# Navigate to API backend
cd services/api-backend

# Run all tests
npm test

# Run specific categories
npm run test:security
npm run test:auth
npm run test:user-isolation
```

**Key Features**:
- API endpoint testing
- Security validation (JWT, authentication, authorization)
- User isolation and multi-tenancy testing
- Tunnel functionality validation
- Admin service testing

### 3. PowerShell Tests
**Location**: `test/powershell/`
**Purpose**: Deployment script validation and infrastructure testing

```bash
# Run all PowerShell tests
pwsh test/powershell/CI-TestRunner.ps1

# Run with coverage
pwsh test/powershell/CI-TestRunner.ps1 -CodeCoverage -ExportResults
```

**Key Features**:
- Deployment script validation
- Infrastructure testing with mocks
- Cross-platform compatibility testing
- Error handling and rollback testing

### 4. Playwright E2E Tests
**Location**: `test/e2e/`
**Purpose**: End-to-end user workflow validation

```bash
# Install browsers (first time)
npx playwright install --with-deps

# Run all E2E tests
npx playwright test

# Run specific test
npx playwright test test/e2e/ci-health-check.spec.js
```

**Key Features**:
- Authentication flow validation
- Cross-browser compatibility testing
- Performance baseline validation
- User journey testing
- Tunnel functionality E2E validation

## 🚀 Quick Start

### Prerequisites
```bash
# Check Flutter
flutter --version  # Should be 3.24.0+

# Check Node.js
node --version     # Should be 18+

# Check PowerShell
pwsh --version     # Should be 7+

# Check Playwright
npx playwright --version
```

### Run All Tests Locally
```bash
# Using integrated deployment script (recommended)
.\scripts\deploy\Deploy-WithTests.ps1 -DryRun

# Or run individual test suites
flutter test                                    # Flutter tests
npm test --prefix services/api-backend          # Node.js tests
pwsh test/powershell/CI-TestRunner.ps1         # PowerShell tests
npx playwright test                             # E2E tests
```

## 🔄 CI/CD Integration

### GitHub Actions Pipeline
The tests are automatically executed in the CI/CD pipeline defined in `.github/workflows/ci-cd.yml`:

1. **Parallel Test Execution**: All test suites run in parallel for faster feedback
2. **Quality Gates**: Tests must pass before deployment proceeds
3. **Comprehensive Reporting**: Results are collected and reported
4. **Artifact Collection**: Test results and coverage reports are preserved

### Test Execution Order
1. **Flutter Tests** - Application core validation
2. **Node.js Tests** - API backend validation
3. **PowerShell Tests** - Deployment script validation
4. **Playwright Tests** - E2E validation (depends on Flutter build)

### Quality Gates
- **Critical Failures**: Block deployment completely
- **Warning Failures**: Generate warnings but may allow deployment
- **Coverage Thresholds**: Enforce minimum code coverage requirements

## 📊 Test Configuration

### Flutter Test Configuration
**File**: `test/flutter_test_config.dart`
- Configures test environment for CI/CD
- Sets up mock services for headless testing
- Manages test timeouts and cleanup

### Node.js Test Configuration
**File**: `services/api-backend/jest.config.js`
- Jest configuration optimized for CI
- Coverage reporting and thresholds
- Test result formatting for CI integration

### PowerShell Test Configuration
**File**: `test/powershell/TestConfig.ps1`
- Mock behavior configuration
- Test data management
- Cross-platform compatibility settings

### Playwright Test Configuration
**File**: `playwright.config.js`
- Browser configuration for different environments
- CI-specific settings and timeouts
- Test result reporting and artifact collection

## 🛠️ Development Workflow

### Adding New Tests

1. **Choose the appropriate test category** based on what you're testing
2. **Follow existing patterns** and naming conventions
3. **Include both positive and negative test cases**
4. **Add proper documentation** and comments
5. **Update CI/CD pipeline** if needed

### Test Best Practices

1. **Write descriptive test names** that explain the scenario
2. **Use proper setup and teardown** for test isolation
3. **Mock external dependencies** for reliability
4. **Include edge cases** and error conditions
5. **Keep tests fast** to maintain CI/CD performance

### Running Tests During Development

```bash
# Quick validation during development
flutter test                    # Fast feedback on Flutter changes
npm test --prefix services/api-backend --watch  # Watch mode for API changes

# Full validation before commit
.\scripts\deploy\Deploy-WithTests.ps1 -DryRun

# Specific test debugging
npx playwright test --headed --debug  # Debug E2E tests visually
```

## 🔧 Troubleshooting

### Common Issues

#### Test Environment Setup
```bash
# Flutter issues
flutter clean && flutter pub get

# Node.js issues
rm -rf node_modules && npm install

# PowerShell issues
Install-Module -Name Pester -Force

# Playwright issues
npx playwright install --with-deps
```

#### CI/CD Pipeline Issues
1. Check GitHub Actions logs for specific errors
2. Verify environment variables are set correctly
3. Ensure all dependencies are properly installed
4. Review test isolation and cleanup procedures

### Getting Help

1. **Review this guide** and related documentation
2. **Check existing test examples** for patterns
3. **Run tests locally** to reproduce issues
4. **Review CI/CD logs** for detailed error information

## 📚 Related Documentation

- [Main Testing & CI/CD Guide](../docs/TESTING_AND_CICD_GUIDE.md)
- [PowerShell Testing Framework](powershell/README.md)
- [E2E Testing Documentation](README.md)
- [Development Workflow](../docs/DEVELOPMENT_WORKFLOW.md)

---

**Note**: This testing infrastructure ensures CloudToLocalLLM maintains high quality and reliability through comprehensive automated validation at every level of the application stack.
