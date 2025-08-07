import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';

// Platform-specific imports
import 'auth_service_web_simple.dart';

/// Platform-aware Authentication service for CloudToLocalLLM
/// Uses web-simple auth for web and Firebase for mobile
/// Replaces Auth0 with modern authentication solutions
class AuthService extends ChangeNotifier {
  late final AuthServiceWebSimple _platformService;
  
  // Constructor
  AuthService() {
    _initialize();
  }
  
  /// Initialize the platform-specific service
  void _initialize() {
    if (kIsWeb) {
      _platformService = AuthServiceWebSimple();
    } else {
      // For mobile, we would use Firebase, but for now use web simple
      _platformService = AuthServiceWebSimple();
    }
    
    // Listen to platform service changes
    _platformService.addListener(_onPlatformServiceChanged);
  }
  
  /// Handle platform service changes
  void _onPlatformServiceChanged() {
    notifyListeners();
  }
  
  // Getters that delegate to platform service
  ValueNotifier<bool> get isAuthenticated => _platformService.isAuthenticated;
  ValueNotifier<bool> get isLoading => _platformService.isLoading;
  UserModel? get currentUser => _platformService.currentUser;
  String? get accessToken => _platformService.accessToken;
  
  // Platform detection
  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;
  bool get isDesktop => !kIsWeb;
  
  /// Login using platform-specific implementation
  Future<void> login() async {
    return await _platformService.login();
  }
  
  /// Sign in with email and password
  Future<void> signInWithEmailPassword(String email, String password) async {
    return await _platformService.signInWithEmailPassword(email, password);
  }
  
  /// Create account with email and password
  Future<void> createAccountWithEmailPassword(
    String email, 
    String password, 
    String displayName
  ) async {
    return await _platformService.createAccountWithEmailPassword(email, password, displayName);
  }
  
  /// Logout using platform-specific implementation
  Future<void> logout() async {
    return await _platformService.logout();
  }
  
  /// Handle Auth0 callback (legacy compatibility)
  Future<bool> handleCallback({String? callbackUrl}) async {
    return await _platformService.handleCallback(callbackUrl: callbackUrl);
  }
  
  /// Mobile-specific: Login with biometric authentication
  Future<void> loginWithBiometrics() async {
    return await _platformService.loginWithBiometrics();
  }
  
  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    return await _platformService.isBiometricAvailable();
  }
  
  /// Get current user's ID token
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _platformService.getIdToken(forceRefresh: forceRefresh);
  }
  
  /// Legacy compatibility methods for existing services
  
  /// Get access token (alias for getIdToken)
  String? getAccessToken() {
    return _platformService.getAccessToken();
  }
  
  /// Get validated access token (async version)
  Future<String?> getValidatedAccessToken() async {
    return await _platformService.getValidatedAccessToken();
  }
  
  /// Check if token is valid
  bool get isTokenValid {
    return _platformService.isTokenValid;
  }
  
  /// Get token expiry time
  DateTime? get tokenExpiryTime {
    return _platformService.tokenExpiryTime;
  }
  
  /// Refresh token if needed
  Future<void> refreshTokenIfNeeded() async {
    return await _platformService.refreshTokenIfNeeded();
  }
  
  /// Get platform information
  Map<String, dynamic> getPlatformInfo() {
    return _platformService.getPlatformInfo();
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _platformService.removeListener(_onPlatformServiceChanged);
    _platformService.dispose();
    super.dispose();
  }
}
