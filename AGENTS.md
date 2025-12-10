# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Stack
- **Frontend**: Flutter app (cross-platform: Windows, Linux, Web) using provider + GetIt for DI
- **Backend**: Node.js services with Express.js, PostgreSQL for server sessions
- **Client Storage**: Local SQLite/IndexedDB for conversation storage
- **Auth**: Auth0 (web uses JS bridge `auth0-bridge.js`, desktop uses native flows)
- **Local Models**: Ollama/LM Studio integrations using OpenAI-compatible APIs

## Essential Commands
- **Flutter**: `flutter pub get`, `flutter run -d windows` / `-d chrome`, `flutter analyze`, `flutter test`
- **Node.js**: `npm install` (dev) / `npm ci` (prod), `npm run dev` (nodemon), `npm test` (Jest with experimental-vm-modules)
- **Linting**: `flutter analyze`, `eslint` + `npm audit` before pushing
- **Formatting**: `flutter format .` before committing

## Critical Patterns
- **DI**: Services registered in `lib/di/locator.dart` via `setupCoreServices()` (pre-auth) and `setupAuthenticatedServices()` (post-auth)
- **MCP Configs**: Workspace `mcp.json`, user-level `%APPDATA%/Code/User/mcp.json`, wiring in `config/mcp/`
- **Docker**: NEVER run Flutter as root - switch to `USER 1000:1000` before any `flutter` command; Node.js as UID 1001
- **Layer Caching**: Copy `pubspec.yaml`/`pubspec.lock` first, run `flutter pub get`, then copy source
- **Testing**: Jest tests in `test/` directory (not `__tests__`), run single test with `node --experimental-vm-modules ./node_modules/jest/bin/jest.js <test-file>`
- **Versioning**: Update `pubspec.yaml` and `package.json` with every release following Semantic Versioning
- **Commit Messages**: Conventional commits with agent prefix (e.g., `ai(Cursor): update provider DI`)
- **K8s**: Configs in `k8s/`, use `secrets.yaml.template`, Azure Key Vault integration
- **Flutter Web**: Use `package:web/web.dart` and `dart:js_interop` instead of deprecated `js` package

## AI Agent Rules
- Use `x-ai/grok-code-fast-1` model for code generation and analysis
- Use `manage_todo_list` tool for complex, multi-step work
- Respect `.cursor/rules/`, `.clinerules/`, and `.github/copilot-instructions.md`
- MCP remote access: `npx -y mcp-remote@latest https://mcp.sentry.dev/mcp` for OAuth-enabled clients

## Mode-Specific Rules
- See `.roo/rules-code/AGENTS.md` for coding patterns
- See `.roo/rules-debug/AGENTS.md` for debugging guidance
- See `.roo/rules-ask/AGENTS.md` for documentation context
- See `.roo/rules-architect/AGENTS.md` for architectural constraints
