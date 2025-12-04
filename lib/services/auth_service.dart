import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'supabase_auth_service.dart';

import 'connection_manager_service.dart';
import '../di/locator.dart' as di;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-based Authentication Service with PostgreSQL Session Storage
class AuthService extends ChangeNotifier {
  final SupabaseAuthService _supabaseAuthService;
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _areAuthenticatedServicesLoaded =
      ValueNotifier<bool>(false);
  final Completer<void> _sessionBootstrapCompleter = Completer<void>();
  UserModel? _currentUser;
  bool _initialized = false;
  bool _isRestoringSession = false;

  AuthService(this._supabaseAuthService);

  Future<void> init() async {
    print('[AuthService] init() called');
    if (_initialized) {
      print('[AuthService] Already initialized');
      return;
    }
    _initialized = true;
    await _initSupabase();
    print('[AuthService] init() completed');
  }

  /// Initialize Supabase Auth
  Future<void> _initSupabase() async {
    try {
      _isRestoringSession = true;
      _isLoading.value = true;
      notifyListeners();

      await _supabaseAuthService.initialize();
      print('[AuthService] Supabase service initialized');

      // Listen to Supabase auth state changes
      _supabaseAuthService.authStateChanges.listen((AuthState state) async {
        final event = state.event;
        final session = state.session;

        debugPrint('[AuthService] Supabase auth event: $event');

        if (session != null) {
          // Authenticated
          debugPrint('[AuthService] User authenticated: ${session.user.email}');
          await _handleAuthenticatedSession(session);
        } else {
          // Logged out
          debugPrint('[AuthService] User logged out');
          await _clearStoredSession();
          _isAuthenticated.value = false;
          _areAuthenticatedServicesLoaded.value = false;
          _currentUser = null;
          _currentUser = null;
        }
        notifyListeners();
      });

      // Check current session
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        print('[AuthService] Found current session, handling...');
        await _handleAuthenticatedSession(currentSession);
        print('[AuthService] Current session handled');
      } else {
        print('[AuthService] No current session found');
        // Complete bootstrap if no session exists
        _completeSessionBootstrap();
      }
    } catch (e) {
      debugPrint(' Failed to initialize Supabase Auth: $e');
      // Complete bootstrap even on error to unblock the app
      _completeSessionBootstrap();
    } finally {
      _isRestoringSession = false;
      _isLoading.value = false;
      notifyListeners();
    }
  }

  Future<void> _handleAuthenticatedSession(Session session) async {
    // Ensure services are loaded even if already authenticated to prevent race conditions
    // and ensure _areAuthenticatedServicesLoaded is correctly set.
    if (_isAuthenticated.value && _areAuthenticatedServicesLoaded.value) {
      debugPrint(
          '[AuthService] Already authenticated and services loaded, completing bootstrap.');
      _completeSessionBootstrap();
      return;
    }

    final user = UserModel(
      id: session.user.id,
      email: session.user.email ?? '',
      name: session.user.userMetadata?['full_name'] ??
          session.user.email ??
          'User',
      picture: session.user.userMetadata?['avatar_url'],
      emailVerified: session.user.emailConfirmedAt != null
          ? DateTime.tryParse(session.user.emailConfirmedAt!)
          : null,
      updatedAt: DateTime.now(),
      createdAt: DateTime.parse(session.user.createdAt),
    );

    _currentUser = user;

    await _loadAuthenticatedServices();
    debugPrint(
        '[AuthService] Authenticated services loaded, _areAuthenticatedServicesLoaded.value: ${_areAuthenticatedServicesLoaded.value}');

    _isAuthenticated.value = true;
    debugPrint(
        '[AuthService] _isAuthenticated set to true, notifying listeners.');
    notifyListeners();

    // Complete session bootstrap after authenticated services are ready
    _completeSessionBootstrap();
  }

  /// Load authenticated services after authentication is confirmed
  Future<void> _loadAuthenticatedServices() async {
    try {
      debugPrint('[AuthService] Loading authenticated services...');

      final hasConnectionManager =
          di.serviceLocator.isRegistered<ConnectionManagerService>();

      if (hasConnectionManager) {
        _areAuthenticatedServicesLoaded.value = true;
        debugPrint(
            '[AuthService] ConnectionManagerService already registered, _areAuthenticatedServicesLoaded set to true, notifying listeners.');
        notifyListeners();
        return;
      }

      debugPrint('[AuthService] Calling setupAuthenticatedServices...');
      await di.setupAuthenticatedServices();
      debugPrint('[AuthService] setupAuthenticatedServices returned');
      _areAuthenticatedServicesLoaded.value = true;
      debugPrint(
          '[AuthService] _areAuthenticatedServicesLoaded set to true after setupAuthenticatedServices, notifying listeners.');
      notifyListeners();
    } catch (e) {
      debugPrint(
          '[AuthService] ERROR: Failed to load authenticated services: $e');
      _areAuthenticatedServicesLoaded.value = false;
      debugPrint(
          '[AuthService] _areAuthenticatedServicesLoaded set to false due to error, notifying listeners.');
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

  /// Login with Google
  Future<void> login({String? tenantId}) async {
    _isLoading.value = true;
    notifyListeners();
    try {
      await _supabaseAuthService.loginWithGoogle();
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading.value = true;
    notifyListeners();
    try {
      await _supabaseAuthService.logout();
      _isAuthenticated.value = false;
      _areAuthenticatedServicesLoaded.value = false;
      _currentUser = null;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  // Legacy/Unused methods stubbed for compatibility if needed
  Future<String?> getAccessToken() async =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Future<String?> getValidatedAccessToken() async => getAccessToken();

  Future<void> updateDisplayName(String name) async {}
  Future<bool> handleCallback({String? callbackUrl, String? code}) async {
    if (code != null) {
      try {
        debugPrint('[AuthService] Exchanging code for session...');
        final response =
            await Supabase.instance.client.auth.exchangeCodeForSession(code);
        debugPrint('[AuthService] Code exchange successful');
        await _handleAuthenticatedSession(response.session);
        return true;
      } catch (e) {
        debugPrint('[AuthService] Code exchange failed: $e');
        return false;
      }
    }
    // If no code is provided, we assume the session might be handled automatically
    // or we are just verifying the state.
    debugPrint('[AuthService] No code provided to handleCallback');
    return _isAuthenticated.value;
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    _areAuthenticatedServicesLoaded.dispose();
    super.dispose();
  }

  void _completeSessionBootstrap() {
    if (!_sessionBootstrapCompleter.isCompleted) {
      print('[AuthService] Completing session bootstrap');
      _sessionBootstrapCompleter.complete();
      print('[AuthService] Session bootstrap completed');
    } else {
      print('[AuthService] Session bootstrap already completed');
    }
  }

  // Helper to clear session
  Future<void> _clearStoredSession() async {
    // Logic to clear any local session storage if needed
  }
}
