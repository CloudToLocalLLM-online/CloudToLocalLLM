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
      if (kIsWeb) {
        // Use the current origin (scheme + host + port)
        // Redirects to root (e.g. https://cloudtolocalllm.online:3000/)
        // Router will handle the 'code' parameter and route to /callback
        redirectTo = Uri.base.origin;
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
