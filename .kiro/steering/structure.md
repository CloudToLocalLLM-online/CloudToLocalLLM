# CloudToLocalLLM Project Structure

## Root Directory Organization

### Core Application (`lib/`)
```
lib/
├── main.dart                    # Main application entry point
├── main_privacy_enhanced.dart   # Privacy-focused variant
├── components/                  # Reusable UI components
├── config/                      # App configuration and routing
├── models/                      # Data models and DTOs
├── screens/                     # Full-screen UI pages
├── services/                    # Business logic and API services
├── shared/                      # Shared utilities and resources
├── utils/                       # Helper utilities
└── widgets/                     # Custom widgets
```

### Key Directories

#### `lib/services/` - Business Logic Layer
- **Authentication**: `auth_service.dart`, platform-specific auth implementations
- **Connection Management**: `connection_manager_service.dart`, `unified_connection_service.dart`
- **Ollama Integration**: `ollama_service.dart`, `local_ollama_connection_service.dart`
- **Tunneling**: `simple_tunnel_client.dart`, `streaming_proxy_service.dart`
- **LangChain**: `langchain_*_service.dart` files for AI integration
- **System Integration**: `native_tray_service.dart`, `window_manager_service.dart`
- **User Management**: `enhanced_user_tier_service.dart`, `user_container_service.dart`

#### `lib/screens/` - UI Pages
- **Core Screens**: `home_screen.dart`, `login_screen.dart`, `settings_screen.dart`
- **Admin**: `admin/` subdirectory for administrative interfaces
- **Marketing**: `marketing/` subdirectory for promotional content
- **Settings**: `settings/` subdirectory for configuration screens

#### `lib/components/` - Reusable UI Components
- **Setup & Onboarding**: `setup_wizard.dart`, `tunnel_connection_wizard.dart`
- **Chat Interface**: `message_bubble.dart`, `message_input.dart`, `conversation_list.dart`
- **Status & Monitoring**: `tunnel_status_indicator.dart`, `llm_security_dashboard.dart`
- **Platform-Specific**: `desktop_client_prompt.dart`, `web_download_prompt.dart`

### Configuration & Build (`config/`, `scripts/`)
```
config/
├── docker/                      # Docker configurations
├── nginx/                       # Web server configurations
├── systemd/                     # Linux service configurations
└── windows/                     # Windows-specific configurations

scripts/
├── build_unified_package.sh     # Main build script
├── flutter_build_with_timestamp.sh  # Flutter build automation
├── version_manager.sh           # Version management
├── deploy/                      # Deployment scripts
├── powershell/                  # Windows PowerShell scripts
└── setup/                       # Installation scripts
```

### Documentation (`docs/`)
```
docs/
├── ARCHITECTURE/                # System design documentation
├── DEPLOYMENT/                  # Deployment guides
├── DEVELOPMENT/                 # Developer documentation
├── FEATURES/                    # Feature specifications
├── INSTALLATION/                # Installation guides
├── OPERATIONS/                  # Operations and maintenance
└── USER_DOCUMENTATION/          # End-user guides
```

### Testing (`test/`)
```
test/
├── unit/                        # Unit tests
├── integration/                 # Integration tests
├── e2e/                         # End-to-end tests
├── services/                    # Service-specific tests
└── widgets/                     # Widget tests
```

### Backend Services (`services/`)
```
services/
├── api-backend/                 # Node.js API server
└── streaming-proxy/             # Streaming proxy service
```

## Architecture Patterns

### Service Layer Pattern
- Services in `lib/services/` handle all business logic
- Services use dependency injection via Provider pattern
- Platform-specific implementations use factory pattern

### State Management
- **Provider Pattern**: Used throughout for state management
- **ChangeNotifier**: Services extend ChangeNotifier for reactive updates
- **Consumer/Selector**: UI components consume state changes

### Navigation
- **GoRouter**: Declarative routing with type-safe navigation
- **Global Navigator Key**: For system tray and external navigation

### Platform Abstraction
- **Conditional Imports**: Platform-specific code using `dart:io` vs `dart:html`
- **Stub Files**: `*_stub.dart` files for unsupported platforms
- **Feature Flags**: Platform-specific feature enablement

## File Naming Conventions
- **Services**: `*_service.dart`
- **Models**: `*_model.dart` or descriptive names like `conversation.dart`
- **Screens**: `*_screen.dart`
- **Components**: Descriptive names like `message_bubble.dart`
- **Platform-specific**: `*_platform_web.dart`, `*_platform_io.dart`
- **Stubs**: `*_stub.dart` for unsupported platform implementations

## Import Organization
1. Dart/Flutter core imports
2. Third-party package imports
3. Local project imports (relative paths)
4. Platform-specific conditional imports at the end

## Build Artifacts
- `build/web/` - Web application build
- `build/linux/` - Linux desktop build
- `build/windows/` - Windows desktop build
- `dist/` - Distribution packages
- `test-results/` - Test execution results