import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth0_service.dart';

/// Auth0-based Authentication Service
/// Provides authentication for web and desktop using Auth0
class AuthService extends ChangeNotifier {
  final Auth0Service _auth0Service;
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;

  AuthService(this._auth0Service) {
    _initAuth0();
  }

  /// Initialize Auth0
  Future<void> _initAuth0() async {
    try {
      await _auth0Service.initialize();
      
      // Listen to Auth0 auth state changes
      _auth0Service.authStateChanges.listen((isAuth) {
        _isAuthenticated.value = isAuth;
        if (isAuth && _auth0Service.currentUser != null) {
          _currentUser = UserModel.fromAuth0Profile(_auth0Service.currentUser!);
        } else {
          _currentUser = null;
        }
        notifyListeners();
      });

      // Check initial auth status
      await _checkAuthStatus();
    } catch (e) {
      debugPrint(' Failed to initialize Auth0: $e');
    }
  }

  Future<void> _checkAuthStatus() async {
    if (_auth0Service.isAuthenticated && _auth0Service.currentUser != null) {
      _isAuthenticated.value = true;
      _currentUser = UserModel.fromAuth0Profile(_auth0Service.currentUser!);
      notifyListeners();
    }
  }

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  
  // Platform detection
  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;
  bool get isDesktop => !kIsWeb;

  /// Login with Auth0
  Future<void> login({String? tenantId}) async {
    _isLoading.value = true;
    notifyListeners();

    try {
      await _auth0Service.login();
      // Note: login() will redirect, so code after this won't execute immediately
    } catch (e) {
      _isLoading.value = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Logout from Auth0
  Future<void> logout() async {
    _isLoading.value = true;
    notifyListeners();

    try {
      await _auth0Service.logout();
      _isAuthenticated.value = false;
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _isLoading.value = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Legacy compatibility method
  Future<String?> getAccessToken() async {
    if (!_auth0Service.isAuthenticated) {
      return null;
    }
    return _auth0Service.getAccessToken();
  }

  /// Get validated access token (alias for getIdToken)
  Future<String?> getValidatedAccessToken() async {
    return await getAccessToken();
  }

  /// Handle callback after authentication redirect
  Future<bool> handleCallback({String? callbackUrl}) async {
    if (kIsWeb) {
      return await _auth0Service.handleRedirectCallback();
    } else {
       // On desktop, the callback is handled differently via deep linking or a local server.
       // This logic assumes the desktop service will handle the full flow internally.
       return true;
    }
  }

  /// Update user display name (not supported with Auth0 - managed in Auth0 dashboard)
  Future<void> updateDisplayName(String displayName) async {
    // Auth0 user profiles are managed via Auth0 dashboard or Management API
    // For now, we'll just log a warning
    debugPrint('updateDisplayName called but Auth0 profiles are managed externally. Use Auth0 Management API to update user profiles.');
    // Update local user model if available
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(name: displayName);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    _auth0Service.dispose();
    super.dispose();
  }
}
