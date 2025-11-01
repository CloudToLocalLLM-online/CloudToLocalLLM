import 'auth0_service.dart';

// Stub implementation for non-web platforms
class Auth0WebService implements Auth0Service {
  @override
  Future<void> initialize() async =>
      throw UnsupportedError('Auth0WebService is only available on the web.');

  @override
  Future<void> login() async =>
      throw UnsupportedError('Auth0WebService is only available on the web.');

  @override
  Future<void> logout() async =>
      throw UnsupportedError('Auth0WebService is only available on the web.');

  @override
  String? getAccessToken() =>
      throw UnsupportedError('Auth0WebService is only available on the web.');

  @override
  Future<bool> handleRedirectCallback() async =>
      throw UnsupportedError('Auth0WebService is only available on the web.');

  @override
  Stream<bool> get authStateChanges =>
      throw UnsupportedError('Auth0WebService is only available on the web.');

  @override
  Map<String, dynamic>? get currentUser =>
      throw UnsupportedError('Auth0WebService is only available on the web.');

  @override
  bool get isAuthenticated =>
      throw UnsupportedError('Auth0WebService is only available on the web.');

  @override
  void dispose() {}
}
