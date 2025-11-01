// Web stub for WindowManagerService - not available on web
import 'package:flutter/foundation.dart';

/// Web stub for WindowManagerService
class WindowManagerService {
  static final WindowManagerService _instance = WindowManagerService._internal();
  factory WindowManagerService() => _instance;
  WindowManagerService._internal();

  bool _isWindowVisible = true;
  bool _isMinimizedToTray = false;
  // ignore: unused_field
  bool _isInitialized = false;

  Future<void> initialize() async {
    debugPrint('[WindowManager] Window management not supported on web platform');
    _isInitialized = false;
  }
  
  Future<void> showWindow() async {
    _isWindowVisible = true;
    _isMinimizedToTray = false;
  }
  
  Future<void> hideToTray() async {
    _isWindowVisible = false;
    _isMinimizedToTray = true;
  }
  
  Future<void> minimizeWindow() async {}
  Future<void> maximizeWindow() async {}
  Future<void> closeWindow() async {}
  
  bool get isWindowVisible => _isWindowVisible;
  bool get isMinimizedToTray => _isMinimizedToTray;
  
  void dispose() {}
}

