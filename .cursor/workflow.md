# Cursor AI Workflow

## General Workflow Principles

1. **Understand First**: Read relevant files and understand the context before making changes.
2. **Plan Before Acting**: For complex tasks, break them down into steps.
3. **Verify Changes**: Check for linting errors and verify functionality after changes.
4. **Document Updates**: Update relevant documentation when making significant changes.

## Common Task Patterns

### Adding a New Dependency

1. Check if package exists and is maintained
2. Add to `pubspec.yaml` (Flutter) or `package.json` (Node.js)
3. Run dependency installation command
4. Update imports in code
5. Run linter/analyzer to check for issues

### Fixing Linter Errors

1. Run linter: `flutter analyze` or `npm run lint`
2. Read error messages carefully
3. Fix errors one at a time
4. Re-run linter to verify fixes
5. Commit fixes with appropriate message

### Dockerfile Changes

1. Follow Docker best practices (see `.cursor/rules/docker.md`)
2. Test build locally if possible
3. Ensure non-root user is used
4. Optimize layer caching
5. Verify final image size is reasonable

### Authentication Changes

1. Never hardcode credentials
2. Use environment variables or configuration files
3. For Auth0: Update domain, audience, client ID in config files
4. Test authentication flow end-to-end
5. Update documentation if auth patterns change

## Error Handling Workflow

1. **Identify**: Read full error message and stack trace
2. **Locate**: Find the file and line causing the error
3. **Understand**: Research the error if unfamiliar
4. **Fix**: Apply fix following best practices
5. **Verify**: Test that the fix resolves the error
6. **Document**: Add comments if fix is non-obvious

## Refactoring Workflow

1. **Scope**: Understand what needs refactoring
2. **Impact**: Identify all files affected
3. **Plan**: Break refactoring into logical steps
4. **Execute**: Make changes incrementally
5. **Test**: Verify functionality is preserved
6. **Cleanup**: Remove unused code and update docs

## Deployment Workflow

1. **Check Requirements**: Ensure all dependencies are available
2. **Build**: Run build commands and verify success
3. **Test**: Run tests if available
4. **Lint**: Fix any linting errors
5. **Commit**: Commit changes with clear message
6. **Push**: Push to repository (user approval required)

## User Interaction

- Always wait for explicit user approval before:
  - Pushing to repository
  - Making breaking changes
  - Deleting files
  - Changing authentication patterns

- Provide clear explanations:
  - What was changed
  - Why it was changed
  - How to verify the changes work

