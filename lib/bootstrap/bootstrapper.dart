import 'dart:async';

import 'package:flutter/foundation.dart';

import '../di/locator.dart';
import '../main_sqflite_init.dart';

/// Data returned by [AppBootstrapper] after the core environment is ready.
class AppBootstrapData {
  AppBootstrapData({required this.isWeb, required this.supportsNativeShell});

  final bool isWeb;
  final bool supportsNativeShell;
}

/// Handles the one-time initialization that must occur before the widget tree
/// is built.  This ensures heavy setup only happens once at application start.
class AppBootstrapper {
  AppBootstrapper();

  Future<AppBootstrapData> load() async {
    await _initializeSqflite();
    await setupServiceLocator();

    return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
  }

  Future<void> _initializeSqflite() async {
    if (!kIsWeb) {
      initSqflite();
    }
  }
}
