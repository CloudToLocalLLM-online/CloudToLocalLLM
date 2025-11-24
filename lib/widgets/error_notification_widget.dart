/// Error Notification Widget
///
/// Displays error messages clearly with recovery options
/// Implements Requirement 17.4: Display error messages clearly
library;

import 'package:flutter/material.dart';

/// Widget for displaying error notifications with recovery options
class ErrorNotificationWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final IconData icon;
  final Color? backgroundColor;

  const ErrorNotificationWidget({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.onDismiss,
    this.icon = Icons.error_outline,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.errorContainer;
    final textColor = theme.colorScheme.onErrorContainer;

    return Material(
      color: bgColor,
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    errorMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                ),
                child: const Text('Retry'),
              ),
            ],
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, color: textColor),
                onPressed: onDismiss,
                tooltip: 'Dismiss',
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show error notification as a SnackBar
  static void showSnackBar(
    BuildContext context,
    String errorMessage, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(errorMessage),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show error notification as a banner at the top
  static Widget banner(
    String errorMessage, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return ErrorNotificationWidget(
      errorMessage: errorMessage,
      onRetry: onRetry,
      onDismiss: onDismiss,
    );
  }
}
