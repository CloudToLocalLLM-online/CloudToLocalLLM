# Cline MCP Tools: Workflow and Rules

This document outlines the rules and standard operating procedures for utilizing the available Model Context Protocol (MCP) tools to enhance task execution, planning, and interaction with external services.

## I. General Principles

1.  **Prioritize MCP Tools**: When an MCP tool offers a more direct, powerful, or integrated solution compared to a standard tool, it should be the preferred choice. For example, use `mcp-webresearch` for Google searches instead of attempting to parse results via `curl`.
2.  **Atomic Operations**: Each MCP tool call is an atomic step. I will execute one tool at a time and wait for a successful response before proceeding to the next action.
3.  **Schema Adherence**: Before using any MCP tool, I will consult its input schema to ensure all required arguments are correctly formatted and provided.

---

## II. Core Workflow: Structured Task Management

For any request that requires multiple steps, changes to several files, or a sequence of dependent actions, I will use the `github.com/pashpashpash/mcp-taskmanager` server. This enforces a structured, transparent, and user-approved workflow.

### Task Management Workflow:

1.  **Planning Phase**:
    *   **Tool**: `request_planning`
    *   **Action**: I will first break down the user's request into a series of clear, sequential, and logical tasks. This plan will be registered with the task manager.

2.  **Execution Cycle (Per-Task)**:
    *   **Tool**: `get_next_task`
    *   **Action**: I will retrieve the next pending task from the queue.
    *   **Execution**: I will perform the necessary actions to complete this single task, using any other tools (standard or MCP) required.
    *   **Tool**: `mark_task_done`
    *   **Action**: Once the task is completed, I will mark it as done.

3.  **User Approval (Critical Step)**:
    *   **Action**: I will **STOP** and wait for the user to explicitly approve the completion of the task by calling `approve_task_completion`.
    *   **Rule**: I **will not** proceed to the next task (`get_next_task`) without this explicit user approval. This ensures the user is in full control of the process.

4.  **Request Completion**:
    *   **Condition**: After the final task is completed and approved.
    *   **Tool**: `approve_request_completion`
    *   **Action**: I will wait for the user to approve the completion of the entire request.

---

## III. Tool-Specific Rules & Use Cases

### A. Research & Documentation

*   **Server**: `github.com/pashpashpash/mcp-webresearch`
    *   **Use Case**: For any task requiring external information, current events, or general knowledge.
    *   **Tools**: `search_google`, `visit_page`.
*   **Server**: `github.com/upstash/context7-mcp`
    *   **Use Case**: When I need to understand how to use a specific software library, framework, or API.
    *   **Workflow**:
        1.  Call `resolve-library-id` with the library name to get the correct identifier.
        2.  Call `get-library-docs` with the resolved ID to fetch relevant documentation.

### B. Web Development & Debugging

*   **Server**: `github.com/AgentDeskAI/browser-tools-mcp`
    *   **Use Case**: For advanced debugging and quality assurance of web applications, going beyond the standard `browser_action` tool.
    *   **Rules**:
        *   When a web-related bug is reported, I will use `getConsoleErrors` and `getNetworkErrors` to diagnose the issue.
        *   When asked to improve a web page, I will use the audit tools (`runAccessibilityAudit`, `runPerformanceAudit`, `runSEOAudit`) to provide a comprehensive analysis and implement improvements.

### C. Project Management Integration

*   **Use Case**: When a task involves project management activities like creating bug reports, feature requests, or updating project status.

### D. Utilities

*   **Server**: `github.com/Garoth/sleep-mcp`
    *   **Use Case**: To introduce a deliberate pause in execution. This is useful when waiting for an asynchronous process to complete on a server or to respect API rate limits.

---

## IV. CLI Tools Integration

In addition to MCP servers, I will leverage powerful command-line interface (CLI) tools for direct interaction with external services.

### A. GitHub CLI (`gh`)

