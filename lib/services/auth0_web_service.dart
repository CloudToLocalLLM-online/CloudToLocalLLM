import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth0_service.dart';
import 'dart:js_interop';

import 'auth0_bridge_interop_js.dart'
    if (dart.library.io) 'auth0_bridge_interop_stub_new.dart';

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
    debugPrint('[Auth0WebService] ===== INITIALIZATION START =====');

    // Wait for Auth0 bridge to be available
    debugPrint('[Auth0WebService] Step 1: Waiting for Auth0 bridge...');
    await _waitForAuth0Bridge();

    // Try to wait for client, but don't fail if it's not ready yet
    // The client will be checked again when actually needed (login, etc.)
    debugPrint('[Auth0WebService] Step 2: Waiting for Auth0 client...');
    try {
      await _waitForAuth0Client();
      debugPrint('[Auth0WebService] Auth0 client ready during initialization');
    } catch (e) {
      debugPrint(
        '[Auth0WebService] Auth0 client not ready during initialization, will retry when needed: $e',
      );
      // Don't throw - we'll check again when login is called
    }

    // Always try to check auth status, even if client isn't ready yet
    // This will ensure we check again when the client becomes available
    debugPrint('[Auth0WebService] Step 3: Checking initial auth status...');
    try {
      await checkAuthStatus();
      debugPrint('[Auth0WebService] Initial auth status check completed');
    } catch (e) {
      debugPrint('[Auth0WebService] Initial auth status check failed: $e');
    }

    debugPrint('[Auth0WebService] ===== INITIALIZATION COMPLETE =====');
  }

  Future<void> _waitForAuth0Bridge() async {
    debugPrint('[Auth0WebService] Waiting for Auth0 bridge...');
    const maxAttempts = 50; // 5 seconds
    var attempts = 0;

    while (attempts < maxAttempts) {
      if (auth0Bridge != null) {
        _bridgeReady = true;
        debugPrint(
          '[Auth0WebService] SUCCESS: Auth0 bridge ready after ${attempts * 100}ms',
        );
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;

      // Log progress every second
      if (attempts % 10 == 0) {
        debugPrint(
          '[Auth0WebService] Still waiting for bridge... (${attempts / 10} seconds)',
        );
      }
    }

    debugPrint(
      '[Auth0WebService] ERROR: Auth0 bridge not available after 5 seconds',
    );
    throw Exception('Auth0 bridge not available after 5 seconds');
  }

  Future<void> _waitForAuth0Client() async {
    if (_clientReady) {
      debugPrint('[Auth0WebService] Auth0 client already ready (cached)');
      return;
    }

    if (auth0Bridge == null) {
      debugPrint('[Auth0WebService] ERROR: Auth0 bridge not available');
      throw Exception('Auth0 bridge not available');
    }

    debugPrint('[Auth0WebService] Waiting for Auth0 client initialization...');
    const maxAttempts = 50; // 5 seconds
    var attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final isReady = auth0Bridge!.isInitialized();
        if (isReady) {
          _clientReady = true;
          debugPrint(
            '[Auth0WebService] SUCCESS: Auth0 client ready after ${attempts * 100}ms',
          );
          return;
        }
      } catch (e) {
        debugPrint(
          '[Auth0WebService] Auth0 client check error (attempt $attempts): $e',
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;

      // Log progress every second
      if (attempts % 10 == 0) {
        debugPrint(
          '[Auth0WebService] Still waiting for client... (${attempts / 10} seconds)',
        );
      }
    }

    debugPrint(
      '[Auth0WebService] ERROR: Auth0 client not initialized after 5 seconds',
    );
    throw Exception('Auth0 client not initialized after 5 seconds');
  }

  /// Retry Auth0 client initialization with exponential backoff
  /// Used for error recovery when initial initialization fails
  Future<void> _retryClientInitialization({
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    debugPrint(
      '[Auth0WebService] Starting Auth0 client initialization retry (max $maxRetries attempts)...',
    );

    for (int retry = 1; retry <= maxRetries; retry++) {
      try {
        debugPrint('[Auth0WebService] Retry attempt $retry/$maxRetries');

        // Reset client ready flag to force re-check
        _clientReady = false;

        // Try to wait for client
        await _waitForAuth0Client();

        debugPrint(
          '[Auth0WebService] SUCCESS: Client initialized on retry $retry',
        );
        return;
      } catch (e) {
        debugPrint('[Auth0WebService] Retry $retry failed: $e');

        if (retry < maxRetries) {
          // Calculate exponential backoff delay: 500ms, 1000ms, 2000ms
          final delayMs = initialDelay.inMilliseconds * (1 << (retry - 1));
          final delay = Duration(milliseconds: delayMs);
          debugPrint(
            '[Auth0WebService] Waiting ${delay.inMilliseconds}ms before next retry...',
          );
          await Future.delayed(delay);
        } else {
          debugPrint('[Auth0WebService] ERROR: All retry attempts exhausted');
          throw Exception(
            'Auth0 client initialization failed after $maxRetries retries: $e',
          );
        }
      }
    }
  }

  Future<void> _ensureClientReady() async {
    debugPrint('[Auth0WebService] Ensuring Auth0 client is ready...');

    // Always ensure bridge is ready
    if (!_bridgeReady) {
      debugPrint('[Auth0WebService] Bridge not ready, waiting...');
      await _waitForAuth0Bridge();
    }

    // Always check client readiness (don't rely on cached _clientReady)
    // The client might have been initialized after our first check
    if (auth0Bridge == null) {
      debugPrint('[Auth0WebService] ERROR: Auth0 bridge not available');
      throw Exception('Auth0 bridge not available');
    }

    try {
      debugPrint('[Auth0WebService] Checking if Auth0 client is ready...');
      final isReady = auth0Bridge!.isInitialized();
      debugPrint(
        '[Auth0WebService] Auth0 client initialized check result: $isReady',
      );
      if (isReady) {
        _clientReady = true;
        debugPrint('[Auth0WebService] Auth0 client is ready');
        return;
      } else {
        // Client not ready, try the full wait
        debugPrint('[Auth0WebService] Auth0 client not ready, waiting...');
        _clientReady = false;
        await _waitForAuth0Client();
      }
    } catch (e) {
      debugPrint(
        '[Auth0WebService] ERROR: Auth0 client readiness check failed: $e',
      );
      // For callback handling, try a shorter wait since Auth0 might still be initializing
      try {
        debugPrint(
          '[Auth0WebService] Retrying Auth0 client wait with shorter timeout...',
        );
        await _waitForAuth0ClientShort();
      } catch (e2) {
        debugPrint('[Auth0WebService] ERROR: Short wait also failed: $e2');
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
          debugPrint(' Auth0 client ready (short wait)');
          return;
        }
      } catch (e) {
        debugPrint(' Auth0 client short check error: $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    throw Exception('Auth0 client not initialized after 3 seconds');
  }

  /// Extended timeout specifically for callback processing
  /// Callbacks may need more time as Auth0 client might still be initializing
  /// Includes retry logic with exponential backoff for error recovery
  Future<void> _ensureClientReadyForCallback() async {
    debugPrint(
      '[Auth0WebService] Ensuring client ready for callback processing...',
    );

    // Always ensure bridge is ready first
    if (!_bridgeReady) {
      debugPrint('[Auth0WebService] Waiting for Auth0 bridge...');
      await _waitForAuth0Bridge();
    }

    if (auth0Bridge == null) {
      throw Exception('Auth0 bridge not available');
    }

    // Extended timeout for callback processing: 10 seconds instead of 5
    const maxAttempts = 100; // 10 seconds (100 * 100ms)
    var attempts = 0;

    debugPrint(
      '[Auth0WebService] Checking Auth0 client initialization (extended timeout for callback)...',
    );

    while (attempts < maxAttempts) {
      try {
        final isReady = auth0Bridge!.isInitialized();
        if (isReady) {
          _clientReady = true;
          debugPrint(
            '[Auth0WebService] Auth0 client is ready for callback processing (attempt $attempts)',
          );
          return;
        }
      } catch (e) {
        debugPrint(
          '[Auth0WebService] Auth0 client check error (attempt $attempts): $e',
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;

      // Log progress every 2 seconds
      if (attempts % 20 == 0) {
        debugPrint(
          '[Auth0WebService] Still waiting for Auth0 client... (${attempts / 10} seconds elapsed)',
        );
      }
    }

    // If initial wait failed, try retry with exponential backoff
    debugPrint(
      '[Auth0WebService] Initial wait timed out, attempting retry with exponential backoff...',
    );
    try {
      await _retryClientInitialization(maxRetries: 3);
      debugPrint('[Auth0WebService] SUCCESS: Client ready after retry');
    } catch (e) {
      debugPrint(
        '[Auth0WebService] ERROR: Client initialization failed after retries: $e',
      );
      throw Exception(
        'Auth0 client not initialized after extended timeout and retries: $e',
      );
    }
  }

  @override
  Future<void> login() async {
    debugPrint('[Auth0WebService] ===== LOGIN START =====');
    debugPrint('[Auth0WebService] Starting login process...');

    debugPrint('[Auth0WebService] Ensuring Auth0 client is ready...');
    await _ensureClientReady();

    if (auth0Bridge == null) {
      debugPrint('[Auth0WebService] ERROR: Auth0 bridge not available');
      throw Exception('Auth0 bridge not available');
    }

    debugPrint(
      '[Auth0WebService] Auth0 bridge ready, calling loginWithRedirect',
    );
    final promise = auth0Bridge!.loginWithRedirect();
    debugPrint('[Auth0WebService] Login promise created, awaiting...');
    await promise.toDart;
    debugPrint('[Auth0WebService] Login redirect completed');
    debugPrint('[Auth0WebService] ===== LOGIN COMPLETE =====');
  }

  @override
  Future<void> logout() async {
    debugPrint('[Auth0WebService] ===== LOGOUT START =====');
    debugPrint('[Auth0WebService] Starting logout process...');
    debugPrint('[Auth0WebService] Auth state before: $_isAuthenticated');

    await _ensureClientReady();
    if (auth0Bridge == null) {
      debugPrint('[Auth0WebService] ERROR: Auth0 bridge not available');
      throw Exception('Auth0 bridge not available');
    }

    debugPrint('[Auth0WebService] Calling Auth0 logout...');
    final promise = auth0Bridge!.logout();
    await promise.toDart;

    debugPrint('[Auth0WebService] Clearing authentication state');
    _isAuthenticated = false;
    _currentUser = null;
    _accessToken = null;
    debugPrint('[Auth0WebService] Auth state after: $_isAuthenticated');
    _authStateController.add(false);
    debugPrint('[Auth0WebService] ===== LOGOUT COMPLETE =====');
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
    debugPrint(
      '[Auth0WebService] Starting Auth0 redirect callback handling...',
    );
    try {
      // Implement extended timeout for Auth0 client initialization during callback processing
      debugPrint(
        '[Auth0WebService] Ensuring Auth0 client is ready for callback...',
      );
      await _ensureClientReadyForCallback();

      if (auth0Bridge == null) {
        debugPrint(
          '[Auth0WebService] ERROR: Auth0 bridge not available for callback',
        );
        return false;
      }

      debugPrint(
        '[Auth0WebService] Auth0 client ready, calling handleRedirectCallback...',
      );
      final promise = auth0Bridge!.handleRedirectCallback();
      final result = await promise.toDart;
      final resultData = result.dartify();
      debugPrint(
        '[Auth0WebService] Auth0 handleRedirectCallback bridge result: $resultData',
      );

      // Check if the result indicates success
      final success = resultData is Map && resultData['success'] == true;
      debugPrint('[Auth0WebService] Callback processing success: $success');

      if (success) {
        // Immediately call checkAuthStatus after successful callback to retrieve tokens
        debugPrint(
          '[Auth0WebService] Callback successful, immediately checking auth status to retrieve tokens...',
        );
        await checkAuthStatus();
        debugPrint(
          '[Auth0WebService] Auth status after callback: $_isAuthenticated',
        );

        // Verify that tokens are actually retrieved after handleRedirectCallback succeeds
        if (_accessToken != null && _currentUser != null) {
          debugPrint(
            '[Auth0WebService] SUCCESS: Tokens and user data retrieved successfully',
          );
          debugPrint(
            '[Auth0WebService] Access token available: ${_accessToken != null}',
          );
          debugPrint(
            '[Auth0WebService] User data available: ${_currentUser != null}',
          );
          return true;
        } else {
          // Return false if tokens are not available even when callback reports success
          debugPrint(
            '[Auth0WebService] ERROR: Callback succeeded but tokens not available',
          );
          debugPrint('[Auth0WebService] Access token: ${_accessToken != null}');
          debugPrint('[Auth0WebService] User data: ${_currentUser != null}');
          return false;
        }
      } else {
        // Add detailed error logging for callback processing failures
        debugPrint(
          '[Auth0WebService] ERROR: Callback failed with result: $resultData',
        );
        if (resultData is Map) {
          debugPrint('[Auth0WebService] Error details: ${resultData['error']}');
          debugPrint(
            '[Auth0WebService] Error description: ${resultData['error_description']}',
          );
        }
        return false;
      }
    } catch (e, stackTrace) {
      // Add detailed error logging for callback processing failures
      debugPrint(
        '[Auth0WebService] ERROR: Exception during redirect callback: $e',
      );
      debugPrint('[Auth0WebService] Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> checkAuthStatus() async {
    debugPrint('[Auth0WebService] Checking authentication status...');
    try {
      // Try to ensure client is ready, but don't fail if it's not
      try {
        await _ensureClientReady();
      } catch (e) {
        debugPrint(
          '[Auth0WebService] Auth0 client not ready for auth check: $e',
        );
        debugPrint('[Auth0WebService] Setting auth state to false');
        _isAuthenticated = false;
        _authStateController.add(false);
        return;
      }

      if (auth0Bridge == null) {
        debugPrint('[Auth0WebService] Auth0 bridge not available');
        _isAuthenticated = false;
        _authStateController.add(false);
        return;
      }

      debugPrint('[Auth0WebService] Calling Auth0 isAuthenticated()...');
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

      debugPrint(
        '[Auth0WebService] Auth status check result: $_isAuthenticated',
      );

      if (_isAuthenticated) {
        debugPrint(
          '[Auth0WebService] User is authenticated, retrieving user data and tokens...',
        );
        // getUser returns a JSON string from our modified bridge
        final userJsonPromise = auth0Bridge!.getUser();
        final userJson = await userJsonPromise.toDart;
        final tokenPromise = auth0Bridge!.getAccessToken();
        final token = await tokenPromise.toDart;

        if (userJson != null) {
          _currentUser =
              jsonDecode(userJson.toString()) as Map<String, dynamic>;
          debugPrint(
            '[Auth0WebService] User data retrieved: ${_currentUser?['email']}',
          );
        }
        if (token != null) {
          _accessToken = token.toString();
          debugPrint('[Auth0WebService] Access token retrieved');
        }
      } else {
        debugPrint(
          '[Auth0WebService] User is not authenticated, clearing user data',
        );
        // Clear user data if not authenticated
        _currentUser = null;
        _accessToken = null;
      }

      if (wasAuthenticated != _isAuthenticated) {
        debugPrint(
          '[Auth0WebService] Auth state changed: $wasAuthenticated -> $_isAuthenticated',
        );
        _authStateController.add(_isAuthenticated);
      }
    } catch (e, stackTrace) {
      debugPrint('[Auth0WebService] ERROR: checkAuthStatus failed: $e');
      debugPrint('[Auth0WebService] Stack trace: $stackTrace');
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
