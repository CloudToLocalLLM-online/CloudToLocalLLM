# Mock objects for WSL integration testing
# Provides realistic mock responses for WSL commands and operations

# Mock WSL distribution list responses
$Script:MockWSLDistributions = @{
    'Full' = @(
        "  NAME            STATE           VERSION",
        "* Ubuntu-24.04    Running         2",
        "  Ubuntu-22.04    Stopped         2",
        "  Debian          Running         2",
        "  Arch            Stopped         1"
    )
    'UbuntuOnly' = @(
        "  NAME            STATE           VERSION",
        "* Ubuntu-24.04    Running         2",
        "  Ubuntu-22.04    Running         2"
    )
    'Empty' = @(
        "  NAME            STATE           VERSION"
    )
    'NoUbuntu' = @(
        "  NAME            STATE           VERSION",
        "  Debian          Running         2",
        "  Arch            Running         1"
    )
}

# Mock WSL command responses
$Script:MockWSLCommands = @{
    'flutter_version' = @(
        "Flutter 3.8.0 • channel stable • https://github.com/flutter/flutter.git",
        "Framework • revision 12345abc (2 weeks ago) • 2024-01-15 10:30:00 -0800",
        "Engine • revision 67890def",
        "Tools • Dart 3.2.0 (build 3.2.0-1.0.dev) • DevTools 2.28.4"
    )
    'git_version' = "git version 2.34.1"
    'whoami' = "testuser"
    'pwd' = "/home/testuser"
    'echo_test' = "test"
    'command_found' = "found"
    'command_missing' = "missing"
    'ssh_test_success' = "SSH_TEST_SUCCESS"
    'build_success' = @(
        "Running 'flutter pub get' in /mnt/c/project...",
        "Resolving dependencies...",
        "Got dependencies!",
        "Building for web...",
        "Compiling lib/main.dart for the Web...",
        "Build completed successfully."
    )
    'deployment_success' = @(
        "Starting deployment...",
        "Pulling latest changes...",
        "Building containers...",
        "Starting services...",
        "Deployment completed successfully."
    )
    'verification_success' = @(
        "Checking HTTP endpoints...",
        "Checking HTTPS endpoints...",
        "Checking SSL certificates...",
        "Checking container health...",
        "All verifications passed."
    )
}

# Mock file system responses
$Script:MockFileSystem = @{
    'project_files' = @{
        'pubspec.yaml' = $true
        'lib/main.dart' = $true
        'build/web/index.html' = $true
        'scripts/version_manager.ps1' = $true
    }
    'ssh_keys' = @{
        'id_rsa' = "-----BEGIN OPENSSH PRIVATE KEY-----`nMOCK_PRIVATE_KEY_CONTENT`n-----END OPENSSH PRIVATE KEY-----"
        'id_rsa.pub' = "ssh-rsa MOCK_PUBLIC_KEY_CONTENT user@host"
        'id_ed25519' = "-----BEGIN OPENSSH PRIVATE KEY-----`nMOCK_ED25519_PRIVATE_KEY`n-----END OPENSSH PRIVATE KEY-----"
        'id_ed25519.pub' = "ssh-ed25519 MOCK_ED25519_PUBLIC_KEY user@host"
    }
}

# Mock network responses
$Script:MockNetworkResponses = @{
    'ssh_success' = @{
        ExitCode = 0
        Output = "SSH connection successful"
    }
    'ssh_failure' = @{
        ExitCode = 1
        Output = "Connection refused"
    }
    'ssh_timeout' = @{
        ExitCode = 255
        Output = "Connection timed out"
    }
}

# Mock version manager responses
$Script:MockVersionManager = @{
    'current_version' = "3.10.3"
    'incremented_version' = "3.10.4"
    'semantic_version' = "3.10.3+build.123"
    'version_files' = @(
        "pubspec.yaml updated",
        "assets/version.json updated",
        "Version files synchronized"
    )
}

# Function to get mock WSL distribution list
function Get-MockWSLDistributions {
    [CmdletBinding()]
    param(
        [ValidateSet('Full', 'UbuntuOnly', 'Empty', 'NoUbuntu')]
        [string]$Scenario = 'Full'
    )
    
    return $Script:MockWSLDistributions[$Scenario]
}

