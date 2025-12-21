import 'package:auth0_flutter/auth0_flutter.dart';

class Auth0Web {
  Auth0Web(String domain, String clientId);

  Future<Credentials?> onLoad() async => null;
  Future<void> loginWithRedirect(
      {Set<String>? scopes, String? audience, String? redirectUri}) async {}
  Future<void> logout() async {}
}
