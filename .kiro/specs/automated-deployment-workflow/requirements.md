# Requirements Document

## Introduction

The current CloudToLocalLLM deployment workflow consists of multiple manual scripts that require separate execution on Windows (PowerShell) and Linux VPS (bash). The workflow involves building Flutter web apps on Windows with WSL2, then deploying to a Linux VPS. This feature will create a unified PowerShell-based deployment system that can be triggered either manually or via Kiro hooks, using WSL2 to execute Linux commands when needed.

## Requirements

### Requirement 1

**User Story:** As a Windows developer, I want a single PowerShell script that handles the complete deployment workflow with full transparency, so that I can see exactly what's happening at each step and deploy confidently from my Windows development environment to the Linux VPS.

#### Acceptance Criteria

1. WHEN I run the PowerShell deployment script THEN it SHALL handle the complete workflow from Windows to VPS
2. WHEN the script needs Linux commands THEN it SHALL use WSL2 to execute them AND show the exact commands being executed
3. WHEN the script runs THEN it SHALL provide real-time visibility of all operations including command outputs, not just status messages
4. WHEN any command executes THEN it SHALL display the actual command being run before execution
5. WHEN deployment completes THEN it SHALL show success or failure with detailed information and full execution log

### Requirement 2

**User Story:** As a developer, I want to trigger deployments either manually or through Kiro hooks, so that I have flexibility in deployment timing.

#### Acceptance Criteria

1. WHEN I run the PowerShell script manually THEN it SHALL execute the full deployment process
2. WHEN I configure a Kiro hook THEN it SHALL trigger the same PowerShell deployment script
3. WHEN deployment runs via hook THEN it SHALL provide the same functionality as manual execution
4. WHEN either method is used THEN the results and logging SHALL be consistent

### Requirement 3

**User Story:** As a developer, I want the deployment script to use the existing VPS deployment infrastructure, so that I don't need to rewrite working deployment logic.

#### Acceptance Criteria

1. WHEN deployment runs THEN it SHALL use the existing complete_deployment.sh and verify_deployment.sh scripts on the VPS
2. WHEN the PowerShell script connects to VPS THEN it SHALL execute the existing Linux deployment scripts via SSH
3. WHEN VPS scripts run THEN they SHALL maintain their current strict verification and rollback capabilities
4. WHEN deployment fails THEN it SHALL use the existing Git-based rollback mechanisms

### Requirement 4

**User Story:** As a developer, I want automatic version management integrated with deployment, so that builds are properly versioned and tracked.

#### Acceptance Criteria

1. WHEN deployment starts THEN it SHALL use the existing version_manager.sh to increment build numbers
2. WHEN version is updated THEN it SHALL update all required files (pubspec.yaml, version.json, etc.)
3. WHEN deployment succeeds THEN it SHALL commit version changes using Git
4. WHEN version management fails THEN it SHALL stop deployment with clear error messages

### Requirement 5

**User Story:** As a developer, I want the deployment to maintain the existing strict quality standards with complete transparency, so that I can see exactly what's being verified and trust that only verified deployments reach production.

#### Acceptance Criteria

1. WHEN deployment completes THEN it SHALL run the existing verify_deployment.sh with zero-tolerance policy
2. WHEN verification runs THEN it SHALL check HTTP/HTTPS endpoints, SSL certificates, and container health AND display all verification steps and results in real-time
3. WHEN all verifications pass THEN deployment SHALL be marked as successful with detailed verification report
4. WHEN any verification fails THEN deployment SHALL automatically trigger rollback procedures AND show exactly what failed and why

### Requirement 6

**User Story:** As a developer, I want complete visibility into all deployment operations, so that I can understand what's happening, debug issues, and have confidence in the deployment process.

#### Acceptance Criteria

1. WHEN any command executes THEN it SHALL display the exact command with parameters before execution
2. WHEN commands produce output THEN it SHALL stream the output in real-time, not hide it behind status messages
3. WHEN SSH commands execute on VPS THEN it SHALL show both the SSH command and the remote command output
4. WHEN WSL commands execute THEN it SHALL show the WSL command and its output
5. WHEN files are being modified THEN it SHALL show which files are being changed and how
6. WHEN network operations occur THEN it SHALL show connection details and response information
7. WHEN the script runs in verbose mode THEN it SHALL show additional debugging information including timing and environment details