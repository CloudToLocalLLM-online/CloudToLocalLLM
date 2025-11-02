// ignore_for_file: non_constant_identifier_names
// ignore_for_file: deprecated_member_use
// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:js/js.dart';
import 'dart:async';
import 'dart:js_util' as js_util;

@JS('window.auth0Bridge')
external dynamic get auth0BridgeJS;

class Auth0Bridge {
  final dynamic _obj;
  
  Auth0Bridge(this._obj);
  
  Future<dynamic> initialize() async {
    return js_util.promiseToFuture(js_util.callMethod(_obj, 'initialize', []));
  }
  
  Future<dynamic> loginWithRedirect() async {
    return js_util.promiseToFuture(js_util.callMethod(_obj, 'loginWithRedirect', []));
  }
  
  Future<dynamic> loginWithGoogle() async {
    return js_util.promiseToFuture(js_util.callMethod(_obj, 'loginWithGoogle', []));
  }
  
  Future<dynamic> isAuthenticated() async {
    return js_util.promiseToFuture(js_util.callMethod(_obj, 'isAuthenticated', []));
  }
  
  Future<dynamic> getUser() async {
    return js_util.promiseToFuture(js_util.callMethod(_obj, 'getUser', []));
  }
  
  Future<dynamic> getAccessToken() async {
    return js_util.promiseToFuture(js_util.callMethod(_obj, 'getAccessToken', []));
  }
  
  Future<dynamic> handleRedirectCallback() async {
    return js_util.promiseToFuture(js_util.callMethod(_obj, 'handleRedirectCallback', []));
  }
  
  Future<dynamic> logout() async {
    return js_util.promiseToFuture(js_util.callMethod(_obj, 'logout', []));
  }
}

Auth0Bridge? get auth0Bridge {
  final obj = auth0BridgeJS;
  return obj != null ? Auth0Bridge(obj) : null;
}

