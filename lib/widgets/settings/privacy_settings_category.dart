/// Privacy Settings Category Widget
///
/// Provides privacy and data collection preferences including analytics,
/// crash reporting, usage statistics, and data clearing functionality.
/// Integrates with SettingsPreferenceService for persistence.
library;

import 'package:flutter/material.dart';
import '../../services/settings_preference_service.dart';
import 'settings_category_widgets.dart';
import 'settings_input_widgets.dart';
import 'settings_base.dart';

/// Privacy Settings Category - Data Collection and Privacy Preferences
class PrivacySettingsCategory extends SettingsCategoryContentWidget {
  const PrivacySettingsCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _PrivacySettingsCategoryContent();
  }
}

class _PrivacySettingsCategoryContent extends StatefulWidget {
  const _PrivacySettingsCategoryContent();

  @override
  State<_PrivacySettingsCategoryContent> createState() =>
      _PrivacySettingsCategoryContentState();
}

class _PrivacySettingsCategoryContentState
    extends State<_PrivacySettingsCategoryContent> {
  late SettingsPreferenceService _preferencesService;

  // State variables
  bool _analyticsEnabled = true;
  bool _crashReportingEnabled = true;
  bool _usageStatsEnabled = true;
  bool _isDirty = false;
  bool _isSaving = false;
  bool _isClearing = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _preferencesService = SettingsPreferenceService();
    _loadSettings();
  }

  /// Load current privacy settings from preferences
  Future<void> _loadSettings() async {
    try {
      final analyticsEnabled = await _preferencesService.isAnalyticsEnabled();
      final crashReportingEnabled =
          await _preferencesService.isCrashReportingEnabled();
      final usageStatsEnabled = await _preferencesService.isUsageStatsEnabled();

      setState(() {
        _analyticsEnabled = analyticsEnabled;
        _crashReportingEnabled = crashReportingEnabled;
        _usageStatsEnabled = usageStatsEnabled;
        _isDirty = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[PrivacySettings] Error loading settings: $e');
      setState(() {
        _errorMessage = 'Failed to load privacy settings';
      });
    }
  }

  /// Save privacy settings to preferences
  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Save privacy preferences
      await _preferencesService.setAnalyticsEnabled(_analyticsEnabled);
      await _preferencesService
          .setCrashReportingEnabled(_crashReportingEnabled);
      await _preferencesService.setUsageStatsEnabled(_usageStatsEnabled);

      setState(() {
        _isDirty = false;
        _isSaving = false;
        _successMessage = 'Privacy settings saved successfully';
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
      debugPrint('[PrivacySettings] Error saving settings: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save privacy settings: ${e.toString()}';
      });
    }
  }

  /// Handle analytics toggle change
  void _onAnalyticsChanged(bool value) {
    setState(() {
      _analyticsEnabled = value;
      _isDirty = true;
    });
  }

  /// Handle crash reporting toggle change
  void _onCrashReportingChanged(bool value) {
    setState(() {
      _crashReportingEnabled = value;
      _isDirty = true;
    });
  }

  /// Handle usage statistics toggle change
  void _onUsageStatsChanged(bool value) {
    setState(() {
      _usageStatsEnabled = value;
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

  /// Handle clear data button
  Future<void> _handleClearData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your stored preferences and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isClearing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Clear all stored data
      await _preferencesService.clearAllData();

      setState(() {
        _isClearing = false;
        _successMessage = 'All data cleared successfully';
        _errorMessage = null;
      });

      // Reload settings to show defaults
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadSettings();
        }
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
      debugPrint('[PrivacySettings] Error clearing data: $e');
      setState(() {
        _isClearing = false;
        _errorMessage = 'Failed to clear data: ${e.toString()}';
      });
    }
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

          // Data Collection Section
          SettingsGroup(
            title: 'Data Collection',
            description: 'Control what data is collected about your usage',
            children: [
              SettingsToggle(
                label: 'Analytics',
                description:
                    'Allow us to collect anonymous usage analytics to improve the application',
                value: _analyticsEnabled,
                onChanged: _isSaving ? null : _onAnalyticsChanged,
                enabled: !_isSaving,
              ),
              Divider(
                height: 1,
                color: Colors.grey.shade300,
                indent: 16,
                endIndent: 16,
              ),
              SettingsToggle(
                label: 'Crash Reporting',
                description:
                    'Allow us to collect crash reports to fix bugs and improve stability',
                value: _crashReportingEnabled,
                onChanged: _isSaving ? null : _onCrashReportingChanged,
                enabled: !_isSaving,
              ),
              Divider(
                height: 1,
                color: Colors.grey.shade300,
                indent: 16,
                endIndent: 16,
              ),
              SettingsToggle(
                label: 'Usage Statistics',
                description:
                    'Allow us to collect statistics about feature usage and performance',
                value: _usageStatsEnabled,
                onChanged: _isSaving ? null : _onUsageStatsChanged,
                enabled: !_isSaving,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Data Management Section
          SettingsGroup(
            title: 'Data Management',
            description: 'Manage your stored data and preferences',
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clear All Data',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Permanently delete all stored preferences and settings',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                        ),
                        onPressed: (_isSaving || _isClearing)
                            ? null
                            : _handleClearData,
                        icon: _isClearing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                        label: Text(
                          _isClearing ? 'Clearing...' : 'Clear All Data',
                        ),
                      ),
                    ),
                  ],
                ),
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
                  onPressed: (_isSaving || _isClearing) ? null : _onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: (_isSaving || _isClearing || !_isDirty)
                      ? null
                      : _saveSettings,
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
