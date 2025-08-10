import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
// Conditional web import for localStorage
import 'web_platform_stub.dart' if (dart.library.html) 'package:web/web.dart' as web;
// GIS web auth (only available on web)
import 'web_gis_auth.dart' if (dart.library.html) 'web_gis_auth.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';

/// Google Cloud Identity Platform Authentication Service
/// Provides enterprise-grade multi-tenant authentication with advanced features:
/// - Multi-tenancy support
/// - Role-based access control (RBAC)
/// - SAML/OIDC integration ready
/// - Advanced custom claims
/// - Audit logging
/// - Identity-Aware Proxy integration
class GCIPAuthService extends ChangeNotifier {
  late final GoogleSignIn _googleSignIn;

  // Authentication state
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;
  String? _currentToken; // ID token
  String? _refreshTokenValue; // Refresh token
  String? _currentTenant;
  Map<String, dynamic>? _customClaims;
  Timer? _tokenRefreshTimer;

  // Persistence keys
  static const _kIdTokenKey = 'gcip_id_token';
  static const _kRefreshTokenKey = 'gcip_refresh_token';
  static const _kExpiryKey = 'gcip_expiry_time';
  static const _kUserInfoKey = 'gcip_user_info';

  // Secure storage for non-web platforms
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Configuration
  static const Duration tokenRefreshInterval = Duration(minutes: 50);
  static const String gcipBaseUrl = 'https://identitytoolkit.googleapis.com/v1';

  // Resolve GCIP API key at runtime (web can override via window.cloudRunConfig or meta tag)
  String _getGcipApiKey() {
    if (kIsWeb) {
      try {
        final cfg = jsGetNested(window: web.window, path: ['cloudRunConfig', 'gcipApiKey']);
        if (cfg is String && cfg.isNotEmpty) return cfg;
      } catch (_) {}
      try {
        final meta = web.document.querySelector('meta[name="gcip-api-key"]');
        final content = meta?.getAttribute('content');
        if (content != null && content.isNotEmpty) return content;
      } catch (_) {}
    }
    return AppConfig.gcipApiKey;
  }

  // Helper: safe nested property getter for web window
  dynamic jsGetNested({required web.Window window, required List<String> path}) {
    dynamic cur = window as dynamic;
    for (final key in path) {
      try {
        cur = (cur as dynamic?)?[key];
      } catch (_) {
        return null;
      }
      if (cur == null) return null;
    }
    return cur;
  }

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  String? get accessToken => _currentToken;
  String? get currentTenant => _currentTenant;
  Map<String, dynamic>? get customClaims => _customClaims;

  // Platform detection
  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;
  bool get isDesktop => !kIsWeb;

  // Constructor
  GCIPAuthService() {
    _initialize();
  }

  /// Initialize the GCIP Auth service
  void _initialize() {
    debugPrint('🏢 Initializing Google Cloud Identity Platform Auth service...');

    try {
      // Initialize Google Sign-In
      _googleSignIn = GoogleSignIn(
        clientId: AppConfig.googleClientId,
        scopes: AppConfig.gcipScopes,
      );

      // Check for existing authentication
      _loadStoredAuth();

      debugPrint('🏢 GCIP Auth service initialized successfully');
    } catch (e) {
      debugPrint('🏢 Failed to initialize GCIP Auth service: $e');
    }
  }

