import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
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
    await auth0Bridge!.loginWithRedirect().toDart;
  }

  @override
  Future<void> logout() async {
    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }
    await auth0Bridge!.logout().toDart;
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
      await auth0Bridge!.handleRedirectCallback().toDart;
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
      
      final isAuth = await auth0Bridge!.isAuthenticated().toDart;
      final wasAuthenticated = _isAuthenticated;

      if (isAuth.isA<JSBoolean>()) {
        _isAuthenticated = isAuth.toDart;
      } else {
        _isAuthenticated = isAuth as bool? ?? false;
      }

      if (_isAuthenticated) {
        // getUser returns a JSON string from our modified bridge
        final userJson = await auth0Bridge!.getUser().toDart;
        final token = await auth0Bridge!.getAccessToken().toDart;

        if (userJson != null && userJson.isA<JSString>()) {
          final userStr = userJson.toDart;
          _currentUser = jsonDecode(userStr) as Map<String, dynamic>;
        }
        if (token != null && token.isA<JSString>()) {
          _accessToken = token.toDart;
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

