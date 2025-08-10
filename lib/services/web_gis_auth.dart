@JS('google.accounts.id')
library web_gis_auth;

import 'dart:async';
import 'dart:js_util' as js_util;
import 'package:js/js.dart';

@JS()
@anonymous
class GisConfig {
  external String get client_id;
  external set client_id(String v);
  external Function get callback;
  external set callback(Function f);
  external String? get ux_mode;
  external set ux_mode(String? v);
  external bool? get auto_select;
  external set auto_select(bool? v);
  external factory GisConfig({String client_id, Function callback, String? ux_mode, bool? auto_select});
}

@JS('initialize')
external void _initialize(GisConfig config);

@JS('prompt')
external void _prompt([Function? cb]);

/// Perform a Google Identity Services sign-in and return the ID token (JWT)
Future<String> gisSignIn(String clientId) {
  final completer = Completer<String>();

  void onCredential(dynamic response) {
    try {
      final cred = js_util.getProperty<String>(response, 'credential');
      if (cred is String && cred.isNotEmpty) {
        if (!completer.isCompleted) completer.complete(cred);
      } else {
        if (!completer.isCompleted) completer.completeError(StateError('Empty credential from GIS'));
      }
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }
  }

  // Initialize GIS with popup UX for better reliability in SPA
  _initialize(GisConfig(
    client_id: clientId,
    callback: allowInterop(onCredential),
    ux_mode: 'popup',
    auto_select: false,
  ));

  // Show prompt (popup will be used due to ux_mode)
  _prompt();

  return completer.future.timeout(
    const Duration(seconds: 90),
    onTimeout: () => throw TimeoutException('GIS sign-in timed out'),
  );
}

