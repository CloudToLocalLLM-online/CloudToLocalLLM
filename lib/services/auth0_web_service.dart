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
  bool _bridgeReady = false;
  bool _clientReady = false;

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

    // Try to wait for client, but don't fail if it's not ready yet
    // The client will be checked again when actually needed (login, etc.)
    try {
      await _waitForAuth0Client();
    } catch (e) {
      debugPrint(
        '⚠️ Auth0 client not ready during initialization, will retry when needed: $e',
      );
      // Don't throw - we'll check again when login is called
    }

    // Always try to check auth status, even if client isn't ready yet
    // This will ensure we check again when the client becomes available
    try {
      await checkAuthStatus();
    } catch (e) {
      debugPrint('⚠️ Initial auth status check failed: $e');
    }
  }

  Future<void> _waitForAuth0Bridge() async {
    const maxAttempts = 50; // 5 seconds
    var attempts = 0;

    while (attempts < maxAttempts) {
      if (auth0Bridge != null) {
        _bridgeReady = true;
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    throw Exception('Auth0 bridge not available after 5 seconds');
  }

  Future<void> _waitForAuth0Client() async {
    if (_clientReady) {
      return;
    }

    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }

    const maxAttempts = 50; // 5 seconds
    var attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final isReady = auth0Bridge!.isInitialized();
        if (isReady) {
          _clientReady = true;
          debugPrint('✅ Auth0 client is ready');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Auth0 client check error: $e');
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    throw Exception('Auth0 client not initialized after 5 seconds');
  }

  Future<void> _ensureClientReady() async {
    // Always ensure bridge is ready
    if (!_bridgeReady) {
      debugPrint('🔄 Waiting for Auth0 bridge...');
      await _waitForAuth0Bridge();
    }

    // Always check client readiness (don't rely on cached _clientReady)
    // The client might have been initialized after our first check
    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }

    try {
      debugPrint('🔄 Checking if Auth0 client is ready...');
      final isReady = auth0Bridge!.isInitialized();
      debugPrint('🔍 Auth0 client initialized check result: $isReady');
      if (isReady) {
        _clientReady = true;
        debugPrint('✅ Auth0 client is ready');
        return;
      } else {
        // Client not ready, try the full wait
        debugPrint('⏳ Auth0 client not ready, waiting...');
        _clientReady = false;
        await _waitForAuth0Client();
      }
    } catch (e) {
      debugPrint('⚠️ Auth0 client readiness check failed: $e');
      // For callback handling, try a shorter wait since Auth0 might still be initializing
      try {
        debugPrint('⏳ Retrying Auth0 client wait with shorter timeout...');
        await _waitForAuth0ClientShort();
      } catch (e2) {
        debugPrint('⚠️ Short wait also failed: $e2');
        throw Exception('Auth0 client not available after retries: $e');
      }
    }
  }

  Future<void> _waitForAuth0ClientShort() async {
    if (_clientReady) {
      return;
    }

    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }

    const maxAttempts = 30; // 3 seconds instead of 5
    var attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final isReady = auth0Bridge!.isInitialized();
        if (isReady) {
          _clientReady = true;
          debugPrint('✅ Auth0 client ready (short wait)');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Auth0 client short check error: $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    throw Exception('Auth0 client not initialized after 3 seconds');
  }

  @override
  Future<void> login() async {
    debugPrint('[Auth0Web] Starting login process...');
    await _ensureClientReady();
    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }
    debugPrint('[Auth0Web] Auth0 bridge ready, calling loginWithRedirect');
    final promise = auth0Bridge!.loginWithRedirect();
    debugPrint('[Auth0Web] Login promise created, awaiting...');
    await promise.toDart;
    debugPrint('[Auth0Web] Login redirect completed');
  }

  @override
  Future<void> logout() async {
    await _ensureClientReady();
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
  bool isCallbackUrl() {
    try {
      if (auth0Bridge == null) return false;
      return auth0Bridge!.isCallbackUrl();
    } catch (e) {
      debugPrint('Error checking callback URL: $e');
      return false;
    }
  }

  @override
  Future<bool> handleRedirectCallback() async {
    debugPrint('🔄 Starting Auth0 redirect callback handling...');
    try {
      await _ensureClientReady();
      if (auth0Bridge == null) {
        debugPrint('❌ Auth0 bridge not available for callback');
        return false;
      }

      debugPrint('🔄 Calling Auth0 bridge handleRedirectCallback...');
      final promise = auth0Bridge!.handleRedirectCallback();
      final result = await promise.toDart;
      final resultData = result.dartify();
      debugPrint(
        '📋 Auth0 handleRedirectCallback bridge result: $resultData',
      );

      // Check if the result indicates success
      final success = resultData is Map && resultData['success'] == true;
      debugPrint('✅ Callback success: $success');

      if (success) {
        debugPrint('🔄 Callback successful, checking auth status...');
        await checkAuthStatus();
        debugPrint('🔐 Auth status after callback: $_isAuthenticated');
        return _isAuthenticated;
      } else {
        debugPrint('❌ Callback failed with result: $resultData');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error handling redirect callback: $e');
      return false;
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      // Try to ensure client is ready, but don't fail if it's not
      try {
        await _ensureClientReady();
      } catch (e) {
        debugPrint('⚠️ Auth0 client not ready for auth check: $e');
        _isAuthenticated = false;
        _authStateController.add(false);
        return;
      }

      if (auth0Bridge == null) {
        _isAuthenticated = false;
        _authStateController.add(false);
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
      } else {
        // Clear user data if not authenticated
        _currentUser = null;
        _accessToken = null;
      }

      if (wasAuthenticated != _isAuthenticated) {
        debugPrint('🔐 Auth state changed: $wasAuthenticated -> $_isAuthenticated');
        _authStateController.add(_isAuthenticated);
      }
    } catch (e, stackTrace) {
      debugPrint('Auth0 checkAuthStatus error: $e');
      debugPrint(stackTrace.toString());
      _isAuthenticated = false;
      _currentUser = null;
      _accessToken = null;
      _authStateController.add(false);
    }
  }

  @override
  void dispose() {
    _authStateController.close();
  }
}

