// Stub for Auth0DesktopService on web platform
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth0_service.dart';

/// Stub implementation of Auth0DesktopService for web platform
class Auth0DesktopService implements Auth0Service {
  @override
  Stream<bool> get authStateChanges => Stream.value(false);

  @override
  Map<String, dynamic>? get currentUser => null;

  @override
  void dispose() {}

  @override
  String? getAccessToken() => null;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  Future<bool> handleRedirectCallback() async {
    throw UnsupportedError('Desktop callback is not available on web platform');
  }

  @override
  Future<void> initialize() async {
    debugPrint('Auth0DesktopService: Not available on web platform');
  }

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> login() async {
    throw UnsupportedError('Auth0 desktop login is only available on desktop platform');
  }

  @override
  Future<void> logout() async {}
}

