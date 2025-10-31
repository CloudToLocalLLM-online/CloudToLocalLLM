// Re-export GCIP Auth Service as AuthService
export 'gcip_auth_service.dart' show GCIPAuthService;

// Create alias for backwards compatibility
import 'package:flutter/foundation.dart';
import 'gcip_auth_service.dart';
import 'auth0_web_service.dart';

class AuthService extends GCIPAuthService {
  AuthService() : super() {
    // Initialize Auth0 for web platform
    if (kIsWeb) {
      _initAuth0();
    }
  }

  Auth0WebService? _auth0Service;

  void _initAuth0() async {
    try {
      _auth0Service = Auth0WebService();
      await _auth0Service!.initialize();
      
      // Listen to Auth0 auth state and sync with GCIP service
      _auth0Service!.authStateChanges.listen((isAuth) {
        if (isAuth) {
          // Notify GCIP service that user is authenticated
          isAuthenticated.value = true;
          user.value = _auth0Service!.currentUser;
          notifyListeners();
        } else {
          isAuthenticated.value = false;
          user.value = null;
          notifyListeners();
        }
      });

      // Check initial auth status
      await _auth0Service!.checkAuthStatus();
    } catch (e) {
      debugPrint('❌ Failed to initialize Auth0: $e');
    }
  }

  @override
  Future<void> login({String? tenantId}) async {
    if (kIsWeb && _auth0Service != null) {
      // Use Auth0 for web
      await _auth0Service!.login();
    } else {
      // Use GCIP for mobile/desktop
      await super.login(tenantId: tenantId);
    }
  }

  @override
  Future<void> logout() async {
    if (kIsWeb && _auth0Service != null) {
      // Use Auth0 for web
      await _auth0Service!.logout();
    } else {
      // Use GCIP for mobile/desktop
      await super.logout();
    }
  }

  /// Get access token (Auth0 for web, GCIP for mobile/desktop)
  @override
  Future<String?> getIdToken() async {
    if (kIsWeb && _auth0Service != null) {
      return _auth0Service!.accessToken;
    } else {
      return super.getIdToken();
    }
  }
}
