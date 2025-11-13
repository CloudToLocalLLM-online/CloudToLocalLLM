// ignore_for_file: non_constant_identifier_names
// ignore_for_file: deprecated_member_use
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';

@JS('auth0Bridge')
external Auth0Bridge? get auth0Bridge;

@JS()
@anonymous
extension type Auth0Bridge._(JSObject _) implements JSObject {
  external bool isInitialized();
  external bool isCallbackUrl();
  external JSPromise<JSAny?> loginWithRedirect();
  external JSPromise<JSAny?> logout();
  external JSPromise<JSAny?> handleRedirectCallback();
  external JSPromise<JSAny?> isAuthenticated();
  external JSPromise<JSAny?> getUser();
  external JSPromise<JSAny?> getAccessToken();
}

