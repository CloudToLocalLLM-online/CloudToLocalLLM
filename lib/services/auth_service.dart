import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';

/// Firebase Authentication service for CloudToLocalLLM
/// Provides Google Sign-In and email/password authentication
/// Replaces Auth0 with Firebase for better Google Cloud integration and cost savings
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;
  
  // Authentication state
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;
  String? _currentToken;
  Timer? _tokenRefreshTimer;
  
  // Stream subscriptions
  StreamSubscription<User?>? _authStateSubscription;
  
  // Configuration
  static const Duration tokenRefreshInterval = Duration(minutes: 50);
  
  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  String? get accessToken => _currentToken;
  
  // Platform detection
  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;
  bool get isDesktop => !kIsWeb;
  
  // Constructor
  AuthService() {
    _initialize();
  }
  
  /// Initialize the Firebase Auth service
  void _initialize() {
    debugPrint('🔥 Initializing Firebase Auth service...');
    
    try {
      // Initialize Google Sign-In
      _googleSignIn = GoogleSignIn(
        clientId: AppConfig.googleClientId,
        scopes: AppConfig.firebaseScopes,
      );
      
      // Listen to auth state changes
      _authStateSubscription = _auth.authStateChanges().listen(_handleAuthStateChange);
      
      // Check if user is already signed in
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        _handleAuthStateChange(currentUser);
      }
      
      debugPrint('🔥 Firebase Auth service initialized successfully');
    } catch (e) {
      debugPrint('🔥 Failed to initialize Firebase Auth service: $e');
    }
  }
  
  /// Handle authentication state changes
  void _handleAuthStateChange(User? user) {
    debugPrint('🔥 Auth state changed - User: ${user?.email ?? 'null'}');
    
    if (user != null) {
      _currentUser = UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? '',
        picture: user.photoURL,
        emailVerified: user.emailVerified ? DateTime.now() : null,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _isAuthenticated.value = true;
      _refreshToken();
      _startTokenRefreshTimer();
    } else {
      _currentUser = null;
      _currentToken = null;
      _isAuthenticated.value = false;
      _stopTokenRefreshTimer();
    }
    
    notifyListeners();
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
  
  /// Refresh the current user's ID token
  Future<void> _refreshToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken(true);
        _currentToken = token;
        debugPrint('🔥 Token refreshed successfully');
      } catch (e) {
        debugPrint('🔥 Failed to refresh token: $e');
        _currentToken = null;
      }
    }
  }
  
  /// Login using platform-specific implementation
  Future<void> login() async {
    await _signInWithGoogle();
  }
  
  /// Sign in with Google
  Future<void> _signInWithGoogle() async {
    try {
      _isLoading.value = true;
      notifyListeners();
      
      debugPrint('🔥 Starting Google sign-in...');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('🔥 Google sign-in cancelled by user');
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('🔥 Google sign-in successful - ${userCredential.user?.email}');
      
    } catch (e) {
      debugPrint('🔥 Google sign-in error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }
  
  /// Sign in with email and password
  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      _isLoading.value = true;
      notifyListeners();
      
      debugPrint('🔥 Starting email/password sign-in...');
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      debugPrint('🔥 Email sign-in successful - ${userCredential.user?.email}');
    } catch (e) {
      debugPrint('🔥 Email sign-in error: $e');
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
      
      debugPrint('🔥 Creating account with email...');
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Update display name
      if (userCredential.user != null && displayName.isNotEmpty) {
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
      }
      
      debugPrint('🔥 Account created successfully - ${userCredential.user?.email}');
    } catch (e) {
      debugPrint('🔥 Account creation error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }
  
  /// Logout using platform-specific implementation
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();
      
      debugPrint('🔥 Signing out...');
      
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      
      _currentUser = null;
      _currentToken = null;
      _stopTokenRefreshTimer();
      
      debugPrint('🔥 Sign out successful');
    } catch (e) {
      debugPrint('🔥 Sign out error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }
  
  /// Handle Auth0 callback (legacy compatibility - not used with Firebase)
  Future<bool> handleCallback({String? callbackUrl}) async {
    debugPrint('🔥 handleCallback called (Firebase - not needed)');
    return false;
  }
  
  /// Mobile-specific: Login with biometric authentication (not supported)
  Future<void> loginWithBiometrics() async {
    throw UnsupportedError('Biometric authentication not implemented for Firebase');
  }
  
  /// Check if biometric authentication is available (not supported)
  Future<bool> isBiometricAvailable() async {
    return false;
  }
  
  /// Get current user's ID token
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      if (forceRefresh || _currentToken == null) {
        await _refreshToken();
      }
      return _currentToken;
    } catch (e) {
      debugPrint('🔥 Failed to get ID token: $e');
      return null;
    }
  }
  
  /// Legacy compatibility methods for existing services
  
  /// Get access token (alias for getIdToken)
  String? getAccessToken() {
    return _currentToken;
  }
  
  /// Get validated access token (async version)
  Future<String?> getValidatedAccessToken() async {
    return await getIdToken(forceRefresh: true);
  }
  
  /// Check if token is valid
  bool get isTokenValid {
    final user = _auth.currentUser;
    return user != null && _currentToken != null;
  }
  
  /// Get token expiry time (Firebase tokens expire after 1 hour)
  DateTime? get tokenExpiryTime {
    final user = _auth.currentUser;
    if (user != null) {
      // Firebase ID tokens expire after 1 hour
      return DateTime.now().add(const Duration(hours: 1));
    }
    return null;
  }
  
  /// Refresh token if needed
  Future<void> refreshTokenIfNeeded() async {
    await _refreshToken();
  }

  /// Update user display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();

        // Update the current user model
        _currentUser = UserModel(
          id: user.uid,
          email: user.email ?? '',
          name: displayName,
          picture: user.photoURL,
          emailVerified: user.emailVerified ? DateTime.now() : null,
          createdAt: user.metadata.creationTime ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        notifyListeners();
        debugPrint('🔥 Display name updated to: $displayName');
      }
    } catch (e) {
      debugPrint('🔥 Failed to update display name: $e');
      rethrow;
    }
  }
  
  /// Get platform information
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': kIsWeb ? 'web' : 'mobile',
      'isWeb': kIsWeb,
      'isMobile': !kIsWeb,
      'isDesktop': !kIsWeb,
      'authProvider': 'firebase',
    };
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _stopTokenRefreshTimer();
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
