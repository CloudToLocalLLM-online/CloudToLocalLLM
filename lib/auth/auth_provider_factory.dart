import '../config/app_config.dart';
import 'auth_provider.dart';
import 'providers/auth0_auth_provider.dart';
import 'providers/supabase_auth_provider.dart';

/// Factory for creating the configured authentication provider
class AuthProviderFactory {
  /// Create the authentication provider based on the application configuration
  static AuthProvider create() {
    switch (AppConfig.authProvider) {
      case AuthProviderType.auth0:
        return Auth0AuthProvider();
      case AuthProviderType.supabase:
        return SupabaseAuthProvider();
      default:
        // Default to Auth0 as per AppConfig
        return Auth0AuthProvider();
    }
  }
}
