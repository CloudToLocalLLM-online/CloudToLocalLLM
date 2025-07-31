// Web-specific platform detection and authentication service factory
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'auth_service_web.dart';
import 'auth_storage_service.dart';

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

  /// Load stored tokens from SQLite database
  Future<void> _loadStoredTokens() async {
    try {
      print('🔐 [DEBUG] Loading stored tokens from SQLite database...');

      final hasValidTokens = await AuthStorageService.hasValidTokens();
      print('🔐 [DEBUG] Valid tokens found: ${hasValidTokens ? "YES" : "NO"}');

      if (hasValidTokens) {
        print('🔐 [DEBUG] Tokens are valid, setting authentication state');
        _platformService.isAuthenticated.value = true;
        _platformService.notifyListeners();
        print('🔐 [DEBUG] Authentication state restored from SQLite storage');
      } else {
        print('🔐 [DEBUG] No valid stored tokens found in SQLite');
      }
    } catch (e) {
      print('🔐 [DEBUG] Error loading stored tokens from SQLite: $e');
    }
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
      '🔐 [DEBUG] AuthServicePlatform.handleCallback - DIRECT IMPLEMENTATION',
    );

    try {
      // Direct implementation to bypass delegation issues
      if (callbackUrl == null) return false;

      final uri = Uri.parse(callbackUrl);
      final code = uri.queryParameters['code'];

      if (code == null) return false;

      print('🔐 [DEBUG] Found authorization code, exchanging for tokens...');

      // Direct token exchange
      print('🔐 [DEBUG] Making HTTP POST request to Auth0 token endpoint...');
      final response = await http.post(
        Uri.https('dev-v2f2p008x3dr74ww.us.auth0.com', '/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'grant_type': 'authorization_code',
          'client_id': 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A',
          'code': code,
          'redirect_uri': 'https://app.cloudtolocalllm.online/callback',
          'audience': 'https://app.cloudtolocalllm.online',
        }),
      );
      print('🔐 [DEBUG] HTTP response received: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['access_token'] as String?;
        final idToken = data['id_token'] as String?;

        if (accessToken != null) {
          // Store tokens in SQLite database
          final expiry = DateTime.now().add(Duration(hours: 1));

          await AuthStorageService.storeTokens(
            accessToken: accessToken,
            idToken: idToken,
            expiresAt: expiry,
            audience: 'https://app.cloudtolocalllm.online',
          );

          print('🔐 [DEBUG] Tokens stored successfully in SQLite database');

          // Set authentication state
          _platformService.isAuthenticated.value = true;
          _platformService.notifyListeners();

          return true;
        }
      }

      print('🔐 [DEBUG] Token exchange failed: ${response.statusCode}');
      return false;
    } catch (e) {
      print('🔐 [DEBUG] Error in handleCallback: $e');
      return false;
    }
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
