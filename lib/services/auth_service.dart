import 'package:flutter/foundation.dart';
import 'auth0_web_service_stub.dart' if (dart.library.html) 'auth0_web_service.dart';
import 'auth0_desktop_service.dart' if (dart.library.html) 'auth0_desktop_service_stub.dart';
import '../models/user_model.dart';

/// Auth0-based Authentication Service
/// Provides authentication for web and desktop using Auth0
class AuthService extends ChangeNotifier {
  Auth0WebService? _auth0Service;
  Auth0DesktopService? _auth0DesktopService;
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;

  AuthService() {
    if (kIsWeb) {
      _initAuth0();
    } else {
      _initAuth0Desktop();
    }
  }

  /// Initialize Auth0 for web platform
  Future<void> _initAuth0() async {
    try {
      _auth0Service = Auth0WebService();
      await _auth0Service!.initialize();
      
      // Listen to Auth0 auth state changes
      _auth0Service!.authStateChanges.listen((isAuth) {
        _isAuthenticated.value = isAuth;
        if (isAuth && _auth0Service!.currentUser != null) {
          _currentUser = UserModel.fromAuth0Profile(_auth0Service!.currentUser!);
        } else {
          _currentUser = null;
        }
        notifyListeners();
      });

      // Check initial auth status
      await _auth0Service!.checkAuthStatus();
      if (_auth0Service!.isAuthenticated && _auth0Service!.currentUser != null) {
        _isAuthenticated.value = true;
        _currentUser = UserModel.fromAuth0Profile(_auth0Service!.currentUser!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint(' Failed to initialize Auth0: $e');
    }
  }

  /// Initialize Auth0 for desktop platform
  Future<void> _initAuth0Desktop() async {
    try {
      _auth0DesktopService = Auth0DesktopService();
      await _auth0DesktopService!.initialize();
      
      // Listen to Auth0 auth state changes
      _auth0DesktopService!.authStateChanges.listen((isAuth) {
        _isAuthenticated.value = isAuth;
        if (isAuth && _auth0DesktopService!.currentUser != null) {
          _currentUser = UserModel.fromAuth0Profile(_auth0DesktopService!.currentUser!);
        } else {
          _currentUser = null;
        }
        notifyListeners();
      });

      // Check initial auth status
      await _auth0DesktopService!.checkAuthStatus();
      if (_auth0DesktopService!.isAuthenticated && _auth0DesktopService!.currentUser != null) {
        _isAuthenticated.value = true;
        _currentUser = UserModel.fromAuth0Profile(_auth0DesktopService!.currentUser!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint(' Failed to initialize Auth0 Desktop: $e');
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
      if (kIsWeb) {
        if (_auth0Service == null) {
          await _initAuth0();
        }
        await _auth0Service!.login();
        // Note: login() will redirect, so code after this won't execute immediately
      } else {
        if (_auth0DesktopService == null) {
          await _initAuth0Desktop();
        }
        await _auth0DesktopService!.login();
      }
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
      if (kIsWeb && _auth0Service != null) {
        await _auth0Service!.logout();
        // Note: logout() will redirect, so code after this won't execute immediately
      } else if (!kIsWeb && _auth0DesktopService != null) {
        await _auth0DesktopService!.logout();
        _isAuthenticated.value = false;
        _currentUser = null;
        notifyListeners();
      } else {
        _isAuthenticated.value = false;
        _currentUser = null;
        notifyListeners();
      }
    } catch (e) {
      _isLoading.value = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get access token (Auth0 JWT)
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (kIsWeb) {
      return _auth0Service?.accessToken;
    } else {
      return _auth0DesktopService?.accessToken;
    }
  }

  /// Legacy compatibility method
  String? getAccessToken() {
    if (kIsWeb) {
      return _auth0Service?.accessToken;
    } else {
      return _auth0DesktopService?.accessToken;
    }
  }

  /// Get validated access token (alias for getIdToken)
  Future<String?> getValidatedAccessToken() async {
    return await getIdToken(forceRefresh: true);
  }

  /// Handle callback after authentication redirect
  Future<bool> handleCallback({String? callbackUrl}) async {
    if (kIsWeb && _auth0Service != null) {
      return await _auth0Service!.handleRedirectCallback();
    } else if (!kIsWeb && _auth0DesktopService != null) {
      // Parse callback URL and extract code and state
      if (callbackUrl != null) {
        final uri = Uri.parse(callbackUrl);
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];
        if (code != null && state != null) {
          await _auth0DesktopService!.handleAuthorizationCode(code, state);
          return true;
        }
      }
      return false;
    }
    return false;
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
    _auth0Service?.dispose();
    _auth0DesktopService?.dispose();
    super.dispose();
  }
}
