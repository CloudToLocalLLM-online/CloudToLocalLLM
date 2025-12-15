import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';

import 'dart:js_interop';
import 'package:web/web.dart' as web;

// --- JS Interop Definitions ---

/// Extension on the global Window to access Auth0Bridge
extension type Auth0Window._(JSObject _) implements JSObject {
  @JS('Auth0Bridge')
  external Auth0Bridge? get auth0Bridge;
  external set flutterAuthCallback(JSFunction callback);
  external Location get location;
}

extension type Location._(JSObject _) implements JSObject {
  external String get search;
}

/// The Auth0Bridge object exposed by auth0-bridge.js
extension type Auth0Bridge._(JSObject _) implements JSObject {
  external void login();
  external void logout();
  external JSPromise<AuthResult> handleRedirect();
  external JSPromise<Auth0User?> getUser(); // Returns Auth0User or null
  external JSPromise<JSString?> getToken(); // Returns token string or null
}

/// The result object passed to the flutterAuthCallback or returned by handleRedirect
extension type AuthResult._(JSObject _) implements JSObject {
  external String get type;
  external Auth0User? get user;
  external String? get accessToken;
  external String? get error;
}

/// The user object returned by Auth0 SDK
extension type Auth0User._(JSObject _) implements JSObject {
  external String? get sub;
  external String? get email;
  external String? get name;
  external String? get nickname;
  external String? get picture;
}

// Helper to access the window as our custom type
Auth0Window get _window => web.window as Auth0Window;

/// Error types for authentication failures
enum AuthErrorType {
  network,
  cancelled,
  invalidCredentials,
  configuration,
  unknown
}

/// Structured authentication exception with recovery suggestions
class AuthException implements Exception {
  final AuthErrorType type;
  final String message;
  final String? recoverySuggestion;

  AuthException(this.type, this.message, {this.recoverySuggestion});

  factory AuthException.network(String details) =>
      AuthException(AuthErrorType.network, 'Network connection error: $details',
          recoverySuggestion: 'Check your internet connection and try again');

  factory AuthException.cancelled() =>
      AuthException(AuthErrorType.cancelled, 'Authentication was cancelled',
          recoverySuggestion: 'Tap the login button to try again');

  factory AuthException.invalidCredentials() => AuthException(
      AuthErrorType.invalidCredentials, 'Invalid credentials provided',
      recoverySuggestion: 'Please check your credentials and try again');

  factory AuthException.configuration(String details) => AuthException(
      AuthErrorType.configuration, 'Configuration error: $details',
      recoverySuggestion: 'Please check your application configuration');
}

/// Auth0 implementation of the authentication provider
class Auth0AuthProvider implements AuthProvider {
  final Auth0 _auth0;
  final String _audience;

  Auth0AuthProvider({
    String? domain,
    String? clientId,
    String? audience,
  })  : _auth0 = Auth0(
          domain ??
              const String.fromEnvironment('AUTH0_DOMAIN',
                  defaultValue: 'dev-v2f2p008x3dr74ww.us.auth0.com'),
          clientId ??
              const String.fromEnvironment('AUTH0_CLIENT_ID',
                  defaultValue: 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A'),
        ),
        _audience = audience ??
            const String.fromEnvironment('AUTH0_AUDIENCE',
                defaultValue: 'https://api.cloudtolocalllm.online');

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  UserModel? _currentUser;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    if (kIsWeb) {
      await _initializeWeb();
    } else {
      await _initializeNative();
    }
  }

  Future<void> _initializeNative() async {
    try {
      final credentials = await _auth0.credentialsManager.credentials();
      if (credentials.accessToken.isNotEmpty) {
        _currentUser = _credentialsToUser(credentials);
        _authStateController.add(true);
      } else {
        _authStateController.add(false);
      }
    } catch (e) {
      _authStateController.add(false);
    }
  }

  Future<void> _initializeWeb() async {
    try {
      final auth0Bridge = _window.auth0Bridge;
      if (auth0Bridge == null) {
        debugPrint('Auth0Bridge not found. Ensure auth0-bridge.js is loaded.');
        _authStateController.add(false);
        return;
      }

      // Register callback immediately
      _registerWebCallback();

      // Check for redirect params in URL
      final search = _window.location.search;
      if (search.contains('code=') && search.contains('state=')) {
        debugPrint(
            '[Auth0AuthProvider] Detected code/state, handling redirect...');
        try {
          final result = await auth0Bridge.handleRedirect().toDart;
          // The callback might handle this, but better to handle explicit return too
          if (result.type == 'success' && result.user != null) {
            _currentUser = _jsUserToUserModel(result.user!);
            _authStateController.add(true);
            return;
          }
        } catch (e) {
          debugPrint('[Auth0AuthProvider] Redirect handling failed: $e');
        }
      }

      // Check for existing session (persistence)
      final user = await auth0Bridge.getUser().toDart;
      if (user != null) {
        debugPrint('[Auth0AuthProvider] Found existing web session');
        _currentUser = _jsUserToUserModel(user);
        _authStateController.add(true);
      } else {
        _authStateController.add(false);
      }
    } catch (e) {
      debugPrint('[Auth0AuthProvider] Web init error: $e');
      _authStateController.add(false);
    }
  }

