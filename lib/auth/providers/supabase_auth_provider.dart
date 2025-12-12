import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloudtolocalllm/auth/auth_provider.dart' as app_auth;
import 'package:cloudtolocalllm/models/user_model.dart';

class SupabaseAuthProvider implements app_auth.AuthProvider {
  final SupabaseClient _supabase;
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  UserModel? _currentUser;

  SupabaseAuthProvider() : _supabase = Supabase.instance.client;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    final session = _supabase.auth.currentSession;
    _updateUserFromSession(session);

    _supabase.auth.onAuthStateChange.listen((data) {
      _updateUserFromSession(data.session);
    });
  }

  void _updateUserFromSession(Session? session) {
    if (session != null && session.user.email != null) {
      _currentUser = UserModel(
        id: session.user.id,
        email: session.user.email!,
        name: session.user.userMetadata?['full_name'] ??
            session.user.email!.split('@')[0],
        createdAt: DateTime.parse(session.user.createdAt),
        updatedAt: session.user.updatedAt != null
            ? DateTime.parse(session.user.updatedAt!)
            : DateTime.now(),
      );
      _authStateController.add(true);
    } else {
      _currentUser = null;
      _authStateController.add(false);
    }
  }

  @override
  Future<void> login() async {
    // Implement login logic here, e.g., redirect to Supabase login page or show dialog
    // For now, we'll assume the user triggers login via Supabase Widgets or other means
    // This method is often project-specific for Supabase (Email/Password, Magic Link, OAuth)
    throw UnimplementedError('Login triggers are handled by Supabase Widgets');
  }

  @override
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<String?> getAccessToken() async {
    return _supabase.auth.currentSession?.accessToken;
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    // Supabase handles auth state changes via the stream listener in initialize()
    // but this might be needed for specific deep link handling if not covered by auto-detect.
    // For now, no-op as the listener covers the state update.
    return true;
  }
}
