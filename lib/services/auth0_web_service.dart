// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth0_service.dart';
import 'auth0_bridge_interop.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Auth0 Web Service for Flutter Web
/// Provides authentication using Auth0's JavaScript SDK
class Auth0WebService implements Auth0Service {
  static final Auth0WebService _instance = Auth0WebService._internal();
  factory Auth0WebService() => _instance;
  Auth0WebService._internal();

  final _authStateController = StreamController<bool>.broadcast();
  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  bool _isInitialized = false;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;

  /// Check if Auth0 is initialized
  bool get isInitialized => _isInitialized;

  /// Check if user is authenticated
  @override
  bool get isAuthenticated => _isAuthenticated;

  /// Get current user info
  @override
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Get access token
  String? get accessToken => _accessToken;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await checkAuthStatus();
    }
    return _accessToken;
  }

  @override
  String? getAccessToken() {
    return _accessToken;
  }

  /// Initialize Auth0 service
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _waitForAuth0Bridge();
      await checkAuthStatus();
      _isInitialized = true;
      debugPrint('Auth0 Web Service initialized');
    } catch (e) {
      debugPrint('Auth0 Web Service initialization error: $e');
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
    return auth0Bridge?.isInitialized() ?? false;
  }

  /// Login with Auth0 Universal Login
  @override
  Future<void> login() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('Starting Auth0 login redirect...');
      await auth0Bridge!.loginWithGoogle().toDart;
    } catch (e, stackTrace) {
      debugPrint('Auth0 login error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check authentication status
  Future<void> checkAuthStatus() async {
    try {
      final isAuth = await auth0Bridge!.isAuthenticated().toDart;
      final wasAuthenticated = _isAuthenticated;
      _isAuthenticated = isAuth.isA<JSBoolean>() && isAuth.toDart;

      if (_isAuthenticated) {
        final user = await auth0Bridge!.getUser().toDart;
        final token = await auth0Bridge!.getAccessToken().toDart;

        if (user != null && user.isA<JSObject>()) {
          _currentUser = _jsObjectToMap(user as JSObject);
        } else {
          _currentUser = null;
        }
        
        if (token != null && token.isA<JSString>()) {
          _accessToken = token.toDart;
        } else {
          _accessToken = null;
        }

        debugPrint('User authenticated: ${_currentUser?['email'] ?? _currentUser?['sub']}');
      } else {
        _currentUser = null;
        _accessToken = null;
      }

      if (wasAuthenticated != _isAuthenticated) {
        _authStateController.add(_isAuthenticated);
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      _isAuthenticated = false;
      _currentUser = null;
      _accessToken = null;
    }
  }

  /// Handle redirect callback after Auth0 login
  @override
  Future<bool> handleRedirectCallback() async {
    try {
      debugPrint('Handling Auth0 redirect callback...');
      final result = await auth0Bridge!.handleRedirectCallback().toDart;
      
      if (result != null && result.isA<JSObject>()) {
        final resultMap = _jsObjectToMap(result as JSObject);
        if (resultMap['success'] == true) {
          debugPrint('Auth0 callback handled successfully');
          await checkAuthStatus();
          return true;
        } else {
          final error = resultMap['error']?.toString() ?? 'Unknown error';
          final errorCode = resultMap['errorCode']?.toString();
          debugPrint(' Auth0 callback error: $error (code: $errorCode)');
          if (error.contains('Service not found')) {
            debugPrint(' Auth0 API not configured - authentication will work but tokens won\'t be scoped');
          }
          return false;
        }
      } else {
        debugPrint(' No Auth0 callback to handle');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint(' Error handling redirect callback: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Logout
  @override
  Future<void> logout() async {
    try {
      debugPrint(' Logging out from Auth0...');
      await auth0Bridge!.logout().toDart;
      
      _isAuthenticated = false;
      _currentUser = null;
      _accessToken = null;
      _authStateController.add(false);
    } catch (e) {
      debugPrint(' Auth0 logout error: $e');
      rethrow;
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _authStateController.close();
  }

  Map<String, dynamic> _jsObjectToMap(JSObject jsObject) {
    final map = <String, dynamic>{};
    final keys = jsObject.globalContext['Object']
        .getProperty('keys'.toJS)
        .callAsFunction(jsObject.jsify())!
        .dartify() as List;
    for (final key in keys) {
      map[key.toString()] = jsObject.getProperty(key.toString().toJS)?.dartify();
    }
    return map;
  }
}

