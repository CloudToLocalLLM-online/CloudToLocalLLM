# Patch web package to work with non-web platforms in Flutter 3.38+
# This script removes dart:js_interop imports from the web package

$webPackagePath = "$env:PUB_CACHE\hosted\pub.dev\web-1.1.1"

if (-not (Test-Path $webPackagePath)) {
    Write-Host "Web package not found at $webPackagePath"
    exit 0
}

Write-Host "Patching web package at $webPackagePath..."

# Create a stub version of the web package that doesn't use dart:js_interop
$stubContent = @"
// Stub implementation for non-web platforms
// This file replaces the web package for Windows/Linux/Android builds

library web;

// Empty exports to satisfy imports
export 'src/stub.dart';
"@

$stubImplContent = @"
// Stub implementation
class Window {}
class Document {}
class Element {}
"@

# Backup original lib/web.dart
if (Test-Path "$webPackagePath\lib\web.dart") {
    Copy-Item "$webPackagePath\lib\web.dart" "$webPackagePath\lib\web.dart.backup" -Force
}

# Replace with stub
Set-Content -Path "$webPackagePath\lib\web.dart" -Value $stubContent -Force
New-Item -ItemType Directory -Path "$webPackagePath\lib\src" -Force | Out-Null
Set-Content -Path "$webPackagePath\lib\src\stub.dart" -Value $stubImplContent -Force

Write-Host "Web package patched successfully"