  void _registerWebCallback() {
    // Set up the callback that JavaScript will call
    _window.flutterAuthCallback = (AuthResult result) {
      final type = result.type;
      debugPrint('[Auth0AuthProvider] Received JS callback: $type');

      if (type == 'success') {
        final userData = result.user;
        final accessToken = result.accessToken;

        if (userData != null && accessToken != null) {
          _currentUser = _jsUserToUserModel(userData);
          _authStateController.add(true);
        }
      } else if (type == 'error') {
        // Provide feedback if needed, but usually handled by promise/ui
        debugPrint('Auth Callback Error: ${result.error}');
      } else if (type == 'logout') {
        _currentUser = null;
        _authStateController.add(false);
      }
    }.toJS;
  }

  @override
  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      final bridge = _window.auth0Bridge;
      if (bridge != null) {
        final tokenJS = await bridge.getToken().toDart;
        return tokenJS?.toDart;
      }
      return null;
    }

    try {
      final credentials = await _auth0.credentialsManager.credentials();
      return credentials.accessToken;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> login() async {
    if (kIsWeb) {
      // Use JavaScript bridge for web
      return _loginWithWebBridge();
    } else {
      // Use native Auth0 SDK for desktop/mobile
      try {
        final credentials = await _auth0.webAuthentication().login(
          audience: _audience,
          scopes: {'openid', 'profile', 'email', 'offline_access'},
        );

        _currentUser = _credentialsToUser(credentials);
        await _auth0.credentialsManager.storeCredentials(credentials);
        _authStateController.add(true);
      } catch (e) {
        _authStateController.add(false);
        throw _categorizeError(e);
      }
    }
  }

  Future<void> _loginWithWebBridge() async {
    // Callback is already registered in initialize, but we can register again or rely on it.
    // However, login() here initiates a redirect. The promise won't complete until redirect logic implies.
    // Actually, loginWithRedirect() returns Promise<void> but it redirects page, so it never technically completes in this session.
    // So we just call it.

    if (kIsWeb) {
      try {
        final auth0Bridge = _window.auth0Bridge;
        if (auth0Bridge != null) {
          auth0Bridge.login(); // This triggers redirect
          // We don't complete here because page will reload.
        } else {
          throw AuthException.configuration('Bridge not found');
        }
      } catch (e) {
        throw AuthException.network('Login init failed: $e');
      }
    }
    // No return needed really as page redirects
  }

  UserModel _jsUserToUserModel(Auth0User jsUser) {
    final sub = jsUser.sub ?? '';
    final email = jsUser.email ?? '';
    final name = jsUser.name ?? email;
    final nickname = jsUser.nickname;
    final picture = jsUser.picture;

    final now = DateTime.now();
    return UserModel(
      id: sub,
      email: email,
      name: name,
      nickname: nickname,
      picture: picture,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _auth0.webAuthentication().logout();
      await _auth0.credentialsManager.clearCredentials();
      _currentUser = null;
      _authStateController.add(false);
    } catch (e) {
      // Even if logout fails, clear local state
      _currentUser = null;
      _authStateController.add(false);
      rethrow;
    }
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    // Auth0 Flutter handles callback automatically
    // This method is for compatibility with the interface
    return true;
  }

  /// Categorizes raw errors into structured AuthExceptions
  AuthException _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('cancelled') ||
        errorString.contains('user_cancelled')) {
      return AuthException.cancelled();
    } else if (errorString.contains('network') ||
        errorString.contains('timeout')) {
      return AuthException.network(error.toString());
    } else if (errorString.contains('invalid') ||
        errorString.contains('unauthorized')) {
      return AuthException.invalidCredentials();
    } else {
      return AuthException(
          AuthErrorType.unknown, 'Authentication failed: ${error.toString()}');
    }
  }

  UserModel _credentialsToUser(Credentials credentials) {
    final userInfo = credentials.user;
    final now = DateTime.now();
    return UserModel(
      id: userInfo.sub,
      email: userInfo.email ?? '',
      name: userInfo.name,
      picture: userInfo
          .name, // Using name as fallback since picture property doesn't exist
      createdAt: now,
      updatedAt: now,
      // Add other user properties as needed
    );
  }

  void dispose() {
    _authStateController.close();
  }
}
