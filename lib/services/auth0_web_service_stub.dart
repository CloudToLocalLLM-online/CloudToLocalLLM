// Stub for Auth0WebService on non-web platforms
import 'package:flutter/foundation.dart';
import 'auth0_service.dart';

class Auth0WebService implements Auth0Service {
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
  Future<bool> handleRedirectCallback() async => false;

  @override
  Future<void> initialize() async {
    debugPrint('Auth0WebService: Not available on this platform');
  }

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> login() async {}

  @override
  Future<void> logout() async {}
}

