# Architecture and Optimization Plan

**Status: Completed**

This document outlines the architecture of the CloudToLocalLLM application and the executed strategic plan for optimizing module loading.

## 1. Code Map and Architecture Visualization

Here is a Mermaid diagram visualizing the high-level architecture of the project, including the Flutter frontend, Node.js backend, and their key modules.

```mermaid
graph TD
    subgraph "CloudToLocalLLM Frontend (Flutter)"
        A[main.dart - Entry Point] --> B{App Initialization};
        B --> C[Router - lib/config/router.dart];
        C --> D[Home Screen];
        C --> E[Login Screen];
        C --> F[Settings Screens (Lazy)];
        C --> G[Admin Screens (Lazy)];
        C --> H[Services];
        C --> I[Marketing Screens (Lazy)];
        C --> J[Ollama Test Screen (Lazy)];
        D --> H;
        E --> H;
        F --> H;
        G --> H;
        I --> H;
        H --> K[API Client];
    end

    subgraph "CloudToLocalLLM Backend (Node.js)"
        L[server.js - Entry Point] --> M{Middleware Pipeline};
        M --> N[API Routes];
        N --> O[Authentication Service];
        N --> P[Tunnel Service];
        N --> Q[Database];
        O --> Q;
        P --> Q;
    end

    K --> N;
```

### Key Observations:

*   **Monolithic Frontend:** The Flutter application was structured as a single, monolithic module.
*   **Centralized Routing:** The routing is handled by `go_router` in a centralized file ([`lib/config/router.dart`](lib/config/router.dart:1)), which facilitated the implementation of lazy loading.
*   **Backend Services:** The backend is well-structured with a clear separation of concerns.

## 2. Strategic Plan for Optimizing Module Loading

The goal was to improve the Critical Rendering Path and reduce the Time to Interactive (TTI) by implementing code splitting, lazy loading, and asynchronous imports.

### 2.1. Code Splitting and Lazy Loading in Flutter

The Flutter application has been refactored to lazy-load routes and their associated widgets and services.

**Implemented Lazy Loading:**

*   **Settings Screens:** Loaded on demand.
*   **Admin Screens:** Loaded only for authorized users.
*   **Ollama Test Screen:** Debugging screen loaded separately.
*   **Marketing Pages (Web):** Loaded separately from the main app.

### 2.2. Asynchronous Imports

Dart's `deferred as` syntax was used to mark libraries for deferred loading, creating separate split points.

## 3. Step-by-Step Refactoring Roadmap

### Phase 1: Refactor the Router for Lazy Loading

- [x] **Identify Routes for Lazy Loading:** Identified Admin, Settings, Ollama Test, and Marketing routes.
- [x] **Create Deferred Libraries:** Created separate Dart library files for each module.
- [x] **Implement Deferred Imports:** Updated [`lib/config/router.dart`](lib/config/router.dart:1) with `deferred as` imports.
- [x] **Update Route Builders:** Updated `GoRoute` builders to use `FutureBuilder` and `loadLibrary()`.

### Phase 2: Implement Lazy Loading for Individual Screens

1.  **Admin Screens:**
    - [x] Create a new library `lib/screens/admin/admin_lazy.dart`.
    - [x] Move `AdminCenterScreen` and `AdminDataFlushScreen` imports and route definitions.
    - [x] Update the main router to use a deferred import.
2.  **Settings Screens:**
    - [x] Create a new library `lib/screens/settings/settings_lazy.dart`.
    - [x] Move `UnifiedSettingsScreen` and other settings screens.
    - [x] Update the main router to use a deferred import.
3.  **Ollama Test Screen:**
    - [x] Create a new library `lib/screens/ollama_test_lazy.dart`.
    - [x] Move `OllamaTestScreen`.
    - [x] Update the main router to use a deferred import.
4.  **Marketing Screens:**
    - [x] Create a new library `lib/screens/marketing/marketing_lazy.dart`.
    - [x] Move `HomepageScreen`, `DownloadScreen`, and `DocumentationScreen`.
    - [x] Update the main router to use a deferred import.

### Phase 3: Verification and Performance Monitoring

- [x] **Manual Testing:** Verified all application routes are functioning correctly.
- [x] **Static Analysis:** Ran `flutter analyze` to ensure no errors or unused imports.
- [x] **Git Commit:** Committed all changes to the repository.

The application is now optimized for better initial load performance through modular code splitting.