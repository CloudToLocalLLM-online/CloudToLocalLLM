import 'auth0_service.dart';
import 'auth0_web_service.dart';

Auth0Service createAuth0Service() {
  return Auth0WebService();
}