# Function to get mock WSL command response
function Get-MockWSLCommandResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [int]$ExitCode = 0,
        
        [switch]$AsArray
    )
    
    # Parse command to determine response
    $responseKey = switch -Regex ($Command) {
        'flutter.*--version' { 'flutter_version' }
        'git.*--version' { 'git_version' }
        'whoami' { 'whoami' }
        'pwd' { 'pwd' }
        'echo.*test' { 'echo_test' }
        'command -v.*found' { 'command_found' }
        'command -v.*missing' { 'command_missing' }
        'echo.*SSH_TEST_SUCCESS' { 'ssh_test_success' }
        'flutter.*build.*web' { 'build_success' }
        'complete_deployment\.sh' { 'deployment_success' }
        'verify_deployment\.sh' { 'verification_success' }
        default { 'echo_test' }
    }
    
    $response = $Script:MockWSLCommands[$responseKey]
    
    if ($AsArray.IsPresent -and $response -is [string]) {
        return @($response)
    }
    elseif (-not $AsArray.IsPresent -and $response -is [array]) {
        return $response -join "`n"
    }
    
    return $response
}

# Function to mock file existence checks
function Test-MockPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $fileName = Split-Path -Leaf $Path
    $relativePath = $Path -replace '^.*[\\/]', ''
    
    # Check against mock file system
    foreach ($key in $Script:MockFileSystem.project_files.Keys) {
        if ($Path -like "*$key*" -or $relativePath -like "*$key*") {
            return $Script:MockFileSystem.project_files[$key]
        }
    }
    
    # Default to false for unknown paths
    return $false
}

# Function to get mock SSH key content
function Get-MockSSHKeyContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('id_rsa', 'id_rsa.pub', 'id_ed25519', 'id_ed25519.pub')]
        [string]$KeyType
    )
    
    return $Script:MockFileSystem.ssh_keys[$KeyType]
}

# Function to simulate network connectivity
function Test-MockNetworkConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Host,
        
        [string]$User = "testuser",
        
        [ValidateSet('Success', 'Failure', 'Timeout')]
        [string]$Scenario = 'Success'
    )
    
    $response = $Script:MockNetworkResponses["ssh_$($Scenario.ToLower())"]
    
    return @{
        ExitCode = $response.ExitCode
        Output = $response.Output
        Success = $response.ExitCode -eq 0
    }
}

# Function to get mock version manager response
function Get-MockVersionManagerResponse {
    [CmdletBinding()]
    param(
        [ValidateSet('get-semantic', 'increment', 'current')]
        [string]$Action = 'current'
    )
    
    switch ($Action) {
        'get-semantic' { return $Script:MockVersionManager.semantic_version }
        'increment' { return $Script:MockVersionManager.version_files }
        'current' { return $Script:MockVersionManager.current_version }
        default { return $Script:MockVersionManager.current_version }
    }
}

# Function to create mock test environment
function New-MockTestEnvironment {
    [CmdletBinding()]
    param(
        [string]$TestDrive = "TestDrive:"
    )
    
    # Create mock project structure
    $projectStructure = @(
        "pubspec.yaml",
        "lib/main.dart",
        "lib/services/auth_service.dart",
        "lib/models/user.dart",
        "build/web/index.html",
        "scripts/version_manager.ps1",
        "scripts/powershell/BuildEnvironmentUtilities.ps1"
    )
    
    foreach ($file in $projectStructure) {
        $fullPath = Join-Path $TestDrive $file
        $directory = Split-Path -Parent $fullPath
        
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        New-Item -ItemType File -Path $fullPath -Force | Out-Null
        
        # Add mock content for specific files
        switch ($file) {
            'pubspec.yaml' {
                Set-Content -Path $fullPath -Value @"
name: cloudtolocalllm
description: CloudToLocalLLM Flutter Application
version: 3.10.3+123
environment:
  sdk: '>=3.8.0 <4.0.0'
  flutter: ">=3.8.0"
"@
            }
            'lib/main.dart' {
                Set-Content -Path $fullPath -Value @"
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudToLocalLLM',
      home: Scaffold(
        appBar: AppBar(title: Text('CloudToLocalLLM')),
        body: Center(child: Text('Hello World')),
      ),
    );
  }
}
"@
            }
        }
    }
    
    return @{
        ProjectRoot = $TestDrive
        Structure = $projectStructure
    }
}

# Export functions for use in tests
Export-ModuleMember -Function @(
    'Get-MockWSLDistributions',
    'Get-MockWSLCommandResponse',
    'Test-MockPath',
    'Get-MockSSHKeyContent',
    'Test-MockNetworkConnectivity',
    'Get-MockVersionManagerResponse',
    'New-MockTestEnvironment'
)