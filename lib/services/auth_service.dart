import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth0_service.dart';
import 'session_storage_service.dart';
import 'connection_manager_service.dart';
import 'streaming_chat_service.dart';
import 'tunnel_service.dart';
import '../di/locator.dart' as di;

/// Auth0-based Authentication Service with PostgreSQL Session Storage
/// Provides authentication for web and desktop using Auth0
/// Sessions and user data are stored in PostgreSQL for better control
class AuthService extends ChangeNotifier {
  final Auth0Service _auth0Service;
  final SessionStorageService _sessionStorage;
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _areAuthenticatedServicesLoaded =
      ValueNotifier<bool>(false);
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
          // Auth0 authenticated - handle successful callback with blocking session persistence
          await _handleSuccessfulCallback();
        } else {
          // Auth0 logged out

          // CRITICAL FIX: If we have a valid SQL session token, IGNORE Auth0's "not authenticated" state.
          // This happens on reload when silent auth fails but the user is still valid in our DB.
          if (_sessionToken != null) {
            debugPrint(
                '[AuthService] Auth0 reported unauthenticated, but valid SQL session exists. Keeping user logged in.');
            return;
          }

          // Only clear if we really don't have a session
          await _clearStoredSession();
          _isAuthenticated.value = false;
          _areAuthenticatedServicesLoaded.value = false;
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

  /// Handle successful callback with blocking PostgreSQL session persistence
  /// This method ensures authentication state is only set AFTER session is persisted
  Future<void> _handleSuccessfulCallback() async {
    debugPrint('[AuthService] ===== HANDLE SUCCESSFUL CALLBACK START =====');
    debugPrint(
      '[AuthService] Handling successful callback - starting session persistence...',
    );
    debugPrint('[AuthService] Auth state before: ${_isAuthenticated.value}');

    try {
      // 1. Get tokens from Auth0Service
      debugPrint(
        '[AuthService] Step 1: Retrieving tokens from Auth0Service...',
      );
      final accessToken = _auth0Service.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[AuthService] ERROR: Access token not available');
        throw Exception('Access token not available from Auth0Service');
      }
      debugPrint('[AuthService] Access token retrieved successfully');

      if (_auth0Service.currentUser == null) {
        debugPrint('[AuthService] ERROR: User profile not available');
        throw Exception('User profile not available from Auth0Service');
      }

      final user = UserModel.fromAuth0Profile(_auth0Service.currentUser!);
      debugPrint('[AuthService] User profile retrieved: ${user.email}');

      // 2. Immediately persist to PostgreSQL (BLOCKING)
      debugPrint(
        '[AuthService] Step 2: Creating PostgreSQL session (blocking)...',
      );
      final sessionStartTime = DateTime.now();
      final session = await _sessionStorage.createSession(
        user: user,
        auth0AccessToken: accessToken,
        auth0IdToken: null,
      );
      final sessionDuration = DateTime.now().difference(sessionStartTime);
      debugPrint(
        '[AuthService] SUCCESS: PostgreSQL session created in ${sessionDuration.inMilliseconds}ms',
      );
      debugPrint('[AuthService] Session token: ${session.token}');

      // 3. Store session token locally
      debugPrint('[AuthService] Step 3: Storing session token locally...');
      _sessionToken = session.token;
      _currentUser = user;
      debugPrint('[AuthService] Session token stored: $_sessionToken');

      // 4. Only NOW set auth state to true
      debugPrint('[AuthService] Step 4: Setting authentication state to true');
      debugPrint('[AuthService] Auth state before: ${_isAuthenticated.value}');
      _isAuthenticated.value = true;
      debugPrint('[AuthService] Auth state after: ${_isAuthenticated.value}');
      notifyListeners();

      // 5. Load authenticated services (async, non-blocking)
      debugPrint('[AuthService] Step 5: Loading authenticated services...');
      _loadAuthenticatedServices();
      debugPrint(
        '[AuthService] ===== HANDLE SUCCESSFUL CALLBACK COMPLETE =====',
      );
    } catch (e, stackTrace) {
      debugPrint('[AuthService] ERROR: Failed to persist session: $e');
      debugPrint('[AuthService] Stack trace: $stackTrace');
      // Don't set auth state if persistence failed
      debugPrint(
        '[AuthService] Clearing auth state due to persistence failure',
      );
      _isAuthenticated.value = false;
      _currentUser = null;
      _sessionToken = null;
      notifyListeners();
      debugPrint('[AuthService] ===== HANDLE SUCCESSFUL CALLBACK FAILED =====');
      throw Exception('Session persistence failed: $e');
    }
  }

  /// Load authenticated services after authentication is confirmed
  Future<void> _loadAuthenticatedServices() async {
    try {
      debugPrint('[AuthService] Loading authenticated services...');
      debugPrint(
        '[AuthService] Authenticated services loaded state before: ${_areAuthenticatedServicesLoaded.value}',
      );

      // Check if critical authenticated services are already registered
      // This handles session restoration where services were already set up in a previous session
      final hasConnectionManager =
          di.serviceLocator.isRegistered<ConnectionManagerService>();
      final hasStreamingChat =
          di.serviceLocator.isRegistered<StreamingChatService>();
      final hasTunnelService = di.serviceLocator.isRegistered<TunnelService>();

      if (hasConnectionManager && hasStreamingChat && hasTunnelService) {
        debugPrint(
          '[AuthService] Authenticated services already registered from previous session',
        );
        _areAuthenticatedServicesLoaded.value = true;
        debugPrint(
          '[AuthService] Authenticated services loaded state after: ${_areAuthenticatedServicesLoaded.value}',
        );
        notifyListeners();
        return;
      }

      final startTime = DateTime.now();
      await di.setupAuthenticatedServices();
      final duration = DateTime.now().difference(startTime);
      debugPrint(
        '[AuthService] SUCCESS: Authenticated services loaded in ${duration.inMilliseconds}ms',
      );
      // Always set to true after setupAuthenticatedServices completes
      // This handles both initial setup and session restoration scenarios
      _areAuthenticatedServicesLoaded.value = true;
      debugPrint(
        '[AuthService] Authenticated services loaded state after: ${_areAuthenticatedServicesLoaded.value}',
      );
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint(
        '[AuthService] ERROR: Failed to load authenticated services: $e',
      );
      debugPrint('[AuthService] Stack trace: $stackTrace');
      _areAuthenticatedServicesLoaded.value = false;
      notifyListeners();
    }
  }

  /// Check for existing session in PostgreSQL
  Future<void> _checkStoredSession() async {
    try {
      debugPrint('[AuthService] Checking for stored session in PostgreSQL...');
      debugPrint(
        '[AuthService] Auth state before check: ${_isAuthenticated.value}',
      );

      // Enforce 5-second timeout to prevent hanging on startup
      final session = await _sessionStorage.getCurrentSession().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[AuthService] WARNING: Session check timed out after 5s');
          return null;
        },
      );

      if (session != null && session.isValid) {
        debugPrint('[AuthService] SUCCESS: Found valid session');
        debugPrint('[AuthService] Session user ID: ${session.userId}');
        debugPrint('[AuthService] Session token: ${session.token}');
        _sessionToken = session.token;
        _currentUser = session.user;
        debugPrint(
          '[AuthService] Auth state before: ${_isAuthenticated.value}',
        );
        _isAuthenticated.value = true;
        debugPrint('[AuthService] Auth state after: ${_isAuthenticated.value}');
        notifyListeners();

        // Load authenticated services now that session is restored
        // This is critical for app reload scenarios where the user is already authenticated
        debugPrint(
          '[AuthService] Session restored - loading authenticated services...',
        );
        await _loadAuthenticatedServices();
      } else {
        debugPrint('[AuthService] No valid stored session found');
        if (session != null) {
          debugPrint('[AuthService] Session exists but is invalid');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[AuthService] ERROR: Failed to check stored session: $e');
      debugPrint('[AuthService] Stack trace: $stackTrace');
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
  ValueNotifier<bool> get areAuthenticatedServicesLoaded =>
      _areAuthenticatedServicesLoaded;
  bool get isSessionBootstrapComplete => _sessionBootstrapCompleter.isCompleted;
  Future<void> get sessionBootstrapFuture => _sessionBootstrapCompleter.future;
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
    debugPrint('[AuthService] ===== LOGIN START =====');
    debugPrint('[AuthService] Login initiated');
    debugPrint('[AuthService] Auth state before: ${_isAuthenticated.value}');
    _isLoading.value = true;
    notifyListeners();

    try {
      debugPrint('[AuthService] Calling Auth0Service.login()...');
      await _auth0Service.login();
      debugPrint(
        '[AuthService] Auth0Service.login() completed (redirect initiated)',
      );
      // Note: login() will redirect, so code after this won't execute immediately
    } finally {
      _isLoading.value = false;
      notifyListeners();
      debugPrint('[AuthService] ===== LOGIN COMPLETE =====');
    }
  }

  /// Logout from Auth0
  Future<void> logout() async {
    debugPrint('[AuthService] ===== LOGOUT START =====');
    debugPrint('[AuthService] Logout initiated');
    debugPrint('[AuthService] Auth state before: ${_isAuthenticated.value}');
    _isLoading.value = true;
    notifyListeners();

    try {
      // Clear stored session FIRST to ensure listener doesn't block logout
      await _clearStoredSession();

      debugPrint('[AuthService] Calling Auth0Service.logout()...');
      await _auth0Service.logout();
      debugPrint('[AuthService] Auth0Service.logout() completed');
      debugPrint('[AuthService] Clearing authentication state');
      debugPrint('[AuthService] Auth state before: ${_isAuthenticated.value}');
      _isAuthenticated.value = false;
      _areAuthenticatedServicesLoaded.value = false;
      debugPrint('[AuthService] Auth state after: ${_isAuthenticated.value}');
      debugPrint(
        '[AuthService] Authenticated services loaded state: ${_areAuthenticatedServicesLoaded.value}',
      );
      _currentUser = null;
      debugPrint('[AuthService] User data cleared');
    } finally {
      _isLoading.value = false;
      notifyListeners();
      debugPrint('[AuthService] ===== LOGOUT COMPLETE =====');
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
    debugPrint('[AuthService] ===== HANDLE CALLBACK START =====');
    debugPrint('[AuthService] handleCallback called with URL: $callbackUrl');
    debugPrint(
      '[AuthService] Auth state before callback: ${_isAuthenticated.value}',
    );

    if (kIsWeb) {
      debugPrint(
        '[AuthService] Web platform - calling Auth0Service.handleRedirectCallback...',
      );
      final success = await _auth0Service.handleRedirectCallback();
      debugPrint(
        '[AuthService] Auth0Service.handleRedirectCallback returned: $success',
      );

      if (success) {
        debugPrint(
          '[AuthService] Callback successful, checking auth status and loading services...',
        );
        // After successful callback handling, check auth status and load services
        await _checkAuthStatus();
        debugPrint(
          '[AuthService] Final auth state after callback: ${isAuthenticated.value}',
        );
        debugPrint(
          '[AuthService] ===== HANDLE CALLBACK COMPLETE (SUCCESS) =====',
        );
      } else {
        debugPrint('[AuthService] ERROR: Callback failed');
        debugPrint(
          '[AuthService] ===== HANDLE CALLBACK COMPLETE (FAILED) =====',
        );
      }
      return success;
    } else {
      debugPrint(
        '[AuthService] Desktop platform - callback handled internally',
      );
      debugPrint(
        '[AuthService] ===== HANDLE CALLBACK COMPLETE (DESKTOP) =====',
      );
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
    debugPrint(
      'updateDisplayName called but Auth0 profiles are managed externally. Use Auth0 Management API to update user profiles.',
    );
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
    _areAuthenticatedServicesLoaded.dispose();
    _auth0Service.dispose();
    super.dispose();
  }

  void _completeSessionBootstrap() {
    if (!_sessionBootstrapCompleter.isCompleted) {
      _sessionBootstrapCompleter.complete();
    }
  }
}
