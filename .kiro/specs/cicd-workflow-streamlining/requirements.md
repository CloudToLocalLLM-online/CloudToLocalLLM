# Requirements Document

## Introduction

CloudToLocalLLM currently uses an overly complex AI-powered CI/CD orchestration system that introduces unnecessary complexity, potential failure points, and maintenance overhead. The system involves multiple workflows, AI analysis for version bumping, platform-specific branch management, and complex deployment orchestration. This spec aims to streamline the CI/CD process while maintaining reliability and reducing complexity.

## Glossary

- **CI/CD System**: The continuous integration and continuous deployment automation system
- **Orchestrator Workflow**: The main workflow that coordinates version management and deployment triggers
- **AI Analysis**: The Kilocode/Gemini-powered system that analyzes commits and determines version bumps
- **Platform Branches**: Separate git branches for cloud, desktop, and mobile deployments
- **Repository Dispatch**: GitHub API mechanism for triggering workflows programmatically
- **Deployment Pipeline**: The sequence of build, test, and deployment steps
- **Version Management**: The automated system for semantic version bumping
- **Build Matrix**: The configuration for building multiple platform variants

## Requirements

### Requirement 1

**User Story:** As a developer, I want a simple and reliable CI/CD system that deploys changes automatically without complex orchestration, so that I can focus on development rather than deployment logistics.

#### Acceptance Criteria

1. WHEN a developer pushes to the main branch THEN the system SHALL trigger deployment directly without intermediate orchestration workflows
2. WHEN deployment is needed THEN the system SHALL use simple trigger patterns instead of repository dispatch events
3. WHEN version management is required THEN the system SHALL use conventional commit parsing instead of AI analysis
4. WHEN multiple services need deployment THEN the system SHALL build and deploy them in a single workflow
5. WHEN deployment fails THEN the system SHALL provide clear error messages without complex debugging across multiple workflows

### Requirement 2

**User Story:** As a DevOps engineer, I want reliable AI-powered version management that makes intelligent decisions based on commit analysis, so that version bumps are accurate and contextual.

#### Acceptance Criteria

1. WHEN AI analyzes commits THEN the system SHALL consider both commit messages and file changes for version bump decisions
2. WHEN breaking changes are detected by AI THEN the system SHALL increment the major version
3. WHEN new features are detected by AI THEN the system SHALL increment the minor version
4. WHEN bug fixes are detected by AI THEN the system SHALL increment the patch version
5. WHEN AI analysis fails THEN the system SHALL fail the workflow and require manual intervention

### Requirement 3

**User Story:** As a system administrator, I want simplified workflow architecture with fewer moving parts, so that the system is easier to maintain and debug.

#### Acceptance Criteria

1. WHEN workflows are executed THEN the system SHALL use direct triggers instead of complex orchestration
2. WHEN cloud deployment is needed THEN the system SHALL deploy directly without intermediate workflows
3. WHEN deployment status is checked THEN the system SHALL provide status in a single workflow instead of multiple workflows
4. WHEN troubleshooting is needed THEN the system SHALL have clear workflow dependencies without circular references
5. WHEN maintenance is required THEN the system SHALL have fewer than 3 active workflows total for current cloud-only deployment

### Requirement 4

**User Story:** As a developer, I want faster deployment cycles with reduced complexity, so that changes reach production quickly and reliably.

#### Acceptance Criteria

1. WHEN changes are pushed THEN the system SHALL complete deployment in under 15 minutes for typical changes
2. WHEN builds are triggered THEN the system SHALL use efficient caching and parallel execution
3. WHEN deployment orchestration runs THEN the system SHALL eliminate unnecessary waiting and coordination steps
4. WHEN version management executes THEN the system SHALL complete in under 2 minutes
5. WHEN multiple services are deployed THEN the system SHALL deploy them concurrently where possible

### Requirement 5

**User Story:** As a team lead, I want reliable AI-powered deployment decisions without fallback mechanisms, so that the system maintains high standards and fails fast when AI analysis cannot be completed.

#### Acceptance Criteria

1. WHEN AI analysis is unavailable THEN the system SHALL fail the workflow and require manual intervention
2. WHEN AI analysis fails THEN the system SHALL fail the workflow and provide clear error messages
3. WHEN AI service has rate limits THEN the system SHALL implement retry logic with exponential backoff before failing
4. WHEN deployment decisions are made THEN the system SHALL log AI reasoning and require successful AI analysis
5. WHEN troubleshooting is needed THEN the system SHALL provide clear logs of AI analysis results and failure reasons

### Requirement 6

**User Story:** As a developer, I want consolidated build and deployment workflows, so that I don't need to monitor multiple workflows for a single change.

#### Acceptance Criteria

1. WHEN a change is deployed THEN the system SHALL use a single primary workflow for the complete process
2. WHEN build status is checked THEN the system SHALL show progress in one workflow instead of multiple orchestrated workflows
3. WHEN deployment fails THEN the system SHALL show the failure in the primary workflow without cross-workflow dependencies
4. WHEN logs are reviewed THEN the system SHALL provide complete deployment logs in a single workflow run
5. WHEN deployment succeeds THEN the system SHALL show success status in one place

### Requirement 7

**User Story:** As a DevOps engineer, I want simplified branch management without platform-specific branches, so that git history remains clean and manageable.

#### Acceptance Criteria

1. WHEN deployment is triggered THEN the system SHALL deploy directly from the main branch
2. WHEN cloud deployment is needed THEN the system SHALL deploy without creating platform-specific branches
3. WHEN version tags are created THEN the system SHALL tag the main branch with simple semantic version tags
4. WHEN git history is reviewed THEN the system SHALL not create automated commits for branch management
5. WHEN rollback is needed THEN the system SHALL rollback using main branch commits and semantic version tags

### Requirement 8

**User Story:** As a system administrator, I want deterministic deployment decisions based on file changes, so that deployment behavior is predictable and debuggable.

#### Acceptance Criteria

1. WHEN files in web/, lib/, services/, k8s/, config/ directories change THEN the system SHALL trigger cloud deployment
2. WHEN authentication-related files change THEN the system SHALL always trigger cloud deployment
3. WHEN only documentation or non-functional files change THEN the system SHALL skip deployment
4. WHEN deployment decisions are made THEN the system SHALL log the file patterns that triggered deployment
5. WHEN future platform support is added THEN the system SHALL extend file pattern matching for desktop and mobile builds