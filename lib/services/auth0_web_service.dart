import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth0_service.dart';
import 'dart:js_interop';

import 'auth0_bridge_interop_js.dart' if (dart.library.io) 'auth0_bridge_interop_stub_new.dart';

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
    final promise = auth0Bridge!.loginWithRedirect();
    await promise.toDart;
  }

  @override
  Future<void> logout() async {
    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }
    final promise = auth0Bridge!.logout();
    await promise.toDart;
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
      final promise = auth0Bridge!.handleRedirectCallback();
      await promise.toDart;
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

      final isAuthPromise = auth0Bridge!.isAuthenticated();
      final isAuth = await isAuthPromise.toDart;
      final wasAuthenticated = _isAuthenticated;

      // Handle dynamic result from await
      final authValue = isAuth.dartify();
      if (authValue is bool) {
        _isAuthenticated = authValue;
      } else if (authValue == 'true') {
        _isAuthenticated = true;
      } else if (authValue == 'false') {
        _isAuthenticated = false;
      } else {
        _isAuthenticated = false;
      }

      if (_isAuthenticated) {
        // getUser returns a JSON string from our modified bridge
        final userJsonPromise = auth0Bridge!.getUser();
        final userJson = await userJsonPromise.toDart;
        final tokenPromise = auth0Bridge!.getAccessToken();
        final token = await tokenPromise.toDart;

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

