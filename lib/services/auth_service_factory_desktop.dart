import 'auth0_service.dart';
import 'auth0_desktop_service.dart';

Auth0Service createAuth0Service() {
  return Auth0DesktopService();
}
