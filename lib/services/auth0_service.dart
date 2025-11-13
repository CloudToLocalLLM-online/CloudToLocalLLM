abstract class Auth0Service {
  Future<void> initialize();
  Future<void> login();
  Future<void> logout();
  String? getAccessToken();
  Future<bool> handleRedirectCallback();
  bool isCallbackUrl();
  Stream<bool> get authStateChanges;
  Map<String, dynamic>? get currentUser;
  bool get isAuthenticated;
  void dispose();
}
