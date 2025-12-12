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
}

/// The Auth0Bridge object exposed by auth0-bridge.js
extension type Auth0Bridge._(JSObject _) implements JSObject {
  external void login();
  external void logout();
}

/// The result object passed to the flutterAuthCallback
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
                defaultValue:
                    'https://dev-v2f2p008x3dr74ww.us.auth0.com/api/v2/');

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  UserModel? _currentUser;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
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

  @override
  Future<String?> getAccessToken() async {
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
    final completer = Completer<void>();

    // Set up callback for JavaScript bridge
    if (kIsWeb) {
      try {
        final auth0Bridge = _window.auth0Bridge;

        if (auth0Bridge != null) {
          // Set up the callback that JavaScript will call
          _window.flutterAuthCallback = (AuthResult result) {
            final type = result.type;

            if (type == 'success') {
              final userData = result.user;
              final accessToken = result.accessToken;

              if (userData != null && accessToken != null) {
                _currentUser = _jsUserToUserModel(userData);
                _authStateController.add(true);
                completer.complete();
              } else {
                completer.completeError(AuthException.invalidCredentials());
              }
            } else if (type == 'error') {
              final error = result.error ?? 'Unknown error';
              completer.completeError(AuthException.network(error));
            }
          }.toJS;

          // Call the login function
          auth0Bridge.login();
        } else {
          completer.completeError(AuthException.configuration(
              'Auth0Bridge not found. Ensure auth0-bridge.js is loaded.'));
        }
      } catch (e) {
        completer.completeError(AuthException.network(
            'Failed to initialize web authentication: $e'));
      }
    } else {
      completer.completeError(AuthException.configuration(
          'Web authentication called on non-web platform'));
    }

    return completer.future;
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
