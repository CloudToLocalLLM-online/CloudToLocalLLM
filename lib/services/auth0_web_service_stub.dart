// Stub for Auth0WebService on non-web platforms
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Stub implementation of Auth0WebService for desktop/mobile platforms
class Auth0WebService {
  static final Auth0WebService _instance = Auth0WebService._internal();
  factory Auth0WebService() => _instance;
  Auth0WebService._internal();

  bool _isInitialized = false;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();

  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  Stream<bool> get authStateChanges => _authStateController.stream;

  Future<void> initialize() async {
    debugPrint('⚠️ Auth0WebService: Not available on desktop platform');
    _isInitialized = true;
  }

  Future<void> checkAuthStatus() async {
    // No-op on desktop
  }

  Future<void> login() async {
    throw UnsupportedError('Auth0 login is only available on web platform');
  }

  Future<void> loginWithGoogle() async {
    throw UnsupportedError('Auth0 login is only available on web platform');
  }

  Future<void> logout() async {
    // No-op on desktop
  }

  Future<bool> handleRedirectCallback() async {
    // No-op on desktop
    return false;
  }

  void dispose() {
    _authStateController.close();
  }
}

