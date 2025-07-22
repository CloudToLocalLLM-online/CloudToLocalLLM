# Simplified Tunnel System Deployment Validation Script (PowerShell)
# This script validates the deployment of the new tunnel system in production

param(
    [string]$ApiBaseUrl = $env:API_BASE_URL ?? "https://api.cloudtolocalllm.online",
    [string]$TestJwtToken = $env:TEST_JWT_TOKEN ?? "",
    [string]$TestUserId = $env:TEST_USER_ID ?? "auth0|test-user-123",
    [string]$LogFile = "",
    [switch]$Verbose,
    [switch]$Help
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Initialize log file if not provided
if (-not $LogFile) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogFile = "$env:TEMP\tunnel-deployment-validation-$timestamp.log"
}

# Validation results tracking
$script:ValidationResults = @()
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0

# Logging functions
function Write-Log {
    param(
        [string]$Level,
        [string]$Message,
        [hashtable]$Data = @{}
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $($Level.ToUpper()): $Message"
    
    # Color coding for console output
    switch ($Level.ToLower()) {
        "success" { Write-Host $logEntry -ForegroundColor Green }
        "error" { Write-Host $logEntry -ForegroundColor Red }
        "warning" { Write-Host $logEntry -ForegroundColor Yellow }
        default { Write-Host $logEntry -ForegroundColor Blue }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $logEntry
    
    if ($Data.Count -gt 0) {
        $dataJson = $Data | ConvertTo-Json -Compress
        Add-Content -Path $LogFile -Value "  Data: $dataJson"
    }
}

function Record-Test {
    param(
        [string]$TestName,
        [string]$Result,
        [string]$Details = ""
    )
    
    $script:TotalTests++
    
    if ($Result -eq "PASS") {
        $script:PassedTests++
        Write-Log -Level "success" -Message "✓ $TestName"
        $script:ValidationResults += "PASS: $TestName"
    } else {
        $script:FailedTests++
        Write-Log -Level "error" -Message "✗ $TestName - $Details"
        $script:ValidationResults += "FAIL: $TestName - $Details"
    }
}

# HTTP request helper
function Invoke-HttpRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers = @{},
        [string]$Body = "",
        [int]$ExpectedStatusCode = 200,
        [int]$TimeoutSeconds = 30
    )
    
    try {
        $requestParams = @{
            Uri = $Uri
            Method = $Method
            TimeoutSec = $TimeoutSeconds
            Headers = $Headers
        }
        
        if ($Body) {
            $requestParams.Body = $Body
        }
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-RestMethod @requestParams -ErrorAction Stop
        $stopwatch.Stop()
        
        return @{
            Success = $true
            StatusCode = 200
            Content = $response
            ResponseTime = $stopwatch.ElapsedMilliseconds
        }
    }
    catch {
        $stopwatch.Stop()
        $statusCode = 0
        
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        
        return @{
            Success = $false
            StatusCode = $statusCode
            Error = $_.Exception.Message
            ResponseTime = $stopwatch.ElapsedMilliseconds
        }
    }
}

