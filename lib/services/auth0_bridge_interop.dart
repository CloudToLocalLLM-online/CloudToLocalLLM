// ignore_for_file: non_constant_identifier_names

import 'dart:js_interop';

@JS('window.auth0Bridge')
external JSObject? get auth0BridgeJS;

extension type Auth0Bridge(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> initialize();
  external JSPromise<JSBoolean> loginWithRedirect();
  external JSPromise<JSBoolean> loginWithGoogle();
  external JSPromise<JSBoolean> isAuthenticated();
  external JSPromise<JSString?> getUser();
  external JSPromise<JSString?> getAccessToken();
  external JSPromise<JSBoolean> handleRedirectCallback();
  external JSPromise<JSBoolean> logout();
}

Auth0Bridge? get auth0Bridge {
  final obj = auth0BridgeJS;
  return obj != null ? Auth0Bridge(obj) : null;
}
