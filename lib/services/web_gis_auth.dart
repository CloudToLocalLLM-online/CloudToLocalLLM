// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, non_constant_identifier_names, unused_element_parameter, unnecessary_library_name

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

// Global callback for when Google Identity Services library loads
@JS('onGoogleLibraryLoad')
external void onGoogleLibraryLoad();



/// Wait for Google Identity Services library to be ready
Future<void> _waitForGisReady() async {
  // Check if library is already ready
  final gisReady = js_util.getProperty(js_util.globalThis, 'gisReady');
  if (gisReady == true) return;

  // Wait for library to load (max 10 seconds)
  for (int i = 0; i < 100; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final ready = js_util.getProperty(js_util.globalThis, 'gisReady');
    if (ready == true) return;
  }

  throw StateError('Google Identity Services library failed to load within 10 seconds');
}

/// Perform a Google Identity Services sign-in and return the ID token (JWT)
Future<String> gisSignIn(String clientId) async {
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

  try {
    // Wait for Google Identity Services library to be ready
    await _waitForGisReady();

    // Check if Google Identity Services is available
    final google = js_util.getProperty(js_util.globalThis, 'google');
    if (google == null) {
      throw StateError('Google Identity Services library not loaded');
    }

    final accounts = js_util.getProperty(google, 'accounts');
    if (accounts == null) {
      throw StateError('Google accounts API not available');
    }

    final id = js_util.getProperty(accounts, 'id');
    if (id == null) {
      throw StateError('Google Identity Services ID API not available');
    }

    // Initialize the Google Identity Services
    js_util.callMethod(id, 'initialize', [
      js_util.jsify({
        'client_id': clientId,
        'callback': js_util.allowInterop(onCredential),
        'ux_mode': 'popup',
        'auto_select': false,
      })
    ]);

    // Prompt for sign-in
    js_util.callMethod(id, 'prompt', []);

  } catch (e) {
    if (!completer.isCompleted) completer.completeError(e);
  }

  return completer.future.timeout(
    const Duration(seconds: 90),
    onTimeout: () => throw TimeoutException('GIS sign-in timed out'),
  );
}

