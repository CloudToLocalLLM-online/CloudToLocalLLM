// Web-specific platform detection and authentication service factory
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service_web.dart';

/// Web platform authentication service factory
class AuthServicePlatform extends ChangeNotifier {
  late final AuthServiceWeb _platformService;

  // Platform detection - always web
  static bool get isWeb => true;
  static bool get isMobile => false;
  static bool get isDesktop => false;

  // Getters that delegate to web service
  ValueNotifier<bool> get isAuthenticated => _platformService.isAuthenticated;
  ValueNotifier<bool> get isLoading => _platformService.isLoading;
  UserModel? get currentUser => _platformService.currentUser;

  AuthServicePlatform() {
    _initialize();
    _loadStoredTokens(); // Fire and forget - async initialization
  }

  void _initialize() {
    print('🔐 [DEBUG] AuthServicePlatform._initialize() called');
    _platformService = AuthServiceWeb();
    print(
      '🔐 [DEBUG] AuthServiceWeb instance created: ${_platformService.runtimeType}',
    );
    debugPrint('🌐 Initialized Web Authentication Service');

    // Listen to platform service changes
    _platformService.addListener(() {
      notifyListeners();
    });
    print('🔐 [DEBUG] AuthServicePlatform initialization complete');
  }

  /// Load stored tokens and restore authentication state
  /// This is handled by the web service itself during initialization
  Future<void> _loadStoredTokens() async {
    // The AuthServiceWeb handles its own token loading and user profile restoration
    // during initialization. No additional logic needed here.
    print(
      '🔐 [DEBUG] Platform service delegating token loading to web service',
    );
  }

  /// Login using web implementation
  Future<void> login() async {
    return await _platformService.login();
  }

  /// Logout using web implementation
  Future<void> logout() async {
    return await _platformService.logout();
  }

  /// Handle authentication callback using web implementation
  Future<bool> handleCallback({String? callbackUrl}) async {
    print(
      '🔐 [DEBUG] AuthServicePlatform.handleCallback - delegating to web service',
    );

    // Delegate to the web service which has proper user profile loading
    return await _platformService.handleCallback(callbackUrl: callbackUrl);
  }

  /// Mobile-specific methods - not supported on web
  Future<void> loginWithBiometrics() async {
    throw UnsupportedError('Biometric authentication is not available on web');
  }

  Future<bool> isBiometricAvailable() async {
    return false;
  }

  Future<void> refreshTokenIfNeeded() async {
    // Not needed for web - handled automatically
  }

  /// Get platform-specific information for debugging
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': 'Web',
      'isWeb': true,
      'isMobile': false,
      'isDesktop': false,
      'serviceType': 'AuthServiceWeb',
      'isAuthenticated': isAuthenticated.value,
      'isLoading': isLoading.value,
      'hasUser': currentUser != null,
    };
  }

  /// Get the current access token for API authentication
  String? getAccessToken() {
    return _platformService.accessToken;
  }

  String getPlatformName() => 'Web';

  /// Platform capability checks
  bool get supportsBiometrics => false;
  bool get supportsDeepLinking => false;
  bool get supportsSecureStorage => false;

  /// Get recommended authentication method for web
  String get recommendedAuthMethod => 'redirect';

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }
}
