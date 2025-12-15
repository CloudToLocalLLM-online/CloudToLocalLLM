import 'dart:async';

import 'package:flutter/foundation.dart';

import '../di/locator.dart';
import '../main_sqflite_init.dart'
    if (dart.library.html) '../main_sqflite_init_stub.dart';

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
    try {
      print('[Bootstrapper] Starting bootstrap process...');

      print('[Bootstrapper] Initializing SQLite...');
      await _initializeSqflite();
      print('[Bootstrapper] SQLite initialized');

      print('[Bootstrapper] Setting up service locator...');
      await setupServiceLocator();
      print('[Bootstrapper] Service locator setup completed');

      print('[Bootstrapper] Bootstrap completed successfully');
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    } catch (e, stack) {
      print('[Bootstrapper] ERROR during bootstrap: $e');
      print('[Bootstrapper] Stack trace: $stack');

      // Re-throw to let the caller handle it
      rethrow;
    }
  }

  Future<void> _initializeSqflite() async {
    if (!kIsWeb) {
      initSqflite();
    }
  }
}
