import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> initialize() async {
    // Initialization is handled in main.dart via Supabase.initialize()
    debugPrint('[SupabaseAuthService] Service initialized');
  }

  Future<void> loginWithGoogle() async {
    debugPrint('[SupabaseAuthService] Logging in with Google...');
    try {
      String? redirectTo;
      String? redirectTo;
      if (kIsWeb) {
        // If running locally, enforce port 3000 to match Supabase whitelist.
        // If running in production (not localhost), use the current origin.
        final host = Uri.base.host;
        if (host == 'localhost' || host == '127.0.0.1') {
          redirectTo = 'http://localhost:3000/callback';
        } else {
          redirectTo = '${Uri.base.origin}/callback';
        }
      } else {
        redirectTo = 'io.supabase.flutterquickstart://login-callback/';
      }

      debugPrint('[SupabaseAuthService] Using redirectTo: $redirectTo');

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      debugPrint('[SupabaseAuthService] OAuth flow initiated');
    } catch (e) {
      debugPrint('[SupabaseAuthService] Login failed: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    debugPrint('[SupabaseAuthService] Logging out...');
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
