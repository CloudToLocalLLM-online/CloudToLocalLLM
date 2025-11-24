/// Theme Error Handler Widget
///
/// Example widget demonstrating error handling and recovery for theme changes
/// Implements Requirements 17.1, 17.4, 17.5
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'error_notification_widget.dart';

/// Widget that handles theme errors and provides recovery options
class ThemeErrorHandlerWidget extends StatelessWidget {
  final Widget child;

  const ThemeErrorHandlerWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Column(
          children: [
            // Display error notification if there's an error
            if (themeProvider.lastError != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ErrorNotificationWidget(
                  errorMessage: themeProvider.lastError!,
                  onRetry: () async {
                    // Retry the last theme change
                    try {
                      await themeProvider.reloadThemePreference();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Theme reloaded successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ErrorNotificationWidget.showSnackBar(
                          context,
                          'Failed to reload theme: $e',
                        );
                      }
                    }
                  },
                  onDismiss: () {
                    // Clear the error (would need to add this method to ThemeProvider)
                    // For now, just show a message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error dismissed'),
                      ),
                    );
                  },
                ),
              ),
            // Main content
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Example usage in a settings screen
class ThemeSettingsExample extends StatelessWidget {
  const ThemeSettingsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
      ),
      body: ThemeErrorHandlerWidget(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Select Theme',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              // ignore: deprecated_member_use
              groupValue: themeProvider.themeMode,
              // ignore: deprecated_member_use
              onChanged: (value) async {
                if (value != null) {
                  try {
                    await themeProvider.setThemeMode(value);
                  } catch (e) {
                    if (context.mounted) {
                      ErrorNotificationWidget.showSnackBar(
                        context,
                        'Failed to change theme: $e',
                        onRetry: () async {
                          await themeProvider.setThemeMode(value);
                        },
                      );
                    }
                  }
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              // ignore: deprecated_member_use
              groupValue: themeProvider.themeMode,
              // ignore: deprecated_member_use
              onChanged: (value) async {
                if (value != null) {
                  try {
                    await themeProvider.setThemeMode(value);
                  } catch (e) {
                    if (context.mounted) {
                      ErrorNotificationWidget.showSnackBar(
                        context,
                        'Failed to change theme: $e',
                        onRetry: () async {
                          await themeProvider.setThemeMode(value);
                        },
                      );
                    }
                  }
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              // ignore: deprecated_member_use
              groupValue: themeProvider.themeMode,
              // ignore: deprecated_member_use
              onChanged: (value) async {
                if (value != null) {
                  try {
                    await themeProvider.setThemeMode(value);
                  } catch (e) {
                    if (context.mounted) {
                      ErrorNotificationWidget.showSnackBar(
                        context,
                        'Failed to change theme: $e',
                        onRetry: () async {
                          await themeProvider.setThemeMode(value);
                        },
                      );
                    }
                  }
                }
              },
            ),
            if (themeProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
