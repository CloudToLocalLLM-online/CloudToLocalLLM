/// Theme Provider Service
///
/// Manages application theme mode (light, dark, system) with persistence.
/// Integrates with MaterialApp.router to control theme across the app.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Service for managing application theme mode
class ThemeProvider extends ChangeNotifier {
  static const String _themePreferenceKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadThemePreference();
  }

  /// Get current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Check if dark mode is enabled
  bool get isDarkMode {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        // For system mode, we can't determine without platform brightness
        // This will be handled by MaterialApp.router
        return false;
    }
  }

  /// Set theme mode and persist preference
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    await _saveThemePreference(mode);
    notifyListeners();
    debugPrint('[ThemeProvider] Theme mode changed to: $mode');
  }

  /// Set theme mode from string (for settings UI)
  Future<void> setThemeModeFromString(String themeString) async {
    ThemeMode mode;
    switch (themeString.toLowerCase()) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      case 'system':
      default:
        mode = ThemeMode.system;
        break;
    }
    await setThemeMode(mode);
  }

  /// Get theme mode as string (for settings UI)
  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Load theme preference from storage
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themePreferenceKey);
      
      if (themeString != null) {
        switch (themeString.toLowerCase()) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
          default:
            // Fallback to AppConfig if invalid value
            _themeMode = AppConfig.enableDarkMode 
                ? ThemeMode.dark 
                : ThemeMode.light;
        }
      } else {
        // No saved preference, use AppConfig default
        _themeMode = AppConfig.enableDarkMode 
            ? ThemeMode.dark 
            : ThemeMode.light;
      }
      
      debugPrint('[ThemeProvider] Loaded theme mode: $_themeMode');
      notifyListeners();
    } catch (e) {
      debugPrint('[ThemeProvider] Error loading theme preference: $e');
      // Fallback to AppConfig
      _themeMode = AppConfig.enableDarkMode 
          ? ThemeMode.dark 
          : ThemeMode.light;
    }
  }

  /// Save theme preference to storage
  Future<void> _saveThemePreference(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;
      switch (mode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.system:
          themeString = 'system';
          break;
      }
      await prefs.setString(_themePreferenceKey, themeString);
      debugPrint('[ThemeProvider] Saved theme preference: $themeString');
    } catch (e) {
      debugPrint('[ThemeProvider] Error saving theme preference: $e');
    }
  }
}

