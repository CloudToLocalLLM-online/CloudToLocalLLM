import 'package:flutter/material.dart';
import '../models/setup_error.dart';
import '../services/setup_troubleshooting_service.dart';
import '../widgets/setup_help_dialog.dart';
import '../widgets/setup_error_display.dart';
import '../widgets/setup_support_widget.dart';

/// Utility service for easy access to setup help and troubleshooting features
///
/// This service provides:
/// - Easy access to help dialogs and widgets
/// - Centralized error handling and display
/// - Quick troubleshooting and support integration
/// - Consistent help experience across the app
class SetupHelpService {
  static final SetupHelpService _instance = SetupHelpService._internal();
  factory SetupHelpService() => _instance;
  SetupHelpService._internal();

  final SetupTroubleshootingService _troubleshootingService =
      SetupTroubleshootingService();

  /// Show comprehensive help dialog
  static Future<void> showHelpDialog(
    BuildContext context, {
    SetupError? error,
    String? currentStep,
    String? platform,
    Map<String, dynamic> dialogContext = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return SetupHelpDialog.show(
      context,
      error: error,
      currentStep: currentStep,
      platform: platform,
      dialogContext: dialogContext,
      onFeedbackSubmitted: onFeedbackSubmitted,
    );
  }

  /// Show error-specific help dialog
  static Future<void> showErrorHelp(
    BuildContext context,
    SetupError error, {
    Map<String, dynamic> dialogContext = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return showHelpDialog(
      context,
      error: error,
      currentStep: error.setupStep,
      dialogContext: dialogContext,
      onFeedbackSubmitted: onFeedbackSubmitted,
    );
  }

  /// Show step-specific help dialog
  static Future<void> showStepHelp(
    BuildContext context,
    String stepName, {
    String? platform,
    Map<String, dynamic> dialogContext = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return showHelpDialog(
      context,
      currentStep: stepName,
      platform: platform,
      dialogContext: dialogContext,
      onFeedbackSubmitted: onFeedbackSubmitted,
    );
  }

  /// Show error as a snackbar with help option
  static void showErrorSnackBar(
    BuildContext context,
    SetupError error, {
    Duration duration = const Duration(seconds: 8),
    VoidCallback? onRetry,
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(error.getErrorIcon()),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error.userFriendlyMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    error.actionableGuidance,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: duration,
        action: SnackBarAction(
          label: 'Help',
          onPressed: () {
            showErrorHelp(
              context,
              error,
              onFeedbackSubmitted: onFeedbackSubmitted,
            );
          },
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _getSnackBarColor(error),
      ),
    );
  }

  /// Show error as a bottom sheet
  static void showErrorBottomSheet(
    BuildContext context,
    SetupError error, {
    VoidCallback? onRetry,
    VoidCallback? onSkip,
    SetupRetryState? retryState,
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: SetupErrorDisplay(
                        error: error,
                        onRetry: onRetry,
                        onSkip: onSkip,
                        onGetHelp: () {
                          Navigator.of(context).pop();
                          showErrorHelp(
                            context,
                            error,
                            onFeedbackSubmitted: onFeedbackSubmitted,
                          );
                        },
                        showTechnicalDetails: true,
                        allowRetry: onRetry != null,
                        allowSkip: onSkip != null,
                        retryState: retryState,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show compact error display
  static Widget buildCompactErrorDisplay(
    SetupError error, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return CompactSetupErrorDisplay(
      error: error,
      onRetry: onRetry,
      onDismiss: onDismiss,
    );
  }

  /// Show support widget
  static Widget buildSupportWidget({
    SetupError? error,
    String? currentStep,
    String? platform,
    Map<String, dynamic> context = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return SetupSupportWidget(
      error: error,
      currentStep: currentStep,
      platform: platform,
      context: context,
      onFeedbackSubmitted: onFeedbackSubmitted,
    );
  }

  /// Show compact support widget
  static Widget buildCompactSupportWidget({
    String? currentStep,
    required BuildContext context,
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return CompactSetupSupportWidget(
      currentStep: currentStep,
      onGetHelp: () {
        showStepHelp(
          context,
          currentStep ?? 'general',
          onFeedbackSubmitted: onFeedbackSubmitted,
        );
      },
    );
  }

  /// Get troubleshooting guides for a step
  static List<TroubleshootingGuide> getTroubleshootingGuides(
    String stepName, {
    String? platform,
    Map<String, dynamic> context = const {},
  }) {
    final service = SetupHelpService()._troubleshootingService;
    return service.getContextualHelp(
      stepName,
      platform: platform,
      context: context,
    );
  }

  /// Get support escalation options for an error
  static List<SupportEscalationOption> getSupportOptions(SetupError error) {
    final service = SetupHelpService()._troubleshootingService;
    return service.getSupportEscalationOptions(error);
  }

  /// Create a help button widget
  static Widget buildHelpButton(
    BuildContext context, {
    SetupError? error,
    String? currentStep,
    String? platform,
    Map<String, dynamic> helpContext = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
    IconData icon = Icons.help_outline,
    String? tooltip,
    bool isFloating = false,
  }) {
    void onPressed() {
      if (error != null) {
        showErrorHelp(
          context,
          error,
          dialogContext: helpContext,
          onFeedbackSubmitted: onFeedbackSubmitted,
        );
      } else {
        showStepHelp(
          context,
          currentStep ?? 'general',
          platform: platform,
          dialogContext: helpContext,
          onFeedbackSubmitted: onFeedbackSubmitted,
        );
      }
    }

    if (isFloating) {
      return FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip ?? 'Get Help',
        child: Icon(icon),
      );
    }

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip ?? 'Get Help',
    );
  }

  /// Create a help text button widget
  static Widget buildHelpTextButton(
    BuildContext context, {
    SetupError? error,
    String? currentStep,
    String? platform,
    Map<String, dynamic> helpContext = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
    String label = 'Get Help',
    IconData? icon,
  }) {
    void onPressed() {
      if (error != null) {
        showErrorHelp(
          context,
          error,
          dialogContext: helpContext,
          onFeedbackSubmitted: onFeedbackSubmitted,
        );
      } else {
        showStepHelp(
          context,
          currentStep ?? 'general',
          platform: platform,
          dialogContext: helpContext,
          onFeedbackSubmitted: onFeedbackSubmitted,
        );
      }
    }

    if (icon != null) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return TextButton(onPressed: onPressed, child: Text(label));
  }

  /// Show a quick help tooltip
  static void showHelpTooltip(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove the tooltip after the specified duration
    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  // Private helper methods

  static Color _getSnackBarColor(SetupError error) {
    switch (error.getErrorColor()) {
      case 'red':
        return Colors.red.shade700;
      case 'orange':
        return Colors.orange.shade700;
      case 'amber':
        return Colors.amber.shade700;
      default:
        return Colors.red.shade700;
    }
  }
}

/// Extension methods for easy access to help features
extension SetupHelpExtensions on BuildContext {
  /// Show help dialog for current context
  Future<void> showSetupHelp({
    SetupError? error,
    String? currentStep,
    String? platform,
    Map<String, dynamic> context = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return SetupHelpService.showHelpDialog(
      this,
      error: error,
      currentStep: currentStep,
      platform: platform,
      dialogContext: context,
      onFeedbackSubmitted: onFeedbackSubmitted,
    );
  }

  /// Show error help for current context
  Future<void> showSetupErrorHelp(
    SetupError error, {
    Map<String, dynamic> context = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return SetupHelpService.showErrorHelp(
      this,
      error,
      dialogContext: context,
      onFeedbackSubmitted: onFeedbackSubmitted,
    );
  }

  /// Show step help for current context
  Future<void> showSetupStepHelp(
    String stepName, {
    String? platform,
    Map<String, dynamic> context = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return SetupHelpService.showStepHelp(
      this,
      stepName,
      platform: platform,
      dialogContext: context,
      onFeedbackSubmitted: onFeedbackSubmitted,
    );
  }

  /// Show error as snackbar
  void showSetupErrorSnackBar(
    SetupError error, {
    Duration duration = const Duration(seconds: 8),
    VoidCallback? onRetry,
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    SetupHelpService.showErrorSnackBar(
      this,
      error,
      duration: duration,
      onRetry: onRetry,
      onFeedbackSubmitted: onFeedbackSubmitted,
    );
  }

  /// Show help tooltip
  void showSetupHelpTooltip(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    SetupHelpService.showHelpTooltip(this, message, duration: duration);
  }
}
