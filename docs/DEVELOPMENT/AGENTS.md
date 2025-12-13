# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Stack
- **Frontend**: Flutter app (cross-platform: Windows, Linux, Web) using Provider + GetIt for DI
- **Backend**: Node.js services with Express.js, PostgreSQL for server sessions
- **Client Storage**: Local SQLite/IndexedDB for conversation storage
- **Auth**: Auth0 (auth provider agnostic, web uses JS bridge `auth0-bridge.js`, desktop uses native flows)
- **Local Models**: Ollama/LM Studio integrations using OpenAI-compatible APIs
- **Cloud**: Azure AKS, Docker Hub registry, Cloudflare DNS/SSL
- **Error Tracking**: Sentry Flutter integration
- **Testing**: Jest (Node.js), Flutter test framework, Playwright (e2e)

## Essential Commands
- **Flutter**: `flutter pub get`, `flutter run -d windows` / `-d chrome`, `flutter analyze`, `flutter test`
- **Node.js**: `npm install` (dev) / `npm ci` (prod), `npm run dev` (nodemon), `npm test` (Jest with experimental-vm-modules)
- **Linting**: `flutter analyze`, `eslint` + `npm audit` before pushing
- **Formatting**: `flutter format .` before committing

## Critical Patterns
- **DI**: Services registered in `lib/di/locator.dart` via `setupCoreServices()` (pre-auth) and `setupAuthenticatedServices()` (post-auth)
- **MCP Configs**: Workspace `.kiro/settings/mcp.json`, user-level `~/.kiro/settings/mcp.json`, Docker MCP gateway
- **Docker**: NEVER run Flutter as root - switch to `USER 1000:1000` before any `flutter` command; Node.js as UID 1001
- **Layer Caching**: Copy `pubspec.yaml`/`pubspec.lock` first, run `flutter pub get`, then copy source
- **Testing**: Jest tests in `test/` directory (not `__tests__`), run single test with `node --experimental-vm-modules ./node_modules/jest/bin/jest.js <test-file>`
- **Property Testing**: Use `fast-check` for property-based testing in Node.js services
- **Versioning**: Update `pubspec.yaml` and `package.json` with every release following Semantic Versioning
- **Commit Messages**: Conventional commits with agent prefix (e.g., `ai(Kiro): update provider DI`)
- **K8s**: Configs in `k8s/`, use `secrets.yaml.template`, Azure AKS deployment
- **Azure**: Use service principal for GitHub Actions authentication, ARM templates for infrastructure
- **Flutter Web**: Use `package:web/web.dart` and `dart:js_interop` instead of deprecated `js` package
- **Error Handling**: Sentry integration for error tracking and performance monitoring

## AI Agent Rules
- Follow Kiro agent patterns and response style guidelines
- Use MCP tools for Docker Hub, Context7, Grafana, and Playwright operations
- Respect `.cursor/rules/`, `.clinerules/`, and `.github/copilot-instructions.md`
- Use property-based testing patterns for complex business logic
- Follow Azure security best practices (service principals, least privilege, encryption)
- Monitor costs when working with Azure resources

## Mode-Specific Rules
- See `.roo/rules-code/AGENTS.md` for coding patterns
- See `.roo/rules-debug/AGENTS.md` for debugging guidance
- See `.roo/rules-ask/AGENTS.md` for documentation context
- See `.roo/rules-architect/AGENTS.md` for architectural constraints
