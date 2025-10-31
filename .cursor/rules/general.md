# General Development Rules

## Code Changes

- Always fix linter errors before committing.
- Run analysis tools (`flutter analyze`, ESLint) before pushing code.
- Keep commits focused and atomic - one logical change per commit.

## File Management

- Never delete or modify files without explicit user request.
- When refactoring, preserve backward compatibility when possible.
- Update documentation when making architectural changes.

## Security

- Never hardcode secrets, API keys, or credentials.
- Use environment variables or secret management systems.
- Always run containers as non-root users.

## User Communication

- When making changes, explain what was done and why.
- If encountering errors, show the full error message.
- Ask for clarification if the request is ambiguous.

## Git Workflow

- Use conventional commit messages: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `ci:`.
- Keep commits focused - one logical change per commit.
- Always push changes when requested by the user.

## Testing

- Fix failing tests before committing.
- Add tests for new features when appropriate.
- Verify changes work as expected before marking complete.

