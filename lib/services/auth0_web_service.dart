import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'auth0_bridge_interop.dart';
import 'auth0_service.dart';

class Auth0WebService implements Auth0Service {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Map<String, dynamic>? get currentUser => _currentUser;

  @override
  String? getAccessToken() => _accessToken;

  @override
  Future<void> initialize() async {
    await checkAuthStatus();
  }

  @override
  Future<void> login() async {
    await auth0Bridge?.loginWithRedirect();
  }

  @override
  Future<void> logout() async {
    await auth0Bridge?.logout();
    _isAuthenticated = false;
    _currentUser = null;
    _accessToken = null;
    _authStateController.add(false);
  }

  @override
  Future<bool> handleRedirectCallback() async {
    try {
      final JSPromise? resultPromise = auth0Bridge?.handleRedirectCallback();
      if (resultPromise == null) {
        return false;
      }
      await resultPromise.toDart;
      await checkAuthStatus();
      return _isAuthenticated;
    } catch (e) {
      debugPrint('Error handling redirect callback: $e');
      return false;
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final JSPromise? isAuthPromise = auth0Bridge?.isAuthenticated();
      if (isAuthPromise == null) {
        _isAuthenticated = false;
        return;
      }
      final dynamic isAuth = await isAuthPromise.toDart;
      final wasAuthenticated = _isAuthenticated;

      if (isAuth != null && isAuth.isA<JSBoolean>()) {
        _isAuthenticated = (isAuth as JSBoolean).toDart;
      } else if (isAuth is bool) {
        _isAuthenticated = isAuth;
      } else {
        _isAuthenticated = false;
      }

      if (_isAuthenticated) {
        final userPromise = auth0Bridge!.getUser();
        final tokenPromise = auth0Bridge!.getAccessToken();

        final user = await userPromise.toDart;
        final token = await tokenPromise.toDart;

        if (user != null && user.isA<JSObject>()) {
          _currentUser = _jsObjectToMap(user as JSObject);
        }
        if (token != null && token.isA<JSString>()) {
          _accessToken = (token as JSString).toDart;
        }
      }

      if (wasAuthenticated != _isAuthenticated) {
        _authStateController.add(_isAuthenticated);
      }
    } catch (e, stackTrace) {
      debugPrint('Auth0 checkAuthStatus error: $e');
      debugPrint(stackTrace.toString());
      _isAuthenticated = false;
      _authStateController.add(false);
    }
  }

  Map<String, dynamic> _jsObjectToMap(JSObject jsObject) {
    final map = <String, dynamic>{};
    final keys = jsObject.keys;
    for (final key in keys) {
      final value = jsObject[key];
      if (value != null) {
        map[key] = _convertToDart(value);
      }
    }
    return map;
  }

  dynamic _convertToDart(JSAny? value) {
    if (value == null) return null;
    if (value.isA<JSBoolean>()) return (value as JSBoolean).toDart;
    if (value.isA<JSString>()) return (value as JSString).toDart;
    if (value.isA<JSNumber>()) return (value as JSNumber).toDart;
    if (value.isA<JSObject>()) return _jsObjectToMap(value as JSObject);
    return value.toString();
  }

  @override
  void dispose() {
    _authStateController.close();
  }
}

extension on JSObject {
  external JSArray get keys;
  external JSAny? operator [](String key);
}

