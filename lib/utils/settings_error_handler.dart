/// Settings Error Handler
///
/// Provides error handling utilities for settings operations.
library;

import 'package:flutter/material.dart';

/// Settings error types
enum SettingsErrorType {
  /// Validation error
  validation,

  /// Save operation failed
  saveFailed,

  /// Load operation failed
  loadFailed,

  /// Connection error (e.g., provider connection test failed)
  connectionFailed,

  /// Import/export error
  importExportFailed,

  /// Storage unavailable
  storageUnavailable,

  /// Unknown error
  unknown,
}

/// Settings error with type and message
class SettingsError {
  /// Error type
  final SettingsErrorType type;

  /// Error message
  final String message;

  /// Field-specific errors (for validation errors)
  final Map<String, String>? fieldErrors;

  /// Whether this error is retryable
  final bool isRetryable;

  /// Original exception (if any)
  final Exception? originalException;

  const SettingsError({
    required this.type,
    required this.message,
    this.fieldErrors,
    this.isRetryable = false,
    this.originalException,
  });

  /// Create a validation error
  factory SettingsError.validation(
    String message, {
    Map<String, String>? fieldErrors,
  }) {
    return SettingsError(
      type: SettingsErrorType.validation,
      message: message,
      fieldErrors: fieldErrors,
      isRetryable: false,
    );
  }

  /// Create a save error
  factory SettingsError.saveFailed(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.saveFailed,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create a load error
  factory SettingsError.loadFailed(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.loadFailed,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create a connection error
  factory SettingsError.connectionFailed(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.connectionFailed,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create an import/export error
  factory SettingsError.importExportFailed(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.importExportFailed,
      message: message,
      isRetryable: false,
      originalException: originalException,
    );
  }

  /// Create a storage unavailable error
  factory SettingsError.storageUnavailable(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.storageUnavailable,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create an unknown error
  factory SettingsError.unknown(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.unknown,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  @override
  String toString() => 'SettingsError($type): $message';
}

/// Settings error handler for displaying errors to users
class SettingsErrorHandler {
  /// Get user-friendly error message
  static String getUserMessage(SettingsError error) {
    switch (error.type) {
      case SettingsErrorType.validation:
        return error.message;

      case SettingsErrorType.saveFailed:
        return 'Failed to save settings. ${error.isRetryable ? 'Please try again.' : ''}';

      case SettingsErrorType.loadFailed:
        return 'Failed to load settings. ${error.isRetryable ? 'Please try again.' : ''}';

      case SettingsErrorType.connectionFailed:
        return 'Connection failed. Please check your settings and try again.';

      case SettingsErrorType.importExportFailed:
        return 'Failed to import/export settings. ${error.message}';

      case SettingsErrorType.storageUnavailable:
        return 'Settings storage is unavailable. Your changes will not be saved.';

      case SettingsErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get error icon
  static IconData getErrorIcon(SettingsError error) {
    switch (error.type) {
      case SettingsErrorType.validation:
        return Icons.warning_amber;

      case SettingsErrorType.saveFailed:
      case SettingsErrorType.loadFailed:
        return Icons.error_outline;

      case SettingsErrorType.connectionFailed:
        return Icons.cloud_off;

      case SettingsErrorType.importExportFailed:
        return Icons.file_download_off;

      case SettingsErrorType.storageUnavailable:
        return Icons.storage;

      case SettingsErrorType.unknown:
        return Icons.help_outline;
    }
  }

  /// Get error color
  static Color getErrorColor(SettingsError error) {
    switch (error.type) {
      case SettingsErrorType.validation:
        return Colors.orange;

      case SettingsErrorType.saveFailed:
      case SettingsErrorType.loadFailed:
      case SettingsErrorType.connectionFailed:
      case SettingsErrorType.importExportFailed:
      case SettingsErrorType.storageUnavailable:
      case SettingsErrorType.unknown:
        return Colors.red;
    }
  }

  /// Show error snackbar
  static void showErrorSnackbar(
    BuildContext context,
    SettingsError error, {
    VoidCallback? onRetry,
  }) {
    final message = getUserMessage(error);
    final icon = getErrorIcon(error);
    final color = getErrorColor(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (error.isRetryable && onRetry != null) ...[
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onRetry();
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Show error dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    SettingsError error, {
    VoidCallback? onRetry,
  }) {
    final message = getUserMessage(error);
    final icon = getErrorIcon(error);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (error.isRetryable && onRetry != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Show success message
  static void showSuccessMessage(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
      ),
    );
  }
}
