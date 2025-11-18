# Workspace Development Guidelines for CloudToLocalLLM

This document outlines specific development guidelines and best practices for the `e:\dev\CloudToLocalLLM` workspace. These rules are intended to ensure consistency, maintainability, and security across the project.

## 1. General Development Practices

*   **Code Quality**:
    *   **MANDATORY**: Always run `flutter analyze` (for Flutter) and `npm run lint` (for Node.js) to verify linter issues **before pushing** to GitHub. This step is manual and crucial as the CI workflow assumes clean code.
    *   Use `flutter format` and appropriate Node.js formatters to ensure consistent code formatting.
    *   Implement robust error handling with try-catch blocks and structured logging.
*   **Dependency Management**:
    *   For Flutter, use `flutter pub get` to manage dependencies and `flutter pub outdated` to identify updates.
    *   For Node.js, use `npm ci` for production builds and `npm install` for development. Keep dependencies updated with `npm outdated` and `npm update`.
    *   Remove unused dependencies to keep the project lean.
*   **Version Control**:
    *   Adhere strictly to Semantic Versioning (`MAJOR.MINOR.PATCH`) for all project components.
    *   Update the version in `pubspec.yaml` (for Flutter) or `package.json` (for Node.js) with every release, following the version bump decision logic (PATCH for bug fixes, MINOR for features, MAJOR for breaking changes).
    *   Use clear and descriptive commit messages.

## 2. Flutter Web Application Development

*   **Dockerization**:
    *   Always use multi-stage Docker builds for Flutter web applications.
    *   **CRITICAL**: Ensure Flutter commands are executed by a non-root user (e.g., `USER 1000:1000`) within the Dockerfile.
    *   Optimize Docker layer caching by copying `pubspec.yaml` and `pubspec.lock` before running `flutter pub get`.
    *   Serve built web assets with a lightweight Nginx image (e.g., `nginxinc/nginx-unprivileged:alpine`).
*   **Web-Specific Features**:
    *   Utilize `package:web/web.dart` for web platform detection and DOM manipulation.
    *   Bridge JavaScript SDKs (like Auth0) through custom bridge files (e.g., `auth0-bridge.js`).
    *   Handle OAuth redirect callbacks correctly.
*   **Authentication**:
    *   Auth0 is the preferred authentication method for web applications.
    *   Use `dart:js_interop` for JavaScript interop, replacing the deprecated `js` package.

## 3. Node.js Backend Development

*   **Dockerization**:
    *   Employ multi-stage Docker builds, building dependencies as root and running the application as a non-root user (e.g., UID 1001).
    *   Copy `package*.json` first, run `npm ci`, then copy source code for efficient layer caching.
    *   Use lightweight base images like `node:24-alpine`.
*   **Security**:
    *   Run Node.js applications as a non-root user in Docker containers.
    *   Use `npm audit` regularly to check for vulnerabilities.
    *   Never hardcode sensitive information; use environment variables for secrets and API keys.
    *   Implement input validation and sanitization.
*   **API Development**:
    *   Use Express.js middleware for authentication (e.g., `express-oauth2-jwt-bearer` for Auth0).
    *   Configure CORS properly for web clients.
    *   Validate JWT tokens before processing requests.

## 4. Kubernetes (k8s) Deployment

*   **Configuration**:
    *   All Kubernetes configurations are located in the `k8s/` directory.
    *   Ensure `secrets.yaml.template` is used as a template and actual secrets are managed securely (e.g., via Azure Key Vault integration as described in `k8s/AZURE_KEYVAULT_SETUP.md`).
    *   Follow guidelines in `k8s/README.md` for general Kubernetes deployment.
*   **SSL/TLS**:
    *   Refer to `k8s/README_AZURE_SSL.md` and `k8s/README_SSL_ALTERNATIVES.md` for SSL/TLS configuration and certificate management.

## 5. Documentation

*   Maintain up-to-date and clear documentation in the `docs/` directory for all aspects of the project, including architecture, deployment, development workflows, and features.
*   Ensure `docs/MCP_WORKFLOW_AND_RULES.md` accurately reflects current operational procedures and tool usage.
