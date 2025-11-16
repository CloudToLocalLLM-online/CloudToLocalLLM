/// Mobile Settings Category Widget
///
/// Provides mobile-specific settings including biometric authentication,
/// notifications, notification sound, and vibration preferences.
/// Integrates with SettingsPreferenceService for persistence.
library;

import 'package:flutter/material.dart';
import '../../services/settings_preference_service.dart';
import 'settings_category_widgets.dart';
import 'settings_input_widgets.dart';
import 'settings_base.dart';

/// Mobile Settings Category - Biometric, Notifications, and Mobile Preferences
class MobileSettingsCategory extends SettingsCategoryContentWidget {
  const MobileSettingsCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _MobileSettingsCategoryContent();
  }
}

class _MobileSettingsCategoryContent extends StatefulWidget {
  const _MobileSettingsCategoryContent();

  @override
  State<_MobileSettingsCategoryContent> createState() =>
      _MobileSettingsCategoryContentState();
}

class _MobileSettingsCategoryContentState
    extends State<_MobileSettingsCategoryContent> {
  late SettingsPreferenceService _preferencesService;

  // State variables
  bool _biometricAuthEnabled = false;
  bool _notificationsEnabled = true;
  bool _notificationSoundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isDirty = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _preferencesService = SettingsPreferenceService();
    _loadSettings();
  }

  /// Load current mobile settings from preferences
  Future<void> _loadSettings() async {
    try {
      final biometricEnabled =
          await _preferencesService.isBiometricAuthEnabled();
      final notificationsEnabled =
          await _preferencesService.isNotificationsEnabled();
      final notificationSoundEnabled =
          await _preferencesService.isNotificationSoundEnabled();
      final vibrationEnabled = await _preferencesService.isVibrationEnabled();

      setState(() {
        _biometricAuthEnabled = biometricEnabled;
        _notificationsEnabled = notificationsEnabled;
        _notificationSoundEnabled = notificationSoundEnabled;
        _vibrationEnabled = vibrationEnabled;
        _isDirty = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[MobileSettings] Error loading settings: $e');
      setState(() {
        _errorMessage = 'Failed to load mobile settings';
      });
    }
  }

  /// Save mobile settings to preferences
  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Save mobile preferences
      await _preferencesService.setBiometricAuthEnabled(_biometricAuthEnabled);
      await _preferencesService.setNotificationsEnabled(_notificationsEnabled);
      await _preferencesService
          .setNotificationSoundEnabled(_notificationSoundEnabled);
      await _preferencesService.setVibrationEnabled(_vibrationEnabled);

      setState(() {
        _isDirty = false;
        _isSaving = false;
        _successMessage = 'Mobile settings saved successfully';
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
      debugPrint('[MobileSettings] Error saving settings: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save mobile settings: ${e.toString()}';
      });
    }
  }

  /// Handle biometric authentication toggle change
  void _onBiometricAuthChanged(bool value) {
    setState(() {
      _biometricAuthEnabled = value;
      _isDirty = true;
    });
  }

  /// Handle notifications toggle change
  void _onNotificationsChanged(bool value) {
    setState(() {
      _notificationsEnabled = value;
      _isDirty = true;
      // Disable notification sound and vibration if notifications are disabled
      if (!value) {
        _notificationSoundEnabled = false;
        _vibrationEnabled = false;
      }
    });
  }

  /// Handle notification sound toggle change
  void _onNotificationSoundChanged(bool value) {
    setState(() {
      _notificationSoundEnabled = value;
      _isDirty = true;
    });
  }

  /// Handle vibration toggle change
  void _onVibrationChanged(bool value) {
    setState(() {
      _vibrationEnabled = value;
      _isDirty = true;
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

          // Biometric Authentication Section
          SettingsGroup(
            title: 'Security',
            description: 'Configure biometric authentication and security',
            children: [
              SettingsToggle(
                label: 'Biometric Authentication',
                description:
                    'Use Face ID, Touch ID, or Fingerprint to unlock the app',
                value: _biometricAuthEnabled,
                onChanged: _isSaving ? null : _onBiometricAuthChanged,
                enabled: !_isSaving,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Notifications Section
          SettingsGroup(
            title: 'Notifications',
            description: 'Control notification preferences',
            children: [
              SettingsToggle(
                label: 'Enable Notifications',
                description: 'Receive notifications from the application',
                value: _notificationsEnabled,
                onChanged: _isSaving ? null : _onNotificationsChanged,
                enabled: !_isSaving,
              ),
              Divider(
                height: 1,
                color: Colors.grey.shade300,
                indent: 16,
                endIndent: 16,
              ),
              SettingsToggle(
                label: 'Notification Sound',
                description: 'Play sound when notifications arrive',
                value: _notificationSoundEnabled,
                onChanged: (_notificationsEnabled && !_isSaving)
                    ? _onNotificationSoundChanged
                    : null,
                enabled: _notificationsEnabled && !_isSaving,
              ),
              Divider(
                height: 1,
                color: Colors.grey.shade300,
                indent: 16,
                endIndent: 16,
              ),
              SettingsToggle(
                label: 'Vibration',
                description: 'Vibrate when notifications arrive',
                value: _vibrationEnabled,
                onChanged: (_notificationsEnabled && !_isSaving)
                    ? _onVibrationChanged
                    : null,
                enabled: _notificationsEnabled && !_isSaving,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Accessibility Note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All touch targets are optimized for mobile accessibility (minimum 44x44 pixels)',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

/// Settings success message widget
class SettingsSuccessMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const SettingsSuccessMessage({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.green.shade600),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, color: Colors.green.shade600),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// Settings validation error widget
class SettingsValidationError extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const SettingsValidationError({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade600),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, color: Colors.red.shade600),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
