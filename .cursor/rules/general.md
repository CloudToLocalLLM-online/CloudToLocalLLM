# General Development Rules (Kilocode Standards)

## Mandatory Methodology: Documentation-First

**ALL development tasks MUST begin with a review and update of relevant documentation before code execution.**

- **Context Acquisition**: Review `docs/` and `.kiro/steering/` files relevant to the task.
- **Preemptive Documentation**: Appropriate documentation updates MUST precede or accompany code changes to ensure a single, cohesive source of truth.
- **Technical Excellence**: All actions as Kilocode must align with defined git workflows, CI/CD guidelines, and architectural structures.

## Primary Framework: Sequential Thinking

**The Sequential Thinking MCP is the MANDATORY primary framework for all complex tasks.**

- **Scope**: Required for complex problem-solving, systematic debugging, architectural tasks, and multi-component analysis.
- **Workflow**: Initialize the framework to break down the problem, hypothesize solutions, and iteratively verify assumptions.
- **Analysis Before Action**: Ensure systematic reasoning is applied before committing to tool-based implementation.

## Code Changes

- Always fix linter errors before committing.
- Run analysis tools (`flutter analyze`, ESLint) before pushing code.
- Keep commits focused and atomic - one logical change per commit.

## File Management

- Never delete or modify files without explicit user request.
- When refactoring, preserve backward compatibility when possible.
- Update documentation when making architectural changes or implementing new features.

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

