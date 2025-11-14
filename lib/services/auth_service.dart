import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth0_service.dart';
import 'session_storage_service.dart';
import '../di/locator.dart' as di;

/// Auth0-based Authentication Service with PostgreSQL Session Storage
/// Provides authentication for web and desktop using Auth0
/// Sessions and user data are stored in PostgreSQL for better control
class AuthService extends ChangeNotifier {
  final Auth0Service _auth0Service;
  final SessionStorageService _sessionStorage;
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final Completer<void> _sessionBootstrapCompleter = Completer<void>();
  UserModel? _currentUser;
  bool _initialized = false;
  String? _sessionToken;
  bool _isRestoringSession = false;

  AuthService(this._auth0Service, this._sessionStorage);

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _initAuth0();
  }

  /// Initialize Auth0 with PostgreSQL session storage
  Future<void> _initAuth0() async {
    try {
      _isRestoringSession = true;
      _isLoading.value = true;
      notifyListeners();

      await _auth0Service.initialize();

      // First, check if we have a valid session in PostgreSQL
      await _checkStoredSession();

      // Listen to Auth0 auth state changes
      _auth0Service.authStateChanges.listen((isAuth) async {
        debugPrint('[AuthService] Auth0 auth state changed: $isAuth');
        if (isAuth && _auth0Service.currentUser != null) {
          // Auth0 authenticated - store session in PostgreSQL
          await _storeAuth0Session(force: true);
          _isAuthenticated.value = true;
          // Load authenticated services now that we have a token (async, non-blocking)
          _loadAuthenticatedServices();
        } else {
          // Auth0 logged out - clear PostgreSQL session
          await _clearStoredSession();
          _isAuthenticated.value = false;
          _currentUser = null;
          _sessionToken = null;
        }
        notifyListeners();
      });

      // If we restored a session from PostgreSQL, we're already authenticated
      if (_isAuthenticated.value) {
        await _loadAuthenticatedServices();
      }
    } catch (e) {
      debugPrint(' Failed to initialize Auth0: $e');
    } finally {
      _isRestoringSession = false;
      _isLoading.value = false;
      _completeSessionBootstrap();
      notifyListeners();
    }
  }

  /// Load authenticated services after authentication is confirmed
  Future<void> _loadAuthenticatedServices() async {
    try {
      debugPrint('[AuthService] Loading authenticated services...');
      await di.setupAuthenticatedServices();
      debugPrint('[AuthService] Authenticated services loaded successfully');
    } catch (e) {
      debugPrint('[AuthService] Error loading authenticated services: $e');
    }
  }

  /// Check for existing session in PostgreSQL
  Future<void> _checkStoredSession() async {
    try {
      debugPrint('[AuthService] Checking for stored session in PostgreSQL...');
      final session = await _sessionStorage.getCurrentSession();
      if (session != null && session.isValid) {
        debugPrint('[AuthService] Found valid session: ${session.userId}');
        _sessionToken = session.token;
        _currentUser = session.user;
        _isAuthenticated.value = true;
        notifyListeners();
      } else {
        debugPrint('[AuthService] No valid stored session found');
      }
    } catch (e) {
      debugPrint(' Error checking stored session: $e');
    } finally {
      _completeSessionBootstrap();
    }
  }

  /// Store Auth0 session in PostgreSQL
  Future<void> _storeAuth0Session({bool force = false}) async {
    try {
      if (_auth0Service.currentUser == null) {
        debugPrint(' No Auth0 user available, skipping session storage');
        return;
      }

      if (!force && _sessionToken != null) {
        debugPrint(' Session already stored, skipping new session creation');
        return;
      }

      debugPrint(' Storing Auth0 session in PostgreSQL...');
      final user = UserModel.fromAuth0Profile(_auth0Service.currentUser!);
      final accessToken = _auth0Service.getAccessToken();

      final session = await _sessionStorage.createSession(
        user: user,
        auth0AccessToken: accessToken,
        auth0IdToken: null, // Could add if needed
      );

      _sessionToken = session.token;
      _currentUser = user;
      debugPrint(' Session stored: ${session.token}');
    } catch (e) {
      debugPrint(' Error storing Auth0 session: $e');
    }
  }

  /// Clear stored session from PostgreSQL
  Future<void> _clearStoredSession() async {
    try {
      if (_sessionToken != null) {
        debugPrint(' Clearing stored session: $_sessionToken');
        await _sessionStorage.invalidateSession(_sessionToken!);
        _sessionToken = null;
      }
    } catch (e) {
      debugPrint(' Error clearing stored session: $e');
    }
  }

  Future<void> _checkAuthStatus() async {
    // For Auth0WebService, we need to call checkAuthStatus() to get the actual auth state
    // since isAuthenticated is just a cached value
    try {
      // This will update the internal state in Auth0Service
      await (_auth0Service as dynamic).checkAuthStatus();
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    }

    // Now check the updated authentication state
    if (_auth0Service.isAuthenticated && _auth0Service.currentUser != null) {
      // Load authenticated services BEFORE setting authenticated state
      // This ensures services are ready when auth state becomes true
      await _loadAuthenticatedServices();
      await _storeAuth0Session();

      _isAuthenticated.value = true;
      _currentUser = UserModel.fromAuth0Profile(_auth0Service.currentUser!);
      notifyListeners();
    }
  }

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  bool get isSessionBootstrapComplete => _sessionBootstrapCompleter.isCompleted;
  Future<void> get sessionBootstrapFuture =>
      _sessionBootstrapCompleter.future;
  bool get isRestoringSession => _isRestoringSession;
  UserModel? get currentUser => _currentUser;
  
  // Platform detection
  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;
  bool get isDesktop => !kIsWeb;

  // Auth0 service access
  Auth0Service get auth0Service => _auth0Service;

  /// Login with Auth0
  Future<void> login({String? tenantId}) async {
    _isLoading.value = true;
    notifyListeners();

    try {
      await _auth0Service.login();
      // Note: login() will redirect, so code after this won't execute immediately
    } finally {
      _isLoading.value = false;
      notifyListeners();
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
    } finally {
      _isLoading.value = false;
      notifyListeners();
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
    debugPrint(' AuthService.handleCallback called with URL: $callbackUrl');
    if (kIsWeb) {
      debugPrint(' Calling Auth0Service.handleRedirectCallback...');
      final success = await _auth0Service.handleRedirectCallback();
      debugPrint(' Auth0Service.handleRedirectCallback returned: $success');

      if (success) {
          debugPrint('[AuthService] Callback successful, checking auth status and loading services...');
        // After successful callback handling, check auth status and load services
        await _checkAuthStatus();
        debugPrint(' Final auth state after callback: ${isAuthenticated.value}');
      } else {
        debugPrint(' Callback failed');
      }
      return success;
    } else {
       // On desktop, the callback is handled differently via deep linking or a local server.
       // This logic assumes the desktop service will handle the full flow internally.
       return true;
    }
  }

  Future<bool> handleRedirectCallback() async {
    if (kIsWeb) {
      return await _auth0Service.handleRedirectCallback();
    }
    return false; // Not applicable for non-web platforms
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

  void _completeSessionBootstrap() {
    if (!_sessionBootstrapCompleter.isCompleted) {
      _sessionBootstrapCompleter.complete();
    }
  }
}

