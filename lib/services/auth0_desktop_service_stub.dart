// Stub for Auth0DesktopService on web platform
import 'dart:async';
import 'auth0_service.dart';

/// Stub implementation of Auth0DesktopService for web platform
class Auth0DesktopServiceStub implements Auth0Service {
  @override
  Stream<bool> get authStateChanges => Stream.value(false);

  @override
  Map<String, dynamic>? get currentUser => null;

  @override
  void dispose() {}

  @override
  String? getAccessToken() => null;

  @override
  Future<bool> handleRedirectCallback() async => false;

  @override
  Future<void> initialize() async {}

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> login() async {}

  @override
  Future<void> logout() async {}
}

