import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Simple client-side log buffer that mirrors debug output into localStorage.
///
/// This allows us to inspect the last N log entries even if the page reloads
/// or loses its console output during rapid redirect loops.
class LogBufferService {
  static const String storageKey = 'app_client_log_buffer';
  static final LogBufferService instance = LogBufferService._internal();

  final int maxEntries;

  LogBufferService._internal() : maxEntries = 500;

  void add(String message, {String level = 'INFO'}) {
    if (!kIsWeb) {
      return;
    }

    try {
      final storage = web.window.localStorage;
      final existing = storage.getItem(storageKey);
      final List<dynamic> logList = existing != null && existing.isNotEmpty
          ? (jsonDecode(existing) as List<dynamic>)
          : <dynamic>[];

      logList.add(<String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'level': level,
        'message': message,
      });

      if (logList.length > maxEntries) {
        final start = logList.length - maxEntries;
        storage.setItem(storageKey, jsonEncode(logList.sublist(start)));
      } else {
        storage.setItem(storageKey, jsonEncode(logList));
      }
    } catch (_) {
      // Fallback silently – logging should never crash the app.
    }
  }

  void clear() {
    if (!kIsWeb) {
      return;
    }
    try {
      web.window.localStorage.removeItem(storageKey);
    } catch (_) {}
  }

  String? export() {
    if (!kIsWeb) {
      return null;
    }
    try {
      return web.window.localStorage.getItem(storageKey);
    } catch (_) {
      return null;
    }
  }
}