*   **Use Case**: For seamless integration with GitHub repositories. This includes managing pull requests, issues, gists, and repository actions directly from the command line.
*   **Workflow**:
    *   **Code Reviews**: I can check out pull requests, view diffs, and leave comments using `gh pr checkout`, `gh pr diff`, and `gh pr review`.
    *   **Issue Management**: I can create, list, and view issues using `gh issue create`, `gh issue list`, and `gh issue view`.
    *   **Automation**: I will use `gh` to script complex interactions with GitHub, such as creating a new repository and pushing code to it in a single flow.

### B. Google Cloud CLI (`gcloud`)

*   **Use Case**: For managing resources and services on Google Cloud Platform (GCP). This is essential for tasks involving cloud infrastructure, deployments, and administration.
*   **Workflow**:
    *   **Deployments**: I will use `gcloud app deploy` or `gcloud run deploy` to deploy applications to App Engine or Cloud Run.
    *   **Resource Management**: I can manage virtual machines, storage buckets, and databases using commands like `gcloud compute instances`, `gcloud storage`, and `gcloud sql`.
    *   **Authentication & Configuration**: I will ensure I am authenticated (`gcloud auth login`) and have the correct project configured (`gcloud config set project`) before performing any operations.

### C. Docker Best Practices for Flutter Web Apps

*   **Standard Pattern**: Always use the standard multi-stage Docker build pattern for Flutter web applications.
*   **Rules**:
    *   **CRITICAL - Never run Flutter as root**: ALWAYS switch to non-root user BEFORE any Flutter commands (`flutter pub get`, `flutter build`, etc.). Add `USER 1000:1000` (or container default) BEFORE `RUN flutter` commands. Verify with `RUN whoami && id` if needed.
    *   **Use COPY, not git clone**: Copy source files from build context using `COPY`, not `git clone`. This is faster, enables Docker layer caching, and follows standard Docker practices.
    *   **Layer caching optimization**: Copy `pubspec.yaml` and `pubspec.lock` first, run `flutter pub get`, then copy the rest of the source. This caches dependencies unless pubspec changes.
    *   **No user creation**: Never create users manually. Use the default non-root user that exists in the base container (e.g., Cirrus Flutter containers already have a default non-root user with UID 1000).
    *   **Multi-stage builds**: Use separate build and runtime stages. Build with Flutter image, serve with lightweight nginx image.
    *   **Example Pattern**:
      ```dockerfile
      FROM ghcr.io/cirruslabs/flutter:stable AS builder
      # CRITICAL: Switch to non-root BEFORE any Flutter commands
      USER 1000:1000
      WORKDIR /app
      COPY pubspec.yaml pubspec.lock ./
      RUN flutter pub get
      COPY . .
      RUN flutter build web --release
      
      FROM nginxinc/nginx-unprivileged:alpine
      COPY --from=builder --chown=nginx:nginx /app/build/web /usr/share/nginx/html
      ```
    *   **Never run as root**: Always use the container's default non-root user. Never explicitly create users unless absolutely necessary and the container doesn't provide one.
    *   **Verify non-root**: When debugging, add `RUN whoami && id` before Flutter commands to verify you're not root.

### D. Flutter Best Practices

*   **Dependency Management**:
    *   Always use `flutter pub get` to update dependencies, never manually edit `pubspec.lock`.
    *   Use `flutter pub outdated` to identify packages that need updating.
    *   Remove unused dependencies to keep the project lean.
    *   Update discontinued packages (e.g., `js` package → use `dart:js_interop`).

