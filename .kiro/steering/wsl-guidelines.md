# WSL Native Development Guidelines

## Overview
As of December 2025, the primary development environment for CloudToLocalLLM is **WSL2 running Ubuntu 24.04**. This shift moves away from the "hybrid" model to a native Linux development workflow while leveraging Windows only for specific packaging and host-resident services.

## Core Environment
- **Distribution**: Ubuntu 24.04
- **Terminal**: WSL default (bash/zsh)
- **Editor**: VS Code with the "Remote - WSL" extension

## Service Interop
### Ollama
- **Location**: Installed on Windows Host (`ollama.exe`)
- **Access**: Access via `http://localhost:11434`
- **Networking**: WSL2 automatically proxies `localhost` to the Windows host. Do NOT use the Host IP unless automatic proxying fails.

### Docker
- **Engine**: Docker Desktop (Windows)
- **Integration**: Enable "WSL Integration" for Ubuntu 24.04 in Docker Desktop settings.
- **Commands**: Standard `docker` and `docker-compose` commands work natively in the terminal.

## SDK Management
### Flutter
- **Installation**: Native Linux SDK installed at `/opt/flutter` or user home.
- **Commands**: Use native `flutter` (Linux binary), NOT `flutter.exe`.
- **Target**: 
  - `linux`: For desktop development and testing.
  - `chrome`: For web development.

### Node.js
- **Management**: Managed via `nvm` (Node Version Manager) within Ubuntu.
- **Version**: LTS (currently v22+).

## Path Management
- **Performance**: Keep project files within the Linux file system (e.g., `~/dev/CloudToLocalLLM`) for maximum disk I/O performance.
- **Mounts**: `/mnt/c/` should only be used for cross-platform asset transfers, never for active build directories or `node_modules`.

## Scripting Standards
- **Development**: Use Bash (`.sh`) or Node.js (`.js`/`.cjs`) for all development and automation scripts.
- **Packaging**: PowerShell (`.ps1`) is reserved strictly for Windows-native installers and release packaging.