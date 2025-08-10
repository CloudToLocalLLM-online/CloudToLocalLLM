# MCP Development Workflow

This document outlines the best practices and a standardized workflow for using Model Context Protocol (MCP) tools in the CloudToLocalLLM project. Following these guidelines will ensure that development is efficient, consistent, and produces high-quality results.

## Core Principles

1.  **Iterative Development**: Always work in small, incremental steps. Use one tool at a time and wait for the result before proceeding to the next step. This allows for course correction and reduces the risk of cascading errors.

2.  **Context is Key**: Before making any changes, gather as much context as possible. Use tools like `list_files`, `read_file`, and `search_files` to understand the existing codebase, file structure, and relevant logic.

3.  **Precision Over Speed**: When modifying files, prefer `replace_in_file` for targeted edits. Use `write_to_file` only for creating new files or when the changes are so extensive that a full rewrite is simpler and less error-prone.

4.  **Verify, Then Trust**: After making changes, verify them. This could involve running tests, using the `browser_action` tool to check the UI, or simply re-reading the file to ensure the changes were applied correctly.

## Standard MCP Workflow

Follow this workflow for any development task using MCP tools.

### 1. Task Analysis
- **Objective**: Fully understand the user's request.
- **Action**: If the request is ambiguous, use the `ask_followup_question` tool to clarify requirements. Do not proceed until the task is well-understood.

### 2. Code Exploration
- **Objective**: Identify the relevant files and code sections.
- **Actions**:
    - Use `list_files` to explore the directory structure.
    - Use `read_file` to examine the contents of specific files.
    - Use `search_files` to find all occurrences of a function, variable, or pattern across the codebase.
    - Use `list_code_definition_names` to get a high-level overview of the code structure.

### 3. Implementation
- **Objective**: Make the required code changes.
- **Actions**:
    - For small, targeted changes, use `replace_in_file`.
    - For creating new files or significant rewrites, use `write_to_file`.
    - Use one tool call per logical change. For example, if you need to modify three files, use three separate `replace_in_file` calls, one for each file.

### 4. Verification
- **Objective**: Ensure the changes work as expected and have not introduced regressions.
- **Actions**:
    - **Run automated tests**: Use `execute_command` to run existing test suites.
    - **Manual Verification**: For UI changes, use the `browser_action` tool to launch the application and visually inspect the changes.
    - **Linting and Analysis**: Run `flutter analyze` or other static analysis tools to check for code quality issues.

### 5. Committing Changes
- **Objective**: Save the work to version control.
- **Actions**:
    - Use the `execute_command` tool to run `git` commands directly.
        - `git status` to review changes.
        - `git add <file>` to stage changes.
        - `git commit -m "message"` to commit with a descriptive message.
    - Alternatively, use the existing PowerShell scripts (`push-dev.ps1`) for a streamlined commit process.

## Best Practices for Common Tools

- **`execute_command`**:
    - Always explain what the command does.
    - Prefer single, chained commands over creating temporary scripts.
    - Set `requires_approval` to `true` for any command that modifies the system or installs software.

- **`replace_in_file`**:
    - Keep `SEARCH` blocks as small as possible while ensuring they are unique.
    - Include enough context lines in the `SEARCH` block to avoid ambiguity.
    - When making multiple changes to a single file, use multiple `SEARCH/REPLACE` blocks in the correct order.

- **`browser_action`**:
    - Always start with `launch` and end with `close`.
    - Base `click` coordinates on the most recent screenshot.
    - Use console logs to debug issues.

## Example Workflow: Adding a New Feature

**Task**: Add a new button to the home screen that displays a greeting.

1.  **Analysis**: The task is clear. No follow-up questions needed.

2.  **Exploration**:
    - `list_files --path lib/screens` to find the home screen file.
    - `read_file --path lib/screens/home_screen.dart` to understand its structure.

3.  **Implementation**:
    - `replace_in_file` to add a new `ElevatedButton` to the `build` method of `home_screen.dart`.
    - The button's `onPressed` will call a new function, `_showGreeting()`.
    - `replace_in_file` again to add the `_showGreeting` function, which uses a `SnackBar` to display "Hello!".

4.  **Verification**:
    - `execute_command --command "flutter run"` to start the app.
    - `browser_action --action launch` to open the app.
    - `browser_action --action click` on the new button.
    - Visually confirm the "Hello!" message appears in the screenshot.
    - `browser_action --action close`.

5.  **Committing**:
    - `execute_command --command "git add lib/screens/home_screen.dart"`
    - `execute_command --command "git commit -m 'feat: Add greeting button to home screen'"`

By following this workflow, development with MCP tools will be structured, predictable, and less prone to errors.
