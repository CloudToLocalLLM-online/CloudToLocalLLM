import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth0_service.dart';

import 'auth0_bridge_interop.dart' if (dart.library.io) 'auth0_bridge_interop_stub.dart';

// ignore: invalid_runtime_check_with_js_interop_types
// JSAny? results from .toDart are dynamic but need explicit type handling

class Auth0WebService implements Auth0Service {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Map<String, dynamic>? get currentUser => _currentUser;

  @override
  String? getAccessToken() => _accessToken;

  @override
  Future<void> initialize() async {
    // Wait for Auth0 bridge to be available
    await _waitForAuth0Bridge();
    await checkAuthStatus();
  }

  Future<void> _waitForAuth0Bridge() async {
    const maxAttempts = 50; // 5 seconds
    var attempts = 0;

    while (attempts < maxAttempts) {
      if (auth0Bridge != null) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    throw Exception('Auth0 bridge not available after 5 seconds');
  }

  @override
  Future<void> login() async {
    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }
    await auth0Bridge!.loginWithRedirect();
  }

  @override
  Future<void> logout() async {
    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }
    await auth0Bridge!.logout();
    _isAuthenticated = false;
    _currentUser = null;
    _accessToken = null;
    _authStateController.add(false);
  }

  @override
  Future<bool> handleRedirectCallback() async {
    try {
      if (auth0Bridge == null) {
        return false;
      }
      await auth0Bridge!.handleRedirectCallback();
      await checkAuthStatus();
      return _isAuthenticated;
    } catch (e) {
      debugPrint('Error handling redirect callback: $e');
      return false;
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      if (auth0Bridge == null) {
        _isAuthenticated = false;
        return;
      }
      
      final isAuth = await auth0Bridge!.isAuthenticated();
      final wasAuthenticated = _isAuthenticated;

      // Handle dynamic result from await
      if (isAuth is bool) {
        _isAuthenticated = isAuth;
      } else if (isAuth is String) {
        _isAuthenticated = isAuth == 'true';
      } else {
        _isAuthenticated = false;
      }

      if (_isAuthenticated) {
        // getUser returns a JSON string from our modified bridge
        final userJson = await auth0Bridge!.getUser();
        final token = await auth0Bridge!.getAccessToken();

        if (userJson != null) {
          _currentUser = jsonDecode(userJson.toString()) as Map<String, dynamic>;
        }
        if (token != null) {
          _accessToken = token.toString();
        }
      }

      if (wasAuthenticated != _isAuthenticated) {
        _authStateController.add(_isAuthenticated);
      }
    } catch (e, stackTrace) {
      debugPrint('Auth0 checkAuthStatus error: $e');
      debugPrint(stackTrace.toString());
      _isAuthenticated = false;
      _authStateController.add(false);
    }
  }

  @override
  void dispose() {
    _authStateController.close();
  }
}

