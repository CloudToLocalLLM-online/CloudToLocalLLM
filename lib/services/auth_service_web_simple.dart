import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';

/// Simple web authentication service that mimics Firebase behavior
/// Uses localStorage for persistence and provides Google-like authentication
class AuthServiceWebSimple extends ChangeNotifier {
  // Authentication state
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;
  String? _currentToken;
  Timer? _tokenRefreshTimer;
  
  // Configuration
  static const Duration tokenRefreshInterval = Duration(minutes: 50);
  static const String storageKeyUser = 'cloudtolocalllm_user';
  static const String storageKeyToken = 'cloudtolocalllm_token';
  
  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  String? get accessToken => _currentToken;
  
  // Platform detection
  bool get isWeb => true;
  bool get isMobile => false;
  bool get isDesktop => false;
  
  // Constructor
  AuthServiceWebSimple() {
    _initialize();
  }
  
  /// Initialize the web auth service
  void _initialize() {
    debugPrint('🌐 Initializing Web Auth service...');
    
    try {
      // Check for existing authentication in localStorage
      _loadStoredAuth();
      
      if (_currentUser != null) {
        _isAuthenticated.value = true;
        _startTokenRefreshTimer();
      }
      
      debugPrint('🌐 Web Auth service initialized successfully');
    } catch (e) {
      debugPrint('🌐 Failed to initialize Web Auth service: $e');
    }
  }
  
  /// Load stored authentication from localStorage
  void _loadStoredAuth() {
    try {
      final userJson = html.window.localStorage[storageKeyUser];
      final token = html.window.localStorage[storageKeyToken];
      
      if (userJson != null && token != null) {
        final userData = jsonDecode(userJson);
        _currentUser = UserModel.fromJson(userData);
        _currentToken = token;
        debugPrint('🌐 Loaded stored authentication for ${_currentUser?.email}');
      }
    } catch (e) {
      debugPrint('🌐 Failed to load stored auth: $e');
      _clearStoredAuth();
    }
  }
  
  /// Save authentication to localStorage
  void _saveAuth() {
    try {
      if (_currentUser != null && _currentToken != null) {
        html.window.localStorage[storageKeyUser] = jsonEncode(_currentUser!.toJson());
        html.window.localStorage[storageKeyToken] = _currentToken!;
        debugPrint('🌐 Saved authentication to localStorage');
      }
    } catch (e) {
      debugPrint('🌐 Failed to save auth: $e');
    }
  }
  
  /// Clear stored authentication
  void _clearStoredAuth() {
    html.window.localStorage.remove(storageKeyUser);
    html.window.localStorage.remove(storageKeyToken);
  }
  
