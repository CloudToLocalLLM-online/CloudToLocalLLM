// ignore_for_file: non_constant_identifier_names

@JS()
import 'dart:js_interop';

@JS('auth0Bridge')
external Auth0Bridge? get auth0Bridge;

@JS()
@anonymous
extension type Auth0Bridge(JSObject obj) {
  external JSPromise initialize();
  external JSPromise loginWithRedirect();
  external JSPromise loginWithGoogle();
  external JSPromise isAuthenticated();
  external JSPromise getUser();
  external JSPromise getAccessToken();
  external JSPromise handleRedirectCallback();
  external JSPromise logout();
  external bool isInitialized();
}
