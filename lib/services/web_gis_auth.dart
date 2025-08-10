// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, non_constant_identifier_names, unused_element_parameter, unnecessary_library_name
@JS('google.accounts.id')

import 'dart:async';
import 'dart:js_util' as js_util;
import 'package:js/js.dart';

@JS()
@anonymous
class GisConfig {
  external String get clientId;
  external set clientId(String v);
  external Function get callback;
  external set callback(Function f);
  external String? get uxMode;
  external set uxMode(String? v);
  external String? get loginUri;
  external set loginUri(String? v);
  external bool? get autoSelect;
  external set autoSelect(bool? v);
  external factory GisConfig({String clientId, Function callback, String? uxMode, String? loginUri, bool? autoSelect});
}

@JS('initialize')
external void _initialize(GisConfig config);

@JS('prompt')
external void _prompt([Function? cb]);

final _gisReadyCompleter = Completer<void>();

@JS('onGoogleLibraryLoad')
external void _onGoogleLibraryLoad();

void _completeGisReady() {
  if (!_gisReadyCompleter.isCompleted) {
    _gisReadyCompleter.complete();
  }
}

Future<void> _waitForGisReady({Duration timeout = const Duration(seconds: 15)}) async {
  // Register the Dart function to be called from JavaScript
  js_util.setProperty(js_util.globalThis, 'onGoogleLibraryLoad', js_util.allowInterop(_completeGisReady));
  return _gisReadyCompleter.future.timeout(timeout);
}

/// Perform a Google Identity Services sign-in and return the ID token (JWT)
Future<String> gisSignIn(String clientId) async {
  await _waitForGisReady();

  final completer = Completer<String>();

  void onCredential(dynamic response) {
    try {
      final cred = js_util.getProperty<String?>(response, 'credential');
      if (cred != null && cred.isNotEmpty) {
        if (!completer.isCompleted) completer.complete(cred);
      } else {
        if (!completer.isCompleted) completer.completeError(StateError('Empty credential from GIS'));
      }
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }
  }

  _initialize(GisConfig(
    clientId: clientId,
    callback: allowInterop(onCredential),
    uxMode: 'popup',
    autoSelect: false,
  ));

  _prompt();

  return completer.future.timeout(
    const Duration(seconds: 90),
    onTimeout: () => throw TimeoutException('GIS sign-in timed out'),
  );
}