  /// Start automatic token refresh timer
  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer();
    _tokenRefreshTimer = Timer.periodic(tokenRefreshInterval, (_) {
      _refreshToken();
    });
  }
  
  /// Stop automatic token refresh timer
  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }
  
  /// Refresh the current user's token (simulate Firebase behavior)
  Future<void> _refreshToken() async {
    if (_currentUser != null) {
      try {
        // Generate a new mock token
        _currentToken = _generateMockToken(_currentUser!);
        _saveAuth();
        debugPrint('🌐 Token refreshed successfully');
      } catch (e) {
        debugPrint('🌐 Failed to refresh token: $e');
        _currentToken = null;
      }
    }
  }
  
  /// Generate a mock JWT-like token
  String _generateMockToken(UserModel user) {
    final header = base64Encode(utf8.encode(jsonEncode({
      'alg': 'HS256',
      'typ': 'JWT'
    })));
    
    final payload = base64Encode(utf8.encode(jsonEncode({
      'sub': user.id,
      'email': user.email,
      'name': user.name,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      'iss': 'cloudtolocalllm-auth',
      'aud': 'cloudtolocalllm'
    })));
    
    final signature = base64Encode(utf8.encode('mock-signature'));
    
    return '$header.$payload.$signature';
  }
  
  /// Login using Google-like authentication (simplified)
  Future<void> login() async {
    try {
      _isLoading.value = true;
      notifyListeners();
      
      debugPrint('🌐 Starting Google-like sign-in...');
      
      // Simulate Google authentication with a popup-like experience
      final result = await _showGoogleSignInDialog();
      
      if (result != null) {
        _currentUser = result;
        _currentToken = _generateMockToken(result);
        _isAuthenticated.value = true;
        _saveAuth();
        _startTokenRefreshTimer();
        
        debugPrint('🌐 Sign-in successful - ${result.email}');
      } else {
        debugPrint('🌐 Sign-in cancelled by user');
      }
      
    } catch (e) {
      debugPrint('🌐 Sign-in error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }
  
  /// Show a simple Google sign-in dialog (mock)
  Future<UserModel?> _showGoogleSignInDialog() async {
    // For demo purposes, create a mock user
    // In a real implementation, this would open Google OAuth
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    
    return UserModel(
      id: 'web-user-${DateTime.now().millisecondsSinceEpoch}',
      email: 'user@example.com',
      name: 'Demo User',
      picture: 'https://via.placeholder.com/150',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  /// Sign in with email and password
  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      _isLoading.value = true;
      notifyListeners();
      
      debugPrint('🌐 Starting email/password sign-in...');
      
      // Simulate authentication
      await Future.delayed(const Duration(seconds: 1));
      
      final user = UserModel(
        id: 'web-user-${email.hashCode}',
        email: email,
        name: email.split('@')[0],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _currentUser = user;
      _currentToken = _generateMockToken(user);
      _isAuthenticated.value = true;
      _saveAuth();
      _startTokenRefreshTimer();
      
      debugPrint('🌐 Email sign-in successful - $email');
    } catch (e) {
      debugPrint('🌐 Email sign-in error: $e');
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
    String displayName
  ) async {
    try {
      _isLoading.value = true;
      notifyListeners();
      
      debugPrint('🌐 Creating account with email...');
      
      // Simulate account creation
      await Future.delayed(const Duration(seconds: 1));
      
      final user = UserModel(
        id: 'web-user-${email.hashCode}',
        email: email,
        name: displayName.isNotEmpty ? displayName : email.split('@')[0],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _currentUser = user;
      _currentToken = _generateMockToken(user);
      _isAuthenticated.value = true;
      _saveAuth();
      _startTokenRefreshTimer();
      
      debugPrint('🌐 Account created successfully - $email');
    } catch (e) {
      debugPrint('🌐 Account creation error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }
  
  /// Logout
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();
      
      debugPrint('🌐 Signing out...');
      
      _currentUser = null;
      _currentToken = null;
      _isAuthenticated.value = false;
      _stopTokenRefreshTimer();
      _clearStoredAuth();
      
      debugPrint('🌐 Sign out successful');
    } catch (e) {
      debugPrint('🌐 Sign out error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }
  
  /// Handle Auth0 callback (legacy compatibility - not used)
  Future<bool> handleCallback({String? callbackUrl}) async {
    debugPrint('🌐 handleCallback called (Web Simple - not needed)');
    return false;
  }
  
  /// Mobile-specific: Login with biometric authentication (not supported)
  Future<void> loginWithBiometrics() async {
    throw UnsupportedError('Biometric authentication not supported on web');
  }
  
  /// Check if biometric authentication is available (not supported)
  Future<bool> isBiometricAvailable() async {
    return false;
  }
  
  /// Get current user's ID token
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_currentUser == null) return null;
    
    try {
      if (forceRefresh || _currentToken == null) {
        await _refreshToken();
      }
      return _currentToken;
    } catch (e) {
      debugPrint('🌐 Failed to get ID token: $e');
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
    if (_currentUser != null) {
      return DateTime.now().add(const Duration(hours: 1));
    }
    return null;
  }
  
  Future<void> refreshTokenIfNeeded() async {
    await _refreshToken();
  }
  
  /// Get platform information
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': 'web',
      'isWeb': true,
      'isMobile': false,
      'isDesktop': false,
      'authProvider': 'web-simple',
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
