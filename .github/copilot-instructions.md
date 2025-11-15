# CloudToLocalLLM Copilot Instructions

Guidelines for AI agents contributing to the CloudToLocalLLM project.

## Project Overview

CloudToLocalLLM is a cross-platform Flutter application (Windows, Linux, Web) that provides a unified interface to cloud AI services (OpenAI, Anthropic) and local models (Ollama, LM Studio). The architecture combines:
- **Frontend**: Flutter with `provider` state management (Get_It dependency injection)
- **Backend**: Node.js services with Model Context Protocol SDK
- **Storage**: PostgreSQL for sessions, SQLite/IndexedDB for local data, secure token storage

## Core Architecture Patterns

### Service-Based Architecture (lib/services/)
The app uses a multi-service design with dependency injection:
- **Auth**: `auth_service.dart` (Auth0 via `auth0_web_service.dart`/`auth0_desktop_service.dart`) + `session_storage_service.dart` (PostgreSQL backend)
- **Streaming**: `streaming_chat_service.dart` manages conversations with real-time updates via `StreamingMessage` model
- **Connections**: `connection_manager_service.dart` routes between local/cloud providers
- **AI Providers**: `llm_provider_manager.dart` handles failover; `BaseLLMProvider` defines interface; platform-specific providers in `llm_providers/`
- **Tunneling**: `unified_connection_service.dart` abstracts connection type (Ollama, WebSocket, cloud)

**Pattern**: Services extend `ChangeNotifier` for reactive state; use `RxDart`'s `BehaviorSubject` for streaming state.

### Platform-Specific Code
Uses conditional imports to handle platform differences:
```dart
import 'services/auth0_web_service.dart' if (dart.library.io) 'services/auth0_web_service_stub.dart';
if (kIsWeb) { /* web code */ } else { /* desktop code */ }
```
- Web: Auth0 via JavaScript bridge (`auth0-bridge.js`), `shared_preferences`, no window manager
- Desktop: Auth0 native, `sqflite_common_ffi`, `window_manager`, `tray_manager`

### Data Models
Located in `lib/models/`:
- `User`: `user_model.dart` (Auth0 user data)
- **Conversations**: `conversation.dart`, `message.dart` (stored in SQLite/PostgreSQL)
- **Streaming**: `streaming_message.dart` (progressive chat updates)
- **Configuration**: `provider_configuration.dart` (Ollama, LM Studio, OpenAI-compatible)
- **Errors**: `llm_communication_error.dart`, `ollama_connection_error.dart` (detailed error classification)

## Critical Development Workflows

### Setup & Dependencies
```bash
flutter pub get        # Frontend deps
npm install            # Backend deps (for services/ if present)
flutter analyze        # Lint check (MUST pass before commit)
flutter format .       # Auto-format code
```

### Running
**Desktop**: `flutter run -d windows` or `-d linux`
**Web**: `flutter run -d chrome` (uses Auth0 JS bridge)
**Backend** (if services/): `npm run dev` (nodemon-based)

### Testing
```bash
flutter test                    # Widget & unit tests; uses test_config.dart for platform mocks
npm test                        # E2E tests (Playwright in e2e/)
```
Platform-specific tests require mocking in `test/test_config.dart` (MethodChannel mocks for window_manager, tray_manager, etc.).

### Building
**Release builds must include `--release` flag**:
- Windows: `flutter build windows --release` (requires Inno Setup)
- Linux: `flutter build linux --release`
- Web: `flutter build web --release`
- **Tagging triggers GitHub Actions**: Push `v4.x.x` tag → automatic desktop build + GitHub release

### Deployment
- **Desktop**: GitHub Actions (`.github/workflows/build-release.yml`) on version tags (v4.x.x); creates .exe installer & portable .zip on hosted runners
- **Docker Images**: GitHub Actions (`.github/workflows/build-images.yml`) builds & pushes to Docker Hub on `develop` branch
- **Kubernetes**: GitHub Actions (`.github/workflows/deploy-aks.yml`) deploys to Azure AKS on `main` branch pushes
- **All via GitHub-hosted runners**: No local/self-hosted infrastructure needed

## Project-Specific Conventions

### Code Style & Patterns
1. **Error Handling**: Use typed error classes with classification (e.g., `OllamaConnectionError` with `ErrorClassification` enum)
2. **Logging**: Use `appLogger` (from `utils/logger.dart`) with named contexts: `appLogger.debug('[ServiceName] message')`
3. **State Updates**: Always call `notifyListeners()` after state changes in `ChangeNotifier` services
4. **Comments**: Document non-obvious logic; include `/// dart doc` for public APIs
5. **Imports**: Use relative imports in same module; absolute for cross-module imports

