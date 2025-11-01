import 'auth0_service.dart';

// Stub implementation for web
class Auth0DesktopService implements Auth0Service {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> login() async {}

  @override
  Future<void> logout() async {}

  @override
  String? getAccessToken() => null;

  @override
  Future<bool> handleRedirectCallback() async => false;

  @override
  Stream<bool> get authStateChanges => Stream.value(false);

  @override
  Map<String, dynamic>? get currentUser => null;

  @override
  bool get isAuthenticated => false;

  @override
  void dispose() {}
}
