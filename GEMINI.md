# Gemini Agent Project Overview

This document outlines the Gemini code assistant's understanding of the project and its plan for contributing.

## Project Goal

The primary objective of this project is to develop a robust and scalable application that provides a seamless user experience. This will be achieved by focusing on a clean architecture, comprehensive testing, and a well-defined development workflow.

## Key Technologies

The project utilizes a diverse set of technologies to achieve its goals. These include:

*   **Frontend:** Flutter
*   **Backend:** Node.js
*   **Database:** Not immediately clear, but likely a relational database.
*   **Deployment:** Docker, potentially with orchestration using Docker Compose.
*   **CI/CD:** GitHub Actions
*   **Project Management:** 

## Development Environment and MCP Tools

I am operating within a Visual Studio Code environment and have access to three dedicated MCP (Model Context Protocol) servers. These servers provide a suite of powerful, specialized tools that allow me to perform advanced tasks, including:

*   **Structured Task Management**: Breaking down complex requests into a sequence of user-approved tasks.
*   **Advanced Web Research**: Performing targeted Google searches and analyzing web page content.
*   **Library Documentation**: Fetching and understanding documentation for specific software libraries and frameworks.
*   **Web Development & Debugging**: Diagnosing web application issues by analyzing console and network errors, and running performance and accessibility audits.
*   **Project Management Automation**: Integrating directly with project management tools to create and manage issues, projects, and other project-related tasks.
*   **CLI Tool Integration**: Leveraging powerful command-line tools like `gh` (GitHub CLI) and `gcloud` (Google Cloud CLI) for seamless interaction with external services.

## Development Plan

To effectively contribute to the project, I will adhere to the following plan:

1.  **Understand the Codebase:** I will thoroughly analyze the existing code to understand its structure, patterns, and conventions.
2.  **Follow Established Practices:** I will follow the project's existing development workflow, including testing and documentation standards.
3.  **Implement New Features:** I will implement new features as requested, ensuring they are well-tested and documented.
4.  **Fix Bugs:** I will identify and fix bugs in the existing code, providing clear and concise bug reports.
5.  **Improve Performance:** I will identify and address performance bottlenecks in the application.
6.  **Enhance Security:** I will identify and address security vulnerabilities in the application.

By following this plan, I will ensure that my contributions are of high quality and align with the project's goals.

## Available Tools

Here are some of the tools I can use to help with development:

*   **`list_directory(path)`**: Lists the files and directories in a specified path.
    *   *Example:* `list_directory(path='/home/rightguy/dev/CloudToLocalLLM/lib/services')`
*   **`read_file(absolute_path)`**: Reads the content of a file.
    *   *Example:* `read_file(absolute_path='/home/rightguy/dev/CloudToLocalLLM/pubspec.yaml')`
*   **`write_file(file_path, content)`**: Writes new content to a file, overwriting existing content.
    *   *Example:* `write_file(file_path='/home/rightguy/dev/CloudToLocalLLM/docs/new_feature.md', content='# New Feature Documentation')`
*   **`replace(file_path, old_string, new_string)`**: Replaces specific text within a file.
    *   *Example:* `replace(file_path='/home/rightguy/dev/CloudToLocalLLM/lib/main.dart', old_string='old_function_name()', new_string='new_function_name()')`
*   **`run_shell_command(command)`**: Executes a shell command in the terminal.
    *   *Example:* `run_shell_command(command='flutter pub get')`
*   **`search_file_content(pattern, include)`**: Searches for a specific pattern within files.
    *   *Example:* `search_file_content(pattern='Future<void>', include='**/*.dart')`
*   **`glob(pattern)`**: Finds files matching a glob pattern.
    *   *Example:* `glob(pattern='**/*.g.dart')`
*   **`gh [COMMAND]`**: Interacts with the GitHub CLI.
    *   *Example:* `run_shell_command(command='gh issue list')`

I will use these tools to carry out the development plan and assist with your requests.
