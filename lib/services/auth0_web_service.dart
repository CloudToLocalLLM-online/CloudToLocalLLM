// ignore_for_file: avoid_web_libraries_in_flutter
// dart:js_util is required for Auth0 bridge integration and doesn't have a direct dart:js_interop equivalent
import 'dart:async';
import 'dart:js_util' as js_util; // ignore: deprecated_member_use
import 'package:flutter/foundation.dart';

/// Auth0 Web Service for Flutter Web
/// Provides authentication using Auth0's JavaScript SDK
class Auth0WebService {
  static final Auth0WebService _instance = Auth0WebService._internal();
  factory Auth0WebService() => _instance;
  Auth0WebService._internal();

  final _authStateController = StreamController<bool>.broadcast();
  Stream<bool> get authStateChanges => _authStateController.stream;

  bool _isInitialized = false;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;

  /// Check if Auth0 is initialized
  bool get isInitialized => _isInitialized;

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated;

  /// Get current user info
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Get access token
  String? get accessToken => _accessToken;

  /// Initialize Auth0 service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Wait for Auth0 bridge to be available
      await _waitForAuth0Bridge();

      // Check if already authenticated (e.g., after redirect)
      await checkAuthStatus();

      _isInitialized = true;
      debugPrint('✅ Auth0 Web Service initialized');
    } catch (e) {
      debugPrint('❌ Auth0 Web Service initialization error: $e');
      rethrow;
    }
  }

  /// Wait for Auth0 bridge to be available
  Future<void> _waitForAuth0Bridge() async {
    const maxAttempts = 50; // 5 seconds
    var attempts = 0;

    while (attempts < maxAttempts) {
      if (_isAuth0BridgeAvailable()) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    throw Exception('Auth0 bridge not available after 5 seconds');
  }

  /// Check if Auth0 bridge is available
  bool _isAuth0BridgeAvailable() {
    try {
      final bridge = js_util.getProperty(js_util.globalThis, 'auth0Bridge');
      if (bridge == null) return false;
      
      final result = js_util.callMethod(bridge, 'isInitialized', []);
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Login with Auth0 Universal Login
  Future<void> login() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('🔐 Starting Auth0 login redirect...');
      final bridge = js_util.getProperty(js_util.globalThis, 'auth0Bridge');
      if (bridge == null) throw Exception('Auth0 bridge not available');
      
      await js_util.promiseToFuture(js_util.callMethod(bridge, 'loginWithGoogle', []));
      // Note: This will redirect the page, so code after this won't execute
    } catch (e) {
      debugPrint('❌ Auth0 login error: $e');
      rethrow;
    }
  }

  /// Check authentication status
  Future<void> checkAuthStatus() async {
    try {
      final bridge = js_util.getProperty(js_util.globalThis, 'auth0Bridge');
      if (bridge == null) return;
      
      final isAuth = await js_util.promiseToFuture(js_util.callMethod(bridge, 'isAuthenticated', []));
      final wasAuthenticated = _isAuthenticated;
      _isAuthenticated = isAuth == true;

      if (_isAuthenticated) {
        // Get user info and token
        final user = await js_util.promiseToFuture(js_util.callMethod(bridge, 'getUser', []));
        final token = await js_util.promiseToFuture(js_util.callMethod(bridge, 'getAccessToken', []));

        _currentUser = user != null ? Map<String, dynamic>.from(js_util.dartify(user) as Map) : null;
        _accessToken = token?.toString();

        debugPrint('✅ User authenticated: ${_currentUser?['email'] ?? _currentUser?['sub']}');
      } else {
        _currentUser = null;
        _accessToken = null;
      }

      // Notify listeners if auth state changed
      if (wasAuthenticated != _isAuthenticated) {
        _authStateController.add(_isAuthenticated);
      }
    } catch (e) {
      debugPrint('❌ Error checking auth status: $e');
      _isAuthenticated = false;
      _currentUser = null;
      _accessToken = null;
    }
  }

  /// Handle redirect callback after Auth0 login
  Future<bool> handleRedirectCallback() async {
    try {
      debugPrint('🔄 Handling Auth0 redirect callback...');
      final bridge = js_util.getProperty(js_util.globalThis, 'auth0Bridge');
      if (bridge == null) return false;
      
      final result = await js_util.promiseToFuture(js_util.callMethod(bridge, 'handleRedirectCallback', []));
      final resultMap = result != null ? Map<String, dynamic>.from(js_util.dartify(result) as Map) : null;
      
      if (resultMap != null && resultMap['success'] == true) {
        debugPrint('✅ Auth0 callback handled successfully');
        await checkAuthStatus();
        return true;
      } else {
        debugPrint('⚠️ No Auth0 callback to handle');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error handling redirect callback: $e');
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      debugPrint('🔐 Logging out from Auth0...');
      final bridge = js_util.getProperty(js_util.globalThis, 'auth0Bridge');
      if (bridge == null) throw Exception('Auth0 bridge not available');
      
      await js_util.promiseToFuture(js_util.callMethod(bridge, 'logout', []));
      
      _isAuthenticated = false;
      _currentUser = null;
      _accessToken = null;
      _authStateController.add(false);
      
      // Note: This will redirect the page, so code after this won't execute
    } catch (e) {
      debugPrint('❌ Auth0 logout error: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}