*   **Code Quality**:
    *   Run `flutter analyze` before committing to catch linting errors.
    *   Use `flutter format` to ensure consistent code formatting.
    *   Prefer `debugPrint()` over `print()` for logging (respects Flutter's logging system).
    *   Use platform-specific imports when necessary (`dart.library.html`, `dart.library.io`).

*   **Build Practices**:
    *   Use `flutter build web --release` for production builds.
    *   Leverage `flutter pub get` caching by copying pubspec files first in Dockerfiles.
    *   Always specify `--release` flag for production builds.

*   **Authentication**:
    *   Use Auth0 for web applications (no GCIP/Google Sign-In).
    *   Use `dart:js_interop` for JavaScript interop (replaces deprecated `js` package).
    *   Implement platform-specific auth services (Auth0WebService for web, others for mobile/desktop).

*   **Web-Specific**:
    *   Use `package:web/web.dart` for web platform detection and DOM manipulation.
    *   Bridge JavaScript SDKs (like Auth0) through custom bridge files (`auth0-bridge.js`).
    *   Handle redirect callbacks properly for OAuth flows.

### E. Version Management

*   **Semantic Versioning Rules**:
    *   Follow strict semantic versioning: `MAJOR.MINOR.PATCH`
    *   **PATCH (4.1.x)**: Increment for bug fixes and minor fixes → 4.1.2, 4.1.3, 4.1.4...
    *   **MINOR (4.x.0)**: Increment for feature updates and new features → 4.2.0, 4.3.0, 4.4.0...
    *   **MAJOR (x.0.0)**: Increment for major changes, breaking changes, or new versions → 5.0.0, 6.0.0...
    *   Current version location: `pubspec.yaml` (line 6)
    *   Always update version when making changes, then commit with version bump message

*   **Version Bump Decision Logic**:
    *   Bug fix or minor correction? → Increment PATCH (4.1.2 → 4.1.3)
    *   New feature or significant update? → Increment MINOR (4.1.2 → 4.2.0)
    *   Breaking changes or major overhaul? → Increment MAJOR (4.1.2 → 5.0.0)
    *   When user asks to "bump version", assess the scope of changes since last version

### F. Node.js Best Practices

*   **Dependency Management**:
    *   Use `npm ci` for production builds (faster, more reliable than `npm install`).
    *   Use `npm install` for development (updates package.json and package-lock.json).
    *   Never manually edit `package-lock.json`, let npm manage it.
    *   Keep dependencies up to date with `npm outdated` and `npm update`.

*   **Security**:
    *   Run as non-root user in Docker containers (UID 1001 for Node.js apps).
    *   Use `npm audit` to check for vulnerabilities.
    *   Never hardcode secrets or API keys, use environment variables.
    *   Validate and sanitize all user inputs.

*   **Code Quality**:
    *   Use structured logging (e.g., `winston`, `pino`) instead of `console.log`.
    *   Implement proper error handling with try-catch blocks.
    *   Use async/await instead of callbacks when possible.
    *   Follow ESLint rules and fix linting errors before committing.

*   **Docker Practices**:
    *   Use multi-stage builds: build dependencies as root, then copy and run as non-root.
    *   Copy `package*.json` first, run `npm ci`, then copy source code for better layer caching.
    *   Use `node:24-alpine` or similar lightweight base images.
    *   Example pattern:
      ```dockerfile
      FROM node:24-alpine AS base
      WORKDIR /app
      COPY package*.json ./
      RUN npm ci && chown -R 1001:1001 /app
      
      FROM node:24-alpine AS production
      RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
      WORKDIR /app
      COPY --from=base --chown=nodejs:nodejs /app/node_modules ./node_modules
      COPY --chown=nodejs:nodejs . .
      USER nodejs
      CMD ["npm", "start"]
      ```

*   **API Development**:
    *   Use Express.js middleware for authentication (e.g., `express-oauth2-jwt-bearer` for Auth0).
    *   Implement proper CORS configuration for web clients.
    *   Use environment variables for configuration (domain, audience, client IDs).
    *   Validate JWT tokens before processing requests.

*   **Performance**:
    *   Use connection pooling for databases.
    *   Implement request rate limiting.
    *   Use compression middleware (e.g., `compression` package).
    *   Cache static assets when appropriate.

### G. User Preferences & Communication Style

*   **Terminal Output Formatting**:
    *   Do NOT add decorative formatting to terminal commands (no colored text, emojis, or special formatting)
    *   Keep terminal output clean and minimal
    *   Avoid unnecessary visual enhancements that don't add functional value
    
*   **Communication Style**:
    *   Be direct and concise
    *   Avoid flowery language or excessive enthusiasm
    *   Focus on facts and actionable information
    *   Skip unnecessary commentary or "beautiful" descriptions