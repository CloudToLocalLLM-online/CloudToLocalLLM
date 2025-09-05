# CloudToLocalLLM Copilot Instructions

This document provides essential guidelines for AI coding agents to effectively contribute to the `CloudToLocalLLM` project.

## 1. Project Overview

`CloudToLocalLLM` is a Flutter-based application that enables seamless interaction with both cloud-based and local AI models. It features a hybrid AI architecture, privacy-first design, cross-platform support (Windows, Linux, Web), secure OAuth2 authentication, and real-time WebSocket communication. The backend services are built with Node.js.

## 2. Architecture Highlights

*   **Hybrid AI Architecture**: The application integrates with cloud AI services (OpenAI, Anthropic) and local AI models (Ollama).
    *   **Key Files**: `lib/services/llm_provider_manager.dart`, `lib/services/langchain_ollama_service.dart`, `lib/services/openai_compatible_provider.dart`
*   **Secure Tunneling**: Real-time communication between the client and cloud services is facilitated via WebSocket tunneling.
    *   **Key Files**: `lib/services/unified_connection_service.dart`, `lib/services/streaming_chat_service.dart`, `lib/services/http_polling_tunnel_client.dart`, `lib/services/tunnel_llm_request_handler.dart`, `lib/services/tunnel_message_protocol.dart`
*   **Multi-Container Architecture**: Deployment leverages Docker and Google Cloud Run for web, API, and streaming services.
    *   **Key Files**: `Dockerfile/api`, `Dockerfile/streaming`, `docker-compose.yml`, `docker-compose.multi.yml`
*   **Authentication**: OAuth2-based authentication with encrypted token storage.
    *   **Key Files**: `lib/services/auth_service.dart`, `lib/services/gcip_auth_service.dart`, `lib/services/auth_logger.dart`
*   **State Management**: `provider` is used for state management in the Flutter application.
    *   **Key Files**: Refer to `lib/main.dart` and `lib/screens/` for examples.
*   **Backend Services**: Node.js backend utilizing `@modelcontextprotocol/sdk` and `zod`.
    *   **Key Files**: `package.json`, `server.js` (if present in the root or `services/api-backend/`)

## 3. Developer Workflows

### 3.1. Setup

*   **Flutter**: Ensure Flutter SDK (3.8+) is installed.
*   **Node.js**: Required for development and testing.
*   **Ollama**: (Optional) For local AI models.
*   **Dependencies**:
    ```bash
    flutter pub get
    npm install
    ```

### 3.2. Running the Application

*   **Desktop (Windows/Linux)**:
    ```bash
    flutter run -d windows
    flutter run -d linux
    ```
*   **Web**:
    ```bash
    flutter run -d chrome
    ```
*   **Backend (Development)**:
    ```bash
    npm run dev
    ```

### 3.3. Testing

*   **Flutter Tests**:
    ```bash
    flutter test
    ```
*   **E2E Tests (Node.js)**:
    ```bash
    npm test
    ```
*   **Specific Test Suites**:
    ```bash
    npm run test:auth
    npm run test:tunnel
    ```

### 3.4. Building

*   **Windows**:
    ```bash
    flutter build windows --release
    ```
*   **Linux**:
    ```bash
    flutter build linux --release
    ```
*   **Web**:
    ```bash
    flutter build web --release
    ```

### 3.5. Deployment

*   **Desktop Application Builds**: Use PowerShell scripts for Windows/macOS/Linux builds and GitHub releases.
    *   **Key Script**: `scripts/powershell/Deploy-CloudToLocalLLM.ps1`
*   **Cloud Infrastructure Deployment**: Automatically handled by GitHub Actions on `main` branch pushes, deploying to Google Cloud Run.
    *   **Key Files**: `.github/workflows/` (if present), `config/cloudrun/OIDC_WIF_SETUP.md`

## 4. Project-Specific Conventions and Patterns

*   **Environment Variables**: Configuration is managed via a `.env` file in the project root.
    *   **Example**: `OPENAI_API_KEY`, `SERVER_HOST`, `OAUTH_CLIENT_ID`
*   **Version Management**: Automated version management scripts are used.
    *   **Key Scripts**: `scripts/powershell/version_manager.ps1`, `scripts/version_manager.sh`
*   **Code Style**: Follow Flutter/Dart conventions. Ensure meaningful names, comments for complex logic, and passing tests.

## 5. Integration Points and External Dependencies

*   **Cloud AI**: OpenAI, Anthropic.
*   **Local AI**: Ollama.
*   **Authentication**: Google Cloud Identity Platform (GCIP) for OAuth2.
*   **Error Tracking**: Sentry.
*   **Networking**: `http`, `dio`, `web_socket_channel`.
*   **Local Storage**: `sqflite_common_ffi` (desktop), `shared_preferences` (web).
*   **System Integration**: `window_manager`, `flutter_secure_storage_x`, `tray_manager`.
*   **AI Framework**: `langchain`, `langchain_ollama`, `langchain_community`.

## 6. Key Directories and Files

*   `lib/`: Flutter application source code.
    *   `lib/services/`: Core application services (authentication, AI, streaming, connection).
    *   `lib/models/`: Data models.
    *   `lib/screens/`: UI screens.
    *   `lib/components/`, `lib/widgets/`: Reusable UI components.
    *   `lib/config/`: Application configuration.
*   `scripts/`: Automation scripts (deployment, versioning, environment setup).
*   `docs/`: Comprehensive project documentation.
*   `config/`: Configuration files for various environments (Cloud Run, Docker, etc.).
*   `services/`: Backend service implementations (e.g., `api-backend`, `streaming-proxy`).
*   `test/`: Unit and integration tests.
*   `e2e/`: End-to-end tests.

Please provide feedback on any unclear or incomplete sections to iterate and improve these instructions.
