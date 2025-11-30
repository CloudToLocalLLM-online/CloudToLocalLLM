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
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _initSupabase();
  }

  /// Initialize Supabase Auth
  Future<void> _initSupabase() async {
    try {
      _isRestoringSession = true;
      _isLoading.value = true;
      notifyListeners();

      await _supabaseAuthService.initialize();

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
        await _handleAuthenticatedSession(currentSession);
      }
    } catch (e) {
      debugPrint(' Failed to initialize Supabase Auth: $e');
    } finally {
      _isRestoringSession = false;
      _isLoading.value = false;
      _completeSessionBootstrap();
      notifyListeners();
    }
  }

  Future<void> _handleAuthenticatedSession(Session session) async {
    if (_isAuthenticated.value) return;

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
    _isAuthenticated.value = true;
    notifyListeners();

    await _loadAuthenticatedServices();
  }

  /// Load authenticated services after authentication is confirmed
  Future<void> _loadAuthenticatedServices() async {
    try {
      debugPrint('[AuthService] Loading authenticated services...');

      final hasConnectionManager =
          di.serviceLocator.isRegistered<ConnectionManagerService>();

      if (hasConnectionManager) {
        _areAuthenticatedServicesLoaded.value = true;
        notifyListeners();
        return;
      }

      await di.setupAuthenticatedServices();
      _areAuthenticatedServicesLoaded.value = true;
      notifyListeners();
    } catch (e) {
      debugPrint(
          '[AuthService] ERROR: Failed to load authenticated services: $e');
      _areAuthenticatedServicesLoaded.value = false;
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
  Future<bool> handleCallback({String? callbackUrl}) async => true;

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    _areAuthenticatedServicesLoaded.dispose();
    super.dispose();
  }

  void _completeSessionBootstrap() {
    if (!_sessionBootstrapCompleter.isCompleted) {
      _sessionBootstrapCompleter.complete();
    }
  }

  // Helper to clear session
  Future<void> _clearStoredSession() async {
    // Logic to clear any local session storage if needed
  }
}
