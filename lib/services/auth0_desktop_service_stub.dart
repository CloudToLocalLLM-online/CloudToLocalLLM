// Stub for Auth0DesktopService on web platform
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Stub implementation of Auth0DesktopService for web platform
class Auth0DesktopService {
  static final Auth0DesktopService _instance = Auth0DesktopService._internal();
  factory Auth0DesktopService() => _instance;
  Auth0DesktopService._internal();

  final bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  Stream<bool> get authStateChanges => _authStateController.stream;

  Future<void> initialize() async {
    debugPrint(' Auth0DesktopService: Not available on web platform');
  }

  Future<void> checkAuthStatus() async {
    // No-op on web
  }

  Future<void> login() async {
    throw UnsupportedError('Auth0 desktop login is only available on desktop platform');
  }

  Future<void> logout() async {
    // No-op on web
  }

  Future<void> handleAuthorizationCode(String code, String state) async {
    throw UnsupportedError('Auth0 desktop callback is only available on desktop platform');
  }

  void dispose() {
    _authStateController.close();
  }
}

