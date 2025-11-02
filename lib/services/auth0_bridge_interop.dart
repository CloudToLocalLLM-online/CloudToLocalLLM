// ignore_for_file: non_constant_identifier_names

import 'dart:js_interop';

@JS('auth0Bridge')
external JSObject? get auth0BridgeJS;

extension type Auth0Bridge(JSObject obj) {
  external JSPromise initialize();
  external JSPromise loginWithRedirect();
  external JSPromise loginWithGoogle();
  external JSPromise isAuthenticated();
  external JSPromise getUser();
  external JSPromise getAccessToken();
  external JSPromise handleRedirectCallback();
  external JSPromise logout();
  external JSBoolean isInitialized();
}

Auth0Bridge? get auth0Bridge {
  final obj = auth0BridgeJS;
  return obj != null ? Auth0Bridge(obj) : null;
}
