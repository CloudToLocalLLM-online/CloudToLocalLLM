import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/supabase_config.dart';

/// Supabase implementation of the authentication provider
class SupabaseAuthProvider implements AuthProvider {
  final SupabaseClient _client;
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();
  UserModel? _currentUser;

  SupabaseAuthProvider() : _client = Supabase.instance.client {
    _client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      _currentUser = session != null ? _mapToUserModel(session.user) : null;
      _authStateController.add(session != null);
      
      debugPrint('[SupabaseAuthProvider] Auth state changed: $event');
    });
  }

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<void> initialize() async {
    // Supabase.initialize is typically called in main() 
    // but we can ensure session is loaded here
    final session = _client.auth.currentSession;
    _currentUser = session != null ? _mapToUserModel(session.user) : null;
    _authStateController.add(session != null);
  }

  @override
  Future<String?> getAccessToken() async {
    return _client.auth.currentSession?.accessToken;
  }

  @override
  Future<void> login() async {
    // Implement specific login logic if needed, e.g. Email/Password or OAuth
    throw UnimplementedError('Supabase login not implemented in this stub');
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    return true;
  }

  UserModel _mapToUserModel(User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['full_name'] ?? user.email ?? '',
      picture: user.userMetadata?['avatar_url'],
      createdAt: DateTime.parse(user.createdAt),
      updatedAt: DateTime.parse(user.updatedAt ?? user.createdAt),
    );
  }

  void dispose() {
    _authStateController.close();
  }
}