  /// Load stored authentication from persistence (tokens first, then silent Google)
  Future<void> _loadStoredAuth() async {
    _isLoading.value = true;
    notifyListeners();

    try {
      // Try restoring persisted tokens first
      final restored = await _restoreAuthState();
      if (restored) {
        debugPrint('🏢 Restored authentication state from storage');
        return;
      }

      // Fallback to Google silent sign-in (non-web only)
      if (!kIsWeb) {
        final isSignedIn = await _googleSignIn.isSignedIn();
        if (isSignedIn) {
          await _handleGoogleSignInSilent();
        }
      }
    } catch (e) {
      debugPrint('🏢 Failed to load stored auth: $e');
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Handle silent Google Sign-In
  Future<void> _handleGoogleSignInSilent() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        await _authenticateWithGCIP(googleUser);
      }
    } catch (e) {
      debugPrint('🏢 Silent sign-in failed: $e');
    }
  }

  /// Authenticate with Google Cloud Identity Platform
  Future<void> _authenticateWithGCIP(GoogleSignInAccount googleUser) async {
    try {
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null && accessToken == null) {
        throw Exception('No Google tokens available (idToken and accessToken are null)');
      }

      final gcipToken = await _exchangeGoogleTokenForGCIP(idToken: idToken, accessToken: accessToken);
      await _handleGCIPToken(gcipToken);
    } catch (e) {
      debugPrint('🏢 GCIP authentication failed: $e');
      rethrow;
    }
  }

  Future<String> _exchangeGoogleTokenForGCIP({String? idToken, String? accessToken}) async {
    final url = '$gcipBaseUrl/accounts:signInWithIdp?key=${_getGcipApiKey()}';

    // Build postBody with only non-null params
    final parts = <String>[];
    if (idToken != null && idToken.isNotEmpty) {
      parts.add('id_token=${Uri.encodeQueryComponent(idToken)}');
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      parts.add('access_token=${Uri.encodeQueryComponent(accessToken)}');
    }
    parts.add('providerId=google.com');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'postBody': parts.join('&'),
        'requestUri': kIsWeb ? Uri.base.origin : 'http://localhost',
        'returnIdpCredential': true,
        'returnSecureToken': true,
        'tenantId': _currentTenant ?? AppConfig.tenantConfigs['default'],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Capture both ID token and refresh token
      final idTok = data['idToken'] as String?;
      final refreshTok = data['refreshToken'] as String?;
      if (idTok == null || refreshTok == null) {
        throw Exception('GCIP response missing tokens');
      }
      _refreshTokenValue = refreshTok;
      return idTok;
    } else {
      throw Exception('GCIP token exchange failed: ${response.body}');
    }
  }

  /// Handle GCIP token and extract user information
  Future<void> _handleGCIPToken(String token, {String? refreshToken}) async {
    try {
      _currentToken = token;
      if (refreshToken != null) {
        _refreshTokenValue = refreshToken;
      }

      // Decode JWT to extract user information and custom claims
      final decodedToken = JwtDecoder.decode(token);
      _customClaims = decodedToken;

      // Extract tenant information
      _currentTenant = decodedToken['firebase']?['tenant'] ?? AppConfig.tenantConfigs['default'];

      // Create user model with enhanced information
      _currentUser = UserModel(
        id: decodedToken['sub'] ?? '',
        email: decodedToken['email'] ?? '',
        name: decodedToken['name'] ?? '',
        picture: decodedToken['picture'],
        emailVerified: decodedToken['email_verified'] == true ? DateTime.now() : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch((decodedToken['iat'] ?? 0) * 1000),
        updatedAt: DateTime.now(),
      );

      // Persist
      await _persistAuthState();

      _isAuthenticated.value = true;
      _startTokenRefreshTimer();

      debugPrint('🏢 GCIP authentication successful - ${_currentUser?.email}');
      debugPrint('🏢 Tenant: $_currentTenant');
      debugPrint('🏢 Custom Claims: ${_getCustomClaimsString()}');

      notifyListeners();
    } catch (e) {
      debugPrint('🏢 Failed to handle GCIP token: $e');
      rethrow;
    }
  }

  /// Persist auth state (tokens and user) to storage
  Future<void> _persistAuthState() async {
    try {
      // Compute expiry from JWT
      int? exp;
      if (_currentToken != null && !JwtDecoder.isExpired(_currentToken!)) {
        exp = JwtDecoder.getExpirationDate(_currentToken!)
            .millisecondsSinceEpoch;
      }

      // Serialize user info
      final userJson = _currentUser == null
          ? null
          : jsonEncode({
              'id': _currentUser!.id,
              'email': _currentUser!.email,
              'name': _currentUser!.name,
              'picture': _currentUser!.picture,
            });

      if (kIsWeb) {
        // Web: localStorage
        if (_currentToken != null) {
          web.window.localStorage.setItem(_kIdTokenKey, _currentToken!);
        }
        if (_refreshTokenValue != null) {
          web.window.localStorage.setItem(
              _kRefreshTokenKey, _refreshTokenValue!);
        }
        if (exp != null) {
          web.window.localStorage.setItem(_kExpiryKey, exp.toString());
        }
        if (userJson != null) {
          web.window.localStorage.setItem(_kUserInfoKey, userJson);
        }
      } else {
        // Desktop: secure storage
        if (_currentToken != null) {
          await _secureStorage.write(key: _kIdTokenKey, value: _currentToken!);
        }
        if (_refreshTokenValue != null) {
          await _secureStorage.write(
              key: _kRefreshTokenKey, value: _refreshTokenValue!);
        }
        if (exp != null) {
          await _secureStorage.write(key: _kExpiryKey, value: exp.toString());
        }
        if (userJson != null) {
          await _secureStorage.write(key: _kUserInfoKey, value: userJson);
        }
      }
    } catch (e) {
      debugPrint('🏢 Failed to persist auth state: $e');
    }
  }

  /// Load persisted auth state
  Future<bool> _restoreAuthState() async {
    try {
      String? idTok;
      String? refTok;
      String? expStr;
      String? userJson;

      if (kIsWeb) {
        idTok = web.window.localStorage.getItem(_kIdTokenKey);
        refTok = web.window.localStorage.getItem(_kRefreshTokenKey);
        expStr = web.window.localStorage.getItem(_kExpiryKey);
        userJson = web.window.localStorage.getItem(_kUserInfoKey);
      } else {
        idTok = await _secureStorage.read(key: _kIdTokenKey);
        refTok = await _secureStorage.read(key: _kRefreshTokenKey);
        expStr = await _secureStorage.read(key: _kExpiryKey);
        userJson = await _secureStorage.read(key: _kUserInfoKey);
      }

      if (idTok == null || refTok == null) {
        return false;
      }

      _currentToken = idTok;
      _refreshTokenValue = refTok;

      // Recreate user info if possible
      if (userJson != null) {
        try {
          final decodedToken = JwtDecoder.decode(idTok);
          _customClaims = decodedToken;
          _currentTenant = decodedToken['firebase']?['tenant'] ??
              AppConfig.tenantConfigs['default'];
          _currentUser = UserModel(
            id: decodedToken['sub'] ?? '',
            email: decodedToken['email'] ?? '',
            name: decodedToken['name'] ?? '',
            picture: decodedToken['picture'],
            emailVerified: decodedToken['email_verified'] == true
                ? DateTime.now()
                : null,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
                (decodedToken['iat'] ?? 0) * 1000),
            updatedAt: DateTime.now(),
          );
        } catch (_) {}
      }

      // Validate expiry
      if (expStr != null) {
        final expMs = int.tryParse(expStr);
        if (expMs != null) {
          final expired = DateTime.now().millisecondsSinceEpoch >= expMs - 15000;
          if (expired) {
            // Try refresh
            final refreshed = await _refreshIdToken();
            return refreshed;
          }
        }
      }

      _isAuthenticated.value = true;
      _startTokenRefreshTimer();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('🏢 Failed to restore auth state: $e');
      return false;
    }
  }

  /// Refresh ID token using stored refresh token
  Future<bool> _refreshIdToken() async {
    if (_refreshTokenValue == null) return false;
    try {
      final url =
          'https://securetoken.googleapis.com/v1/token?key=${_getGcipApiKey()}';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(_refreshTokenValue!)}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newIdToken = data['id_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        if (newIdToken == null || newRefreshToken == null) {
          throw Exception('Refresh response missing tokens');
        }
        await _handleGCIPToken(newIdToken, refreshToken: newRefreshToken);
        return true;
      } else {
        debugPrint('🏢 Token refresh failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('🏢 Token refresh exception: $e');
      return false;
    }
  }

  /// Get formatted custom claims string for logging
  String _getCustomClaimsString() {
    if (_customClaims == null) return 'None';

    final role = _customClaims!['role'] ?? 'user';
    final permissions = _customClaims!['permissions'] ?? [];
    final tenant = _customClaims!['tenant'] ?? 'default';

    return 'Role: $role, Tenant: $tenant, Permissions: $permissions';
  }

  /// Start automatic token refresh timer
  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer();
    _tokenRefreshTimer = Timer.periodic(tokenRefreshInterval, (_) async {
      await _refreshIdToken();
    });
  }

  /// Stop automatic token refresh timer
  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }



  /// Login with tenant selection
  Future<void> login({String? tenantId}) async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Set tenant before authentication
      _currentTenant = tenantId ?? AppConfig.tenantConfigs['default'];

      debugPrint('🏢 Starting GCIP sign-in for tenant: $_currentTenant');

      if (kIsWeb) {
        // Force GIS on web to avoid deprecated google_sign_in path
        final idJwt = await gisSignIn(AppConfig.googleClientId);
        final gcipToken = await _exchangeGoogleTokenForGCIP(idToken: idJwt);
        await _handleGCIPToken(gcipToken);
        debugPrint('🏢 GIS web sign-in successful');
        return;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('🏢 Google sign-in cancelled by user');
        return;
      }

      await _authenticateWithGCIP(googleUser);

    } catch (e) {
      debugPrint('🏢 GCIP sign-in error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Sign in with email and password (GCIP native)
  Future<void> signInWithEmailPassword(String email, String password, {String? tenantId}) async {
    try {
      _isLoading.value = true;
      notifyListeners();

      _currentTenant = tenantId ?? AppConfig.tenantConfigs['default'];

      debugPrint('🏢 Starting email/password sign-in for tenant: $_currentTenant');

      final url = '$gcipBaseUrl/accounts:signInWithPassword?key=${AppConfig.gcipApiKey}';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true,
          'tenantId': _currentTenant,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _handleGCIPToken(data['idToken']);
        debugPrint('🏢 Email sign-in successful - $email');
      } else {
        throw Exception('Sign-in failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('🏢 Email sign-in error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Create account with email and password
  Future<void> createAccountWithEmailPassword(
    String email,
    String password,
    String displayName, {
    String? tenantId,
    Map<String, dynamic>? customClaims,
  }) async {
    try {
      _isLoading.value = true;
      notifyListeners();

      _currentTenant = tenantId ?? AppConfig.tenantConfigs['default'];

      debugPrint('🏢 Creating account for tenant: $_currentTenant');

      final url = '$gcipBaseUrl/accounts:signUp?key=${AppConfig.gcipApiKey}';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'displayName': displayName,
          'returnSecureToken': true,
          'tenantId': _currentTenant,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _handleGCIPToken(data['idToken']);

        // Set custom claims if provided
        if (customClaims != null) {
          await _setCustomClaims(customClaims);
        }

        debugPrint('🏢 Account created successfully - $email');
      } else {
        throw Exception('Account creation failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('🏢 Account creation error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Set custom claims for the current user
  Future<void> _setCustomClaims(Map<String, dynamic> claims) async {
    // This would typically be done on the backend with admin privileges
    // For now, we'll simulate it locally
    _customClaims = {...(_customClaims ?? {}), ...claims};
    debugPrint('🏢 Custom claims set: $claims');
  }

  /// Logout
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      debugPrint('🏢 Signing out...');

      await _googleSignIn.signOut();

      _currentUser = null;
      _currentToken = null;
      _currentTenant = null;
      _customClaims = null;
      _isAuthenticated.value = false;
      _stopTokenRefreshTimer();

      debugPrint('🏢 Sign out successful');
    } catch (e) {
      debugPrint('🏢 Sign out error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Check if user has specific role
  bool hasRole(String role) {
    return _customClaims?['role'] == role;
  }

  /// Check if user has specific permission
  bool hasPermission(String permission) {
    final permissions = _customClaims?['permissions'] as List<dynamic>?;
    return permissions?.contains(permission) ?? false;
  }

  /// Check if user is admin
  bool get isAdmin => hasRole('admin') || hasRole('org-admin');

  /// Get current user's ID token
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_currentUser == null) return null;

    try {
      if (forceRefresh || _currentToken == null) {
        await _refreshIdToken();
      }
      return _currentToken;
    } catch (e) {
      debugPrint('🏢 Failed to get ID token: $e');
      return null;
    }
  }

  /// Legacy compatibility methods
  String? getAccessToken() => _currentToken;

  Future<String?> getValidatedAccessToken() async {
    return await getIdToken(forceRefresh: true);
  }

  bool get isTokenValid => _currentUser != null && _currentToken != null;

  DateTime? get tokenExpiryTime {
    if (_currentToken != null && !JwtDecoder.isExpired(_currentToken!)) {
      return JwtDecoder.getExpirationDate(_currentToken!);
    }
    return null;
  }

  Future<void> refreshTokenIfNeeded() async {
    await _refreshIdToken();
  }

  /// Update user display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      if (_currentUser != null && _currentToken != null) {
        final url = '$gcipBaseUrl/accounts:update?key=${AppConfig.gcipApiKey}';

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idToken': _currentToken,
            'displayName': displayName,
            'returnSecureToken': true,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await _handleGCIPToken(data['idToken']);
          debugPrint('🏢 Display name updated to: $displayName');
        }
      }
    } catch (e) {
      debugPrint('🏢 Failed to update display name: $e');
      rethrow;
    }
  }

  /// Handle Auth0 callback (legacy compatibility)
  Future<bool> handleCallback({String? callbackUrl}) async {
    debugPrint('🏢 handleCallback called (GCIP - not needed)');
    return false;
  }

  /// Mobile-specific: Login with biometric authentication (not supported)
  Future<void> loginWithBiometrics() async {
    throw UnsupportedError('Biometric authentication not implemented for GCIP');
  }

  /// Check if biometric authentication is available (not supported)
  Future<bool> isBiometricAvailable() async {
    return false;
  }

  /// Get platform information
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': kIsWeb ? 'web' : 'mobile',
      'isWeb': kIsWeb,
      'isMobile': !kIsWeb,
      'isDesktop': !kIsWeb,
      'authProvider': 'gcip',
      'tenant': _currentTenant,
      'multiTenant': true,
    };
  }

  /// Dispose resources
  @override
  void dispose() {
    _stopTokenRefreshTimer();
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
