# Cursor AI Rules and Workflows

This directory contains rules and workflows for Cursor AI assistant to follow when working on this codebase.

## Structure

- `.cursor/rules/` - Specific rules for different technologies and domains
- `.cursor/workflow.md` - General workflow patterns and procedures

## Rules

### `docker.md`
Docker best practices for Flutter web apps and Node.js applications. Includes standard patterns for multi-stage builds, layer caching, and non-root user configuration.

### `flutter.md`
Flutter development best practices including dependency management, code quality, build practices, authentication patterns, and web-specific guidance.

### `nodejs.md`
Node.js best practices covering dependency management, security, code quality, API development, and performance optimization.

### `general.md`
General development rules applicable to all parts of the codebase, including code changes, file management, security, and git workflow.

## Workflow

See `workflow.md` for common task patterns, error handling procedures, refactoring workflows, and deployment processes.

## Usage

Cursor AI will automatically reference these rules and workflows when:
- Making code changes
- Creating or modifying Dockerfiles
- Adding dependencies
- Fixing errors
- Refactoring code
- Deploying applications

## Updates

When updating these rules:
1. Make changes to the appropriate rule file
2. Test that the rules make sense in context
3. Commit with message: `docs: update Cursor AI rules`
4. Push to repository

