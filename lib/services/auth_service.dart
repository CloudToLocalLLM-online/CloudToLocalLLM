// Re-export GCIP Auth Service as AuthService
export 'gcip_auth_service.dart' show GCIPAuthService;

// Create alias for backwards compatibility
import 'gcip_auth_service.dart';

class AuthService extends GCIPAuthService {
  AuthService() : super();
}
