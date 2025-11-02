// ignore_for_file: non_constant_identifier_names

import 'dart:js_interop';

@JS('window.auth0Bridge')
external JSObject? get auth0BridgeJS;

extension type Auth0Bridge(JSObject _) implements JSObject {
  external JSPromise<JSAny?> initialize();
  external JSPromise<JSAny?> loginWithRedirect();
  external JSPromise<JSAny?> loginWithGoogle();
  external JSPromise<JSAny?> isAuthenticated();
  external JSPromise<JSAny?> getUser();
  external JSPromise<JSAny?> getAccessToken();
  external JSPromise<JSAny?> handleRedirectCallback();
  external JSPromise<JSAny?> logout();
}

Auth0Bridge? get auth0Bridge {
  final obj = auth0BridgeJS;
  return obj != null ? Auth0Bridge(obj) : null;
}