# Test WebSocket connection (simplified - requires external tool)
function Test-WebSocketConnection {
    param(
        [string]$Uri,
        [int]$TimeoutSeconds = 10
    )
    
    # Check if wscat is available
    $wscatPath = Get-Command wscat -ErrorAction SilentlyContinue
    
    if (-not $wscatPath) {
        Write-Log -Level "warning" -Message "wscat not available, skipping WebSocket test"
        return @{ Success = $true; Skipped = $true }
    }
    
    try {
        $process = Start-Process -FilePath "wscat" -ArgumentList "-c", $Uri, "-x", '{"type":"ping","id":"test"}' -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\wscat-output.txt" -RedirectStandardError "$env:TEMP\wscat-error.txt"
        
        if ($process.ExitCode -eq 0) {
            return @{ Success = $true; Skipped = $false }
        } else {
            $errorContent = Get-Content "$env:TEMP\wscat-error.txt" -Raw -ErrorAction SilentlyContinue
            return @{ Success = $false; Error = $errorContent }
        }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Validation Tests

function Test-InfrastructureHealth {
    Write-Log -Level "info" -Message "Testing infrastructure health..."
    
    # Test API health endpoint
    $healthResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/health"
    
    if ($healthResponse.Success -and $healthResponse.Content.status -eq "healthy") {
        Record-Test -TestName "API Health Check" -Result "PASS"
    } else {
        Record-Test -TestName "API Health Check" -Result "FAIL" -Details "API not healthy or unreachable"
    }
    
    # Test tunnel health endpoint
    $tunnelHealthResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/health"
    
    if ($tunnelHealthResponse.Success -and $tunnelHealthResponse.Content.status -eq "healthy") {
        Record-Test -TestName "Tunnel Health Check" -Result "PASS"
    } else {
        Record-Test -TestName "Tunnel Health Check" -Result "FAIL" -Details "Tunnel system not healthy"
    }
}

function Test-WebSocketConnectivity {
    Write-Log -Level "info" -Message "Testing WebSocket connectivity..."
    
    if (-not $TestJwtToken) {
        Write-Log -Level "warning" -Message "No test JWT token provided, skipping WebSocket test"
        Record-Test -TestName "Tunnel WebSocket Connection" -Result "SKIP" -Details "No test token available"
        return
    }
    
    $wsUrl = $ApiBaseUrl.Replace("https://", "wss://") + "/ws/tunnel?token=$TestJwtToken"
    $wsResult = Test-WebSocketConnection -Uri $wsUrl
    
    if ($wsResult.Skipped) {
        Record-Test -TestName "Tunnel WebSocket Connection" -Result "SKIP" -Details "wscat not available"
    } elseif ($wsResult.Success) {
        Record-Test -TestName "Tunnel WebSocket Connection" -Result "PASS"
    } else {
        Record-Test -TestName "Tunnel WebSocket Connection" -Result "FAIL" -Details $wsResult.Error
    }
}

function Test-Authentication {
    Write-Log -Level "info" -Message "Testing authentication system..."
    
    # Test without authentication (should fail)
    $noAuthResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/status" -ExpectedStatusCode 401
    
    if ($noAuthResponse.StatusCode -eq 401) {
        Record-Test -TestName "Authentication Required" -Result "PASS"
    } else {
        Record-Test -TestName "Authentication Required" -Result "FAIL" -Details "Endpoint accessible without authentication"
    }
    
    # Test with invalid token (should fail)
    $invalidHeaders = @{ "Authorization" = "Bearer invalid-token" }
    $invalidAuthResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/status" -Headers $invalidHeaders -ExpectedStatusCode 403
    
    if ($invalidAuthResponse.StatusCode -eq 403) {
        Record-Test -TestName "Invalid Token Rejection" -Result "PASS"
    } else {
        Record-Test -TestName "Invalid Token Rejection" -Result "FAIL" -Details "Invalid token not properly rejected"
    }
    
    # Test with valid token (if available)
    if ($TestJwtToken) {
        $validHeaders = @{ "Authorization" = "Bearer $TestJwtToken" }
        $validAuthResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/status" -Headers $validHeaders
        
        if ($validAuthResponse.Success) {
            Record-Test -TestName "Valid Token Authentication" -Result "PASS"
        } else {
            Record-Test -TestName "Valid Token Authentication" -Result "FAIL" -Details "Valid token authentication failed"
        }
    } else {
        Write-Log -Level "warning" -Message "No test JWT token provided, skipping valid token test"
        Record-Test -TestName "Valid Token Authentication" -Result "SKIP" -Details "No test token available"
    }
}

function Test-TunnelProxy {
    Write-Log -Level "info" -Message "Testing tunnel proxy endpoints..."
    
    if (-not $TestJwtToken) {
        Write-Log -Level "warning" -Message "No test JWT token provided, skipping tunnel proxy tests"
        Record-Test -TestName "Tunnel Proxy Tests" -Result "SKIP" -Details "No test token available"
        return
    }
    
    $headers = @{ "Authorization" = "Bearer $TestJwtToken" }
    
    # Test user-specific health endpoint
    $userHealthResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/health/$TestUserId" -Headers $headers
    
    if ($userHealthResponse.Success) {
        Record-Test -TestName "User Tunnel Health" -Result "PASS"
    } else {
        Record-Test -TestName "User Tunnel Health" -Result "FAIL" -Details "User tunnel health check failed"
    }
    
    # Test tunnel status endpoint
    $statusResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/status" -Headers $headers
    
    if ($statusResponse.Success -and $statusResponse.Content.user) {
        Record-Test -TestName "Tunnel Status Endpoint" -Result "PASS"
    } else {
        Record-Test -TestName "Tunnel Status Endpoint" -Result "FAIL" -Details "Invalid status response format"
    }
    
    # Test tunnel metrics endpoint
    $metricsResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/metrics" -Headers $headers
    
    if ($metricsResponse.Success -and $metricsResponse.Content.system) {
        Record-Test -TestName "Tunnel Metrics Endpoint" -Result "PASS"
    } else {
        Record-Test -TestName "Tunnel Metrics Endpoint" -Result "FAIL" -Details "Invalid metrics response format"
    }
    
    # Test cross-user access prevention
    $crossUserResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/health/auth0|other-user" -Headers $headers -ExpectedStatusCode 403
    
    if ($crossUserResponse.StatusCode -eq 403) {
        Record-Test -TestName "Cross-User Access Prevention" -Result "PASS"
    } else {
        Record-Test -TestName "Cross-User Access Prevention" -Result "FAIL" -Details "Cross-user access not properly blocked"
    }
}

function Test-ErrorHandling {
    Write-Log -Level "info" -Message "Testing error handling..."
    
    # Test 404 for non-existent endpoints
    $notFoundResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/nonexistent" -ExpectedStatusCode 404
    
    if ($notFoundResponse.StatusCode -eq 404) {
        Record-Test -TestName "404 Error Handling" -Result "PASS"
    } else {
        Record-Test -TestName "404 Error Handling" -Result "FAIL" -Details "404 errors not properly handled"
    }
}

function Test-Performance {
    Write-Log -Level "info" -Message "Testing performance characteristics..."
    
    # Test response time
    $performanceResponse = Invoke-HttpRequest -Method "GET" -Uri "$ApiBaseUrl/api/tunnel/health"
    
    if ($performanceResponse.Success) {
        if ($performanceResponse.ResponseTime -lt 2000) {
            Record-Test -TestName "Response Time Performance" -Result "PASS" -Details "Response time: $($performanceResponse.ResponseTime)ms"
        } else {
            Record-Test -TestName "Response Time Performance" -Result "FAIL" -Details "Slow response time: $($performanceResponse.ResponseTime)ms"
        }
    } else {
        Record-Test -TestName "Response Time Performance" -Result "FAIL" -Details "Health endpoint unreachable"
    }
    
    # Test concurrent connections (basic)
    $concurrentJobs = @()
    $concurrentCount = 5
    
    for ($i = 1; $i -le $concurrentCount; $i++) {
        $job = Start-Job -ScriptBlock {
            param($Uri)
            try {
                $response = Invoke-RestMethod -Uri $Uri -TimeoutSec 10
                return @{ Success = $true }
            } catch {
                return @{ Success = $false }
            }
        } -ArgumentList "$ApiBaseUrl/api/tunnel/health"
        
        $concurrentJobs += $job
    }
    
    $results = $concurrentJobs | Wait-Job | Receive-Job
    $concurrentJobs | Remove-Job
    
    $successfulRequests = ($results | Where-Object { $_.Success }).Count
    
    if ($successfulRequests -eq $concurrentCount) {
        Record-Test -TestName "Concurrent Request Handling" -Result "PASS" -Details "$successfulRequests/$concurrentCount requests succeeded"
    } else {
        Record-Test -TestName "Concurrent Request Handling" -Result "FAIL" -Details "Only $successfulRequests/$concurrentCount requests succeeded"
    }
}

function Test-Security {
    Write-Log -Level "info" -Message "Testing security measures..."
    
    # Test HTTPS enforcement (basic check)
    $httpUrl = $ApiBaseUrl.Replace("https://", "http://")
    
    try {
        $httpResponse = Invoke-WebRequest -Uri "$httpUrl/api/health" -TimeoutSec 10 -ErrorAction Stop
        
        if ($httpResponse.StatusCode -eq 301 -or $httpResponse.StatusCode -eq 302) {
            Record-Test -TestName "HTTPS Enforcement" -Result "PASS" -Details "HTTP requests properly redirected"
        } else {
            Record-Test -TestName "HTTPS Enforcement" -Result "FAIL" -Details "HTTP requests not properly handled"
        }
    }
    catch {
        # If HTTP request fails, that's actually good for security
        Record-Test -TestName "HTTPS Enforcement" -Result "PASS" -Details "HTTP endpoint not accessible"
    }
    
    # Test security headers
    try {
        $headersResponse = Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Head -TimeoutSec 10
        $securityHeadersFound = 0
        
        if ($headersResponse.Headers["Strict-Transport-Security"]) { $securityHeadersFound++ }
        if ($headersResponse.Headers["X-Content-Type-Options"]) { $securityHeadersFound++ }
        if ($headersResponse.Headers["X-Frame-Options"]) { $securityHeadersFound++ }
        
        if ($securityHeadersFound -ge 2) {
            Record-Test -TestName "Security Headers" -Result "PASS" -Details "$securityHeadersFound security headers found"
        } else {
            Record-Test -TestName "Security Headers" -Result "FAIL" -Details "Insufficient security headers ($securityHeadersFound found)"
        }
    }
    catch {
        Record-Test -TestName "Security Headers" -Result "FAIL" -Details "Could not retrieve headers"
    }
}

# Main validation function
function Start-Validation {
    Write-Log -Level "info" -Message "Starting Simplified Tunnel System Deployment Validation (PowerShell)"
    Write-Log -Level "info" -Message "API Base URL: $ApiBaseUrl"
    Write-Log -Level "info" -Message "Test User ID: $TestUserId"
    Write-Log -Level "info" -Message "Log File: $LogFile"
    
    if (-not $TestJwtToken) {
        Write-Log -Level "warning" -Message "TEST_JWT_TOKEN not provided - some tests will be skipped"
        Write-Log -Level "warning" -Message "To run full validation, set TEST_JWT_TOKEN environment variable"
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Run all validation tests
        Test-InfrastructureHealth
        Test-WebSocketConnectivity
        Test-Authentication
        Test-TunnelProxy
        Test-ErrorHandling
        Test-Performance
        Test-Security
        
        $stopwatch.Stop()
        
        # Generate summary report
        Write-Log -Level "info" -Message ""
        Write-Log -Level "info" -Message "=== VALIDATION SUMMARY ==="
        Write-Log -Level "info" -Message "Total Tests: $script:TotalTests"
        Write-Log -Level "info" -Message "Passed: $script:PassedTests"
        Write-Log -Level "info" -Message "Failed: $script:FailedTests"
        Write-Log -Level "info" -Message "Success Rate: $([math]::Round(($script:PassedTests / $script:TotalTests) * 100, 2))%"
        Write-Log -Level "info" -Message "Total Time: $($stopwatch.ElapsedMilliseconds)ms"
        
        # Print detailed results
        Write-Log -Level "info" -Message ""
        Write-Log -Level "info" -Message "=== DETAILED RESULTS ==="
        foreach ($result in $script:ValidationResults) {
            if ($result.StartsWith("PASS:")) {
                Write-Log -Level "success" -Message $result.Substring(5).Trim()
            } elseif ($result.StartsWith("FAIL:")) {
                Write-Log -Level "error" -Message $result.Substring(5).Trim()
            } else {
                Write-Log -Level "warning" -Message $result
            }
        }
        
        # Determine overall result
        if ($script:FailedTests -eq 0) {
            Write-Log -Level "success" -Message "DEPLOYMENT VALIDATION PASSED"
            Write-Log -Level "info" -Message "All critical systems are functioning properly"
            return 0
        } else {
            Write-Log -Level "error" -Message "DEPLOYMENT VALIDATION FAILED"
            Write-Log -Level "error" -Message "$script:FailedTests test(s) failed - review issues before proceeding"
            return 1
        }
    }
    catch {
        Write-Log -Level "error" -Message "Validation failed with unexpected error: $($_.Exception.Message)"
        return 2
    }
}

# Show usage information
function Show-Usage {
    Write-Host @"
Usage: .\validate_tunnel_deployment.ps1 [OPTIONS]

Validates the deployment of the Simplified Tunnel System in production.

OPTIONS:
    -ApiBaseUrl URL         API base URL (default: https://api.cloudtolocalllm.online)
    -TestJwtToken TOKEN     JWT token for authenticated tests
    -TestUserId ID          Test user ID (default: auth0|test-user-123)
    -LogFile FILE           Log file path (default: temp file with timestamp)
    -Verbose                Enable verbose output
    -Help                   Show this help message

ENVIRONMENT VARIABLES:
    API_BASE_URL           API base URL
    TEST_JWT_TOKEN         JWT token for authenticated tests
    TEST_USER_ID           Test user ID

EXAMPLES:
    # Basic validation
    .\validate_tunnel_deployment.ps1

    # Validation with custom API URL and token
    .\validate_tunnel_deployment.ps1 -ApiBaseUrl "https://staging.cloudtolocalllm.online" -TestJwtToken "eyJ0eXAiOiJKV1Q..."

    # Validation with environment variables
    $env:TEST_JWT_TOKEN = "eyJ0eXAiOiJKV1Q..."
    $env:API_BASE_URL = "https://api.cloudtolocalllm.online"
    .\validate_tunnel_deployment.ps1

EXIT CODES:
    0    All validations passed
    1    One or more validations failed
    2    Invalid arguments or configuration
"@
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Validate configuration
if (-not $ApiBaseUrl) {
    Write-Log -Level "error" -Message "API_BASE_URL is required"
    exit 2
}

# Run the validation
$exitCode = Start-Validation
exit $exitCode