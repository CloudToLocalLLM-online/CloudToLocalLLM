/// General Settings Category Widget
///
/// Provides theme selection, language selection, and other general application
/// preferences. Integrates with AppTheme for theme application and
/// SettingsPreferenceService for persistence.
library;

import 'package:flutter/material.dart';
import '../../services/settings_preference_service.dart';
import 'settings_category_widgets.dart';
import 'settings_input_widgets.dart';
import 'settings_base.dart';

/// General Settings Category - Theme, Language, and General Preferences
class GeneralSettingsCategory extends SettingsCategoryContentWidget {
  const GeneralSettingsCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _GeneralSettingsCategoryContent();
  }
}

class _GeneralSettingsCategoryContent extends StatefulWidget {
  const _GeneralSettingsCategoryContent();

  @override
  State<_GeneralSettingsCategoryContent> createState() =>
      _GeneralSettingsCategoryContentState();
}

class _GeneralSettingsCategoryContentState
    extends State<_GeneralSettingsCategoryContent> {
  late SettingsPreferenceService _preferencesService;

  // State variables
  String _selectedTheme = 'system'; // 'light', 'dark', 'system'
  String _selectedLanguage = 'en'; // 'en', 'es', 'fr', etc.
  bool _isDirty = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Validation errors
  final Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _preferencesService = SettingsPreferenceService();
    _loadSettings();
  }

  /// Load current settings from preferences
  Future<void> _loadSettings() async {
    try {
      // Load theme and language preferences
      final theme = await _preferencesService.getTheme();
      final language = await _preferencesService.getLanguage();

      setState(() {
        _selectedTheme = theme;
        _selectedLanguage = language;
        _isDirty = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[GeneralSettings] Error loading settings: $e');
      setState(() {
        _errorMessage = 'Failed to load settings';
      });
    }
  }

  /// Validate all settings
  bool _validateSettings() {
    _fieldErrors.clear();

    // Validate theme selection
    if (!['light', 'dark', 'system'].contains(_selectedTheme)) {
      _fieldErrors['theme'] = 'Invalid theme selection';
    }

    // Validate language selection
    if (!['en', 'es', 'fr', 'de', 'ja', 'zh'].contains(_selectedLanguage)) {
      _fieldErrors['language'] = 'Invalid language selection';
    }

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
      // Save theme and language preferences
      await _preferencesService.setTheme(_selectedTheme);
      await _preferencesService.setLanguage(_selectedLanguage);

      // Apply theme change
      _applyThemeChange();

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
      debugPrint('[GeneralSettings] Error saving settings: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save settings: ${e.toString()}';
      });
    }
  }

  /// Apply theme change to the application
  void _applyThemeChange() {
    // The theme is controlled by AppConfig.enableDarkMode
    // In a real implementation, this would update a ThemeProvider
    // For now, we'll just log the change
    debugPrint('[GeneralSettings] Theme changed to: $_selectedTheme');

    // TODO: Implement theme provider integration
    // This would require creating a ThemeProvider service that:
    // 1. Stores the theme preference
    // 2. Notifies listeners when theme changes
    // 3. Updates the MaterialApp.router themeMode property
  }

  /// Handle theme selection change
  void _onThemeChanged(String? newTheme) {
    if (newTheme != null && newTheme != _selectedTheme) {
      setState(() {
        _selectedTheme = newTheme;
        _isDirty = true;
        _fieldErrors.remove('theme');
      });
    }
  }

  /// Handle language selection change
  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage != null && newLanguage != _selectedLanguage) {
      setState(() {
        _selectedLanguage = newLanguage;
        _isDirty = true;
        _fieldErrors.remove('language');
      });
    }
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

          // Theme Selection
          SettingsGroup(
            title: 'Appearance',
            description: 'Customize how the application looks',
            children: [
              SettingsDropdown<String>(
                label: 'Theme',
                description: 'Choose your preferred color scheme',
                value: _selectedTheme,
                items: [
                  DropdownMenuItem(
                    value: 'light',
                    child: Row(
                      children: [
                        Icon(Icons.light_mode, size: 20),
                        const SizedBox(width: 8),
                        const Text('Light'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'dark',
                    child: Row(
                      children: [
                        Icon(Icons.dark_mode, size: 20),
                        const SizedBox(width: 8),
                        const Text('Dark'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'system',
                    child: Row(
                      children: [
                        Icon(Icons.brightness_auto, size: 20),
                        const SizedBox(width: 8),
                        const Text('System'),
                      ],
                    ),
                  ),
                ],
                onChanged: _onThemeChanged,
                errorMessage: _fieldErrors['theme'],
                enabled: !_isSaving,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Language Selection
          SettingsGroup(
            title: 'Language',
            description: 'Select your preferred language',
            children: [
              SettingsDropdown<String>(
                label: 'Language',
                description:
                    'Choose the language for the application interface',
                value: _selectedLanguage,
                items: [
                  DropdownMenuItem(
                    value: 'en',
                    child: Row(
                      children: [
                        const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        const Text('English'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'es',
                    child: Row(
                      children: [
                        const Text('🇪🇸', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        const Text('Español'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'fr',
                    child: Row(
                      children: [
                        const Text('🇫🇷', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        const Text('Français'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'de',
                    child: Row(
                      children: [
                        const Text('🇩🇪', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        const Text('Deutsch'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'ja',
                    child: Row(
                      children: [
                        const Text('🇯🇵', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        const Text('日本語'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'zh',
                    child: Row(
                      children: [
                        const Text('🇨🇳', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        const Text('中文'),
                      ],
                    ),
                  ),
                ],
                onChanged: _onLanguageChanged,
                errorMessage: _fieldErrors['language'],
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
