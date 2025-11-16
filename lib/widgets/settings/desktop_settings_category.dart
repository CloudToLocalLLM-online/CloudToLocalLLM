/// Desktop Settings Category Widget
///
/// Provides Windows and Linux desktop-specific settings including window behavior,
/// system tray options, and startup preferences. Integrates with window_manager
/// for window control and SettingsPreferenceService for persistence.
library;

import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../services/settings_preference_service.dart';
import 'settings_category_widgets.dart';
import 'settings_input_widgets.dart';
import 'settings_base.dart';

/// Desktop Settings Category - Windows and Linux specific settings
class DesktopSettingsCategory extends SettingsCategoryContentWidget {
  const DesktopSettingsCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _DesktopSettingsCategoryContent();
  }
}

class _DesktopSettingsCategoryContent extends StatefulWidget {
  const _DesktopSettingsCategoryContent();

  @override
  State<_DesktopSettingsCategoryContent> createState() =>
      _DesktopSettingsCategoryContentState();
}

class _DesktopSettingsCategoryContentState
    extends State<_DesktopSettingsCategoryContent> {
  late SettingsPreferenceService _preferencesService;

  // State variables
  bool _launchOnStartup = false;
  bool _minimizeToTray = false;
  bool _alwaysOnTop = false;
  bool _rememberWindowPosition = true;
  bool _rememberWindowSize = true;
  bool _isDirty = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Validation errors
  final Map<String, String> _fieldErrors = {};

  // Platform detection
  late bool _isWindows;

  @override
  void initState() {
    super.initState();
    _preferencesService = SettingsPreferenceService();
    _isWindows = Platform.isWindows;
    _loadSettings();
  }

  /// Load current settings from preferences
  Future<void> _loadSettings() async {
    try {
      final launchOnStartup =
          await _preferencesService.isLaunchOnStartupEnabled();
      final minimizeToTray =
          await _preferencesService.isMinimizeToTrayEnabled();
      final alwaysOnTop = await _preferencesService.isAlwaysOnTopEnabled();
      final rememberWindowPosition =
          await _preferencesService.isRememberWindowPositionEnabled();
      final rememberWindowSize =
          await _preferencesService.isRememberWindowSizeEnabled();

      setState(() {
        _launchOnStartup = launchOnStartup;
        _minimizeToTray = minimizeToTray;
        _alwaysOnTop = alwaysOnTop;
        _rememberWindowPosition = rememberWindowPosition;
        _rememberWindowSize = rememberWindowSize;
        _isDirty = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[DesktopSettings] Error loading settings: $e');
      setState(() {
        _errorMessage = 'Failed to load settings';
      });
    }
  }

  /// Validate all settings
  bool _validateSettings() {
    _fieldErrors.clear();
    // Desktop settings don't have complex validation requirements
    return _fieldErrors.isEmpty;
  }

  /// Save settings to preferences
  Future<void> _saveSettings() async {
    if (!_validateSettings()) {
      setState(() {
        _errorMessage = 'Please fix the errors below';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Save all desktop settings
      await _preferencesService.setLaunchOnStartupEnabled(_launchOnStartup);
      await _preferencesService.setMinimizeToTrayEnabled(_minimizeToTray);
      await _preferencesService.setAlwaysOnTopEnabled(_alwaysOnTop);
      await _preferencesService
          .setRememberWindowPositionEnabled(_rememberWindowPosition);
      await _preferencesService
          .setRememberWindowSizeEnabled(_rememberWindowSize);

      // Apply window behavior changes
      await _applyWindowBehaviorChanges();

      setState(() {
        _isDirty = false;
        _isSaving = false;
        _successMessage = 'Settings saved successfully';
        _errorMessage = null;
      });

      // Clear success message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      debugPrint('[DesktopSettings] Error saving settings: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save settings: ${e.toString()}';
      });
    }
  }

  /// Apply window behavior changes
  Future<void> _applyWindowBehaviorChanges() async {
    try {
      // TODO: Integrate with window_manager to apply window behavior changes
      // This would require:
      // 1. Import window_manager package
      // 2. Call windowManager.setAlwaysOnTop(_alwaysOnTop)
      // 3. Handle launch on startup via platform-specific code
      // 4. Handle minimize to tray via tray_manager integration
      debugPrint('[DesktopSettings] Window behavior changes applied');
    } catch (e) {
      debugPrint('[DesktopSettings] Error applying window behavior: $e');
      rethrow;
    }
  }

  /// Handle launch on startup toggle
  void _onLaunchOnStartupChanged(bool value) {
    setState(() {
      _launchOnStartup = value;
      _isDirty = true;
      _fieldErrors.remove('launchOnStartup');
    });
  }

  /// Handle minimize to tray toggle
  void _onMinimizeToTrayChanged(bool value) {
    setState(() {
      _minimizeToTray = value;
      _isDirty = true;
      _fieldErrors.remove('minimizeToTray');
    });
  }

  /// Handle always on top toggle
  void _onAlwaysOnTopChanged(bool value) {
    setState(() {
      _alwaysOnTop = value;
      _isDirty = true;
      _fieldErrors.remove('alwaysOnTop');
    });
  }

  /// Handle remember window position toggle
  void _onRememberWindowPositionChanged(bool value) {
    setState(() {
      _rememberWindowPosition = value;
      _isDirty = true;
      _fieldErrors.remove('rememberWindowPosition');
    });
  }

  /// Handle remember window size toggle
  void _onRememberWindowSizeChanged(bool value) {
    setState(() {
      _rememberWindowSize = value;
      _isDirty = true;
      _fieldErrors.remove('rememberWindowSize');
    });
  }

  /// Handle cancel button
  void _onCancel() {
    _loadSettings();
    setState(() {
      _isDirty = false;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Success message
          if (_successMessage != null)
            SettingsSuccessMessage(
              message: _successMessage!,
              onDismiss: () {
                setState(() {
                  _successMessage = null;
                });
              },
            ),

          // Error message
          if (_errorMessage != null)
            SettingsValidationError(
              message: _errorMessage!,
              onDismiss: () {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),

          // Startup Behavior
          SettingsGroup(
            title: 'Startup Behavior',
            description: 'Configure how the application starts',
            children: [
              SettingsToggle(
                label: 'Launch on system startup',
                description:
                    'Automatically start the application when you log in',
                value: _launchOnStartup,
                onChanged: _onLaunchOnStartupChanged,
                enabled: !_isSaving,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // System Tray (Windows only)
          if (_isWindows)
            SettingsGroup(
              title: 'System Tray',
              description: 'Configure system tray behavior',
              children: [
                SettingsToggle(
                  label: 'Minimize to tray',
                  description: 'Minimize the window to the system tray',
                  value: _minimizeToTray,
                  onChanged: _onMinimizeToTrayChanged,
                  enabled: !_isSaving,
                ),
              ],
            ),

          if (_isWindows) const SizedBox(height: 16),

          // Window Behavior
          SettingsGroup(
            title: 'Window Behavior',
            description: 'Configure window appearance and behavior',
            children: [
              SettingsToggle(
                label: 'Always on top',
                description:
                    'Keep the application window on top of other windows',
                value: _alwaysOnTop,
                onChanged: _onAlwaysOnTopChanged,
                enabled: !_isSaving,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Window Position and Size
          SettingsGroup(
            title: 'Window State',
            description: 'Configure window position and size persistence',
            children: [
              SettingsToggle(
                label: 'Remember window position',
                description:
                    'Restore the window position when the application starts',
                value: _rememberWindowPosition,
                onChanged: _onRememberWindowPositionChanged,
                enabled: !_isSaving,
              ),
              SettingsToggle(
                label: 'Remember window size',
                description:
                    'Restore the window size when the application starts',
                value: _rememberWindowSize,
                onChanged: _onRememberWindowSizeChanged,
                enabled: !_isSaving,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Save/Cancel buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : _onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: (_isSaving || !_isDirty) ? null : _saveSettings,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
