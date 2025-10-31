# Flutter Best Practices

## Dependency Management

- Always use `flutter pub get` to update dependencies, never manually edit `pubspec.lock`.
- Use `flutter pub outdated` to identify packages that need updating.
- Remove unused dependencies to keep the project lean.
- Update discontinued packages (e.g., `js` package → use `dart:js_interop`).

## Code Quality

- Run `flutter analyze` before committing to catch linting errors.
- Use `flutter format` to ensure consistent code formatting.
- Prefer `debugPrint()` over `print()` for logging (respects Flutter's logging system).
- Use platform-specific imports when necessary (`dart.library.html`, `dart.library.io`).

## Build Practices

- Use `flutter build web --release` for production builds.
- Leverage `flutter pub get` caching by copying pubspec files first in Dockerfiles.
- Always specify `--release` flag for production builds.

## Authentication

- Use Auth0 for web applications (no GCIP/Google Sign-In).
- Use `dart:js_interop` for JavaScript interop (replaces deprecated `js` package).
- Implement platform-specific auth services (Auth0WebService for web, others for mobile/desktop).

## Web-Specific

- Use `package:web/web.dart` for web platform detection and DOM manipulation.
- Bridge JavaScript SDKs (like Auth0) through custom bridge files (`auth0-bridge.js`).
- Handle redirect callbacks properly for OAuth flows.

## Platform Detection

```dart
import 'package:flutter/foundation.dart';

if (kIsWeb) {
  // Web-specific code
} else {
  // Mobile/Desktop code
}
```

