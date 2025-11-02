import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'auth0_bridge_interop.dart';
import 'auth0_service.dart';

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
    await checkAuthStatus();
  }

  @override
  Future<void> login() async {
    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }
    await js_util.promiseToFuture(js_util.callMethod(auth0Bridge, 'loginWithRedirect', []));
  }

  @override
  Future<void> logout() async {
    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }
    await js_util.promiseToFuture(js_util.callMethod(auth0Bridge, 'logout', []));
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
      await js_util.promiseToFuture(js_util.callMethod(auth0Bridge, 'handleRedirectCallback', []));
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
      
      final isAuth = await js_util.promiseToFuture(js_util.callMethod(auth0Bridge, 'isAuthenticated', []));
      final wasAuthenticated = _isAuthenticated;

      if (isAuth != null && isAuth is bool) {
        _isAuthenticated = isAuth;
      } else {
        _isAuthenticated = false;
      }

      if (_isAuthenticated) {
        // getUser returns a JSON string from our modified bridge
        final userJson = await js_util.promiseToFuture(js_util.callMethod(auth0Bridge, 'getUser', []));
        final token = await js_util.promiseToFuture(js_util.callMethod(auth0Bridge, 'getAccessToken', []));

        if (userJson != null && userJson is String) {
          _currentUser = jsonDecode(userJson) as Map<String, dynamic>;
        }
        if (token != null && token is String) {
          _accessToken = token;
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

