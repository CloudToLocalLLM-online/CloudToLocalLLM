abstract class Auth0Service {
  Future<void> initialize();
  Future<void> login();
  Future<void> logout();
  Future<String?> getIdToken({bool forceRefresh = false});
  String? getAccessToken();
  Future<bool> handleRedirectCallback();
  Stream<bool> get authStateChanges;
  Map<String, dynamic>? get currentUser;
  bool get isAuthenticated;
  void dispose();
}
