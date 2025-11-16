// Stub for non-web platforms

// ignore_for_file: non_constant_identifier_names

class Auth0Bridge {
  // ignore: unused_field
  final dynamic _obj;

  Auth0Bridge(this._obj);

  Future<dynamic> initialize() async =>
      throw UnimplementedError('Not available on this platform');
  Future<dynamic> loginWithRedirect() async =>
      throw UnimplementedError('Not available on this platform');
  Future<dynamic> loginWithGoogle() async =>
      throw UnimplementedError('Not available on this platform');
  Future<dynamic> isAuthenticated() async =>
      throw UnimplementedError('Not available on this platform');
  Future<dynamic> getUser() async =>
      throw UnimplementedError('Not available on this platform');
  Future<dynamic> getAccessToken() async =>
      throw UnimplementedError('Not available on this platform');
  Future<dynamic> handleRedirectCallback() async =>
      throw UnimplementedError('Not available on this platform');
  Future<dynamic> logout() async =>
      throw UnimplementedError('Not available on this platform');
}

Auth0Bridge? get auth0Bridge => null;
