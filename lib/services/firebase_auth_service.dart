// CloudToLocalLLM - Firebase Authentication Service
// This service replaces Auth0 authentication with Firebase Authentication
// for better Google Cloud integration and cost savings

import 'dart:async';
import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;
  
  // Stream controllers for authentication state
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();
  final StreamController<String?> _tokenController = StreamController<String?>.broadcast();
  
  // Current user and token
  User? _currentUser;
  String? _currentToken;
  Timer? _tokenRefreshTimer;

  // Configuration
  static const String googleClientId = 'your-google-client-id.googleusercontent.com';
  static const Duration tokenRefreshInterval = Duration(minutes: 50); // Refresh before 1-hour expiry

  /// Initialize the Firebase Auth service
  Future<void> initialize() async {
    print('CloudToLocalLLM: Initializing Firebase Auth service...');
    
    try {
      // Initialize Google Sign-In
      _googleSignIn = GoogleSignIn(
        clientId: googleClientId,
        scopes: ['email', 'profile'],
      );

      // Listen to auth state changes
      _auth.authStateChanges().listen(_handleAuthStateChange);
      
      // Check if user is already signed in
      _currentUser = _auth.currentUser;
      if (_currentUser != null) {
        await _refreshToken();
        _startTokenRefreshTimer();
      }
      
      print('CloudToLocalLLM: Firebase Auth service initialized successfully');
    } catch (e) {
      print('CloudToLocalLLM: Failed to initialize Firebase Auth service: $e');
      rethrow;
    }
  }

  /// Handle authentication state changes
  void _handleAuthStateChange(User? user) {
    print('CloudToLocalLLM: Auth state changed - User: ${user?.email ?? 'null'}');
    
    _currentUser = user;
    _authStateController.add(user);
    
    if (user != null) {
      _refreshToken();
      _startTokenRefreshTimer();
    } else {
      _currentToken = null;
      _tokenController.add(null);
      _stopTokenRefreshTimer();
    }
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
    if (_currentUser != null) {
      try {
        final token = await _currentUser!.getIdToken(true);
        _currentToken = token;
        _tokenController.add(token);
        print('CloudToLocalLLM: Token refreshed successfully');
      } catch (e) {
        print('CloudToLocalLLM: Failed to refresh token: $e');
        _currentToken = null;
        _tokenController.add(null);
      }
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('CloudToLocalLLM: Starting Google sign-in...');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('CloudToLocalLLM: Google sign-in cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      print('CloudToLocalLLM: Google sign-in successful - ${userCredential.user?.email}');
      
      return userCredential;
    } catch (e) {
      print('CloudToLocalLLM: Google sign-in error: $e');
      throw _handleAuthError(e);
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      print('CloudToLocalLLM: Starting email/password sign-in...');
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      print('CloudToLocalLLM: Email sign-in successful - ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      print('CloudToLocalLLM: Email sign-in error: $e');
      throw _handleAuthError(e);
    }
  }

  /// Create account with email and password
  Future<UserCredential?> createAccountWithEmailPassword(
    String email, 
    String password, 
    String displayName
  ) async {
    try {
      print('CloudToLocalLLM: Creating account with email...');
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name
      if (userCredential.user != null && displayName.isNotEmpty) {
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
      }
      
      print('CloudToLocalLLM: Account created successfully - ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      print('CloudToLocalLLM: Account creation error: $e');
      throw _handleAuthError(e);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      print('CloudToLocalLLM: Password reset email sent to $email');
    } catch (e) {
      print('CloudToLocalLLM: Password reset error: $e');
      throw _handleAuthError(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      print('CloudToLocalLLM: Signing out...');
      
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      
      _currentUser = null;
      _currentToken = null;
      _stopTokenRefreshTimer();
      
      print('CloudToLocalLLM: Sign out successful');
    } catch (e) {
      print('CloudToLocalLLM: Sign out error: $e');
      throw _handleAuthError(e);
    }
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
      print('CloudToLocalLLM: Failed to get ID token: $e');
      return null;
    }
  }

  /// Handle authentication errors
  AuthException _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return AuthException('No account found with this email address.');
        case 'wrong-password':
          return AuthException('Incorrect password.');
        case 'email-already-in-use':
          return AuthException('An account already exists with this email address.');
        case 'weak-password':
          return AuthException('Password is too weak. Please choose a stronger password.');
        case 'invalid-email':
          return AuthException('Invalid email address.');
        case 'user-disabled':
          return AuthException('This account has been disabled.');
        case 'too-many-requests':
          return AuthException('Too many failed attempts. Please try again later.');
        case 'operation-not-allowed':
          return AuthException('This sign-in method is not enabled.');
        default:
          return AuthException('Authentication failed: ${error.message}');
      }
    }
    return AuthException('An unexpected error occurred during authentication.');
  }

  /// Get current user information
  Map<String, dynamic>? get currentUserInfo {
    if (_currentUser == null) return null;
    
    return {
      'uid': _currentUser!.uid,
      'email': _currentUser!.email,
      'displayName': _currentUser!.displayName,
      'photoURL': _currentUser!.photoURL,
      'emailVerified': _currentUser!.emailVerified,
      'isAnonymous': _currentUser!.isAnonymous,
      'metadata': {
        'creationTime': _currentUser!.metadata.creationTime?.toIso8601String(),
        'lastSignInTime': _currentUser!.metadata.lastSignInTime?.toIso8601String(),
      },
      'providerData': _currentUser!.providerData.map((info) => {
        'providerId': info.providerId,
        'uid': info.uid,
        'displayName': info.displayName,
        'email': info.email,
        'photoURL': info.photoURL,
      }).toList(),
    };
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _currentUser != null;

  /// Get current user
  User? get currentUser => _currentUser;

  /// Get authentication state stream
  Stream<User?> get authStateChanges => _authStateController.stream;

  /// Get token stream
  Stream<String?> get tokenStream => _tokenController.stream;

  /// Dispose resources
  void dispose() {
    _stopTokenRefreshTimer();
    _authStateController.close();
    _tokenController.close();
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => 'AuthException: $message';
}