### Cursor Rules (Refer to `.cursor/rules/`)
- **Flutter**: Use `dart:js_interop` (not deprecated `js`), `package:web/web.dart` for DOM access
- **Node.js**: Use `npm ci` for prod; validate JWT; structured logging (not console.log)
- **General**: Run `flutter analyze` + `eslint` before push; atomic commits with conventional messages (`feat:`, `fix:`, `chore:`)

### Environment & Configuration
- `.env` file (root) contains: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `AUTH0_DOMAIN`, `SERVER_HOST`, etc.
- `lib/config/app_config.dart`: Centralized hardcoded constants (Auth0 domain, API URLs, feature flags)
- Feature flags: `enableDevMode`, `enableDarkMode`, `enableDebugMode` in `AppConfig`

### Dependency Injection (lib/di/locator.dart)
- Services registered in `setupCoreServices()` (pre-auth: Auth0, LocalOllama, ProviderDiscovery)
- Services registered in `setupAuthenticatedServices()` (post-auth: StreamingChat, ConnectionManager)
- Use `GetIt.instance` to access; register as singletons; some services lazy-initialized

### Build Configuration
- `build.yaml`: Excludes web-specific code for non-web builds (windows, linux, android)
- Version in `pubspec.yaml` (e.g., `4.4.0+202511081545`); updated by release scripts
- `assets/version.json`: Contains version metadata

## Key Files by Concern

| Concern | Files |
|---------|-------|
| **Auth Flow** | `auth_service.dart`, `auth0_*_service.dart`, `session_storage_service.dart` |
| **AI Integration** | `llm_provider_manager.dart`, `llm_providers/*.dart`, `langchain_*_service.dart` |
| **Chat/Streaming** | `streaming_chat_service.dart`, `conversation_storage_service*.dart` |
| **Connection Mgmt** | `connection_manager_service.dart`, `unified_connection_service.dart` |
| **Local Models** | `ollama_service.dart`, `local_ollama_connection_service.dart`, `provider_discovery_service.dart` |
| **Error Handling** | `llm_error_handler.dart`, `llm_communication_error.dart`, `ollama_connection_error.dart` |
| **Desktop/System** | `window_manager_service*.dart`, `native_tray_service*.dart`, `desktop_client_detection_service.dart` |
| **Config & Constants** | `lib/config/app_config.dart`, `lib/di/locator.dart` |

## External Dependencies & Integrations

**Cloud AI**: OpenAI, Anthropic APIs
**Local AI**: Ollama (via HTTP), LM Studio (OpenAI-compatible)
**Auth**: Auth0 (OAuth2/OIDC; web uses JS SDK via bridge, desktop uses native)
**Database**: PostgreSQL (sessions), SQLite (local conversations)
**Networking**: `dio` (HTTP client for all REST APIs and streaming)
**State**: `provider`, `rxdart` (reactive streams)
**Storage**: `sqflite_common_ffi` (desktop), `shared_preferences` (web), `flutter_secure_storage_x` (tokens)
**AI Framework**: LangChain (`langchain`, `langchain_ollama`, `langchain_community`)
**System**: `window_manager`, `tray_manager`, `flutter_secure_storage_x` (desktop only)

## Testing & Quality Checks

Before pushing:
1. `flutter analyze` (fix all linter errors)
2. `flutter format .` (auto-format)
3. `flutter test` (pass all tests; add mocks to `test/test_config.dart` if needed)
4. For Node.js code: `npm audit`, `eslint`
5. Commit: Use conventional messages (`feat:`, `fix:`, `chore:`, `test:`, `docs:`, `refactor:`, `ci:`)

## MCP Tools Available (Docker Desktop)

The following MCP servers are available for direct use:

- **context7**: Library documentation and knowledge base tool for retrieving up-to-date documentation and API references from libraries and frameworks. Use for researching package documentation, API patterns, and best practices.
- **sequentialthinking**: Reflective problem-solving tool that helps analyze complex problems through multi-step thinking, hypothesis generation, and verification. Use for planning multi-step implementations and validating solutions.
- **memory**: Persistent memory system for tracking project state, decisions, and context across sessions. Use for maintaining knowledge about ongoing tasks and architectural decisions.

## MCP Test Summary

The MCP toolkit was validated locally against the active Docker containers and the workspace was configured to make these tools available to VS Code and AI agents.

- Resolved library docs via `context7` (found `/cfug/dio` and retrieved usage snippets for `dio`).
- Ran a multi-step check with `sequentialthinking` — tool is responsive.
- Created a test entity `mcp-tool-check` in the `memory` server to record observations.
- Added workspace mappings in `.vscode/settings.json` so the MCP extension can find the containers:
	- `context7` -> `mcp/context7`
	- `sequentialthinking` -> `mcp/sequentialthinking`
	- `memory` -> `mcp/memory`

If you'd like, I can (a) run more targeted queries (library lookups, code snippets), (b) populate `memory` with additional project notes, or (c) remove/rename MCP entries in the workspace settings.

---

**Last Updated**: November 15, 2025 | **Version**: 4.4.0
