import 'package:flutter/material.dart';
import '../models/setup_error.dart';
import '../services/setup_troubleshooting_service.dart';
import 'setup_error_display.dart';
import 'setup_support_widget.dart';

/// Comprehensive help dialog for setup issues
///
/// This dialog provides:
/// - Error-specific troubleshooting
/// - Context-sensitive help
/// - Support escalation options
/// - Feedback collection
class SetupHelpDialog extends StatefulWidget {
  final SetupError? error;
  final String? currentStep;
  final String? platform;
  final Map<String, dynamic> context;
  final Function(TroubleshootingFeedback)? onFeedbackSubmitted;

  const SetupHelpDialog({
    super.key,
    this.error,
    this.currentStep,
    this.platform,
    this.context = const {},
    this.onFeedbackSubmitted,
  });

  /// Show the help dialog
  static Future<void> show(
    BuildContext context, {
    SetupError? error,
    String? currentStep,
    String? platform,
    Map<String, dynamic> dialogContext = const {},
    Function(TroubleshootingFeedback)? onFeedbackSubmitted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return SetupHelpDialog(
          error: error,
          currentStep: currentStep,
          platform: platform,
          context: dialogContext,
          onFeedbackSubmitted: onFeedbackSubmitted,
        );
      },
    );
  }

  @override
  State<SetupHelpDialog> createState() => _SetupHelpDialogState();
}

class _SetupHelpDialogState extends State<SetupHelpDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final SetupTroubleshootingService _troubleshootingService =
      SetupTroubleshootingService();
  TroubleshootingSession? _troubleshootingSession;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Start troubleshooting session if we have an error
    if (widget.error != null) {
      _troubleshootingSession = _troubleshootingService
          .startTroubleshootingSession(widget.error!, context: widget.context);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();

    // End troubleshooting session
    if (_troubleshootingSession != null) {
      _troubleshootingService.endTroubleshootingSession(
        _troubleshootingSession!.id,
        resolved: false, // We don't know if it was resolved
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabBarView()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.help_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup Help & Support',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (widget.error != null)
                  Text(
                    'Error: ${widget.error!.userFriendlyMessage}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (widget.currentStep != null)
                  Text(
                    'Step: ${_getStepDisplayName(widget.currentStep!)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.build_outlined), text: 'Troubleshooting'),
          Tab(icon: Icon(Icons.support_outlined), text: 'Support'),
          Tab(icon: Icon(Icons.feedback_outlined), text: 'Feedback'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTroubleshootingTab(),
        _buildSupportTab(),
        _buildFeedbackTab(),
      ],
    );
  }

  Widget _buildTroubleshootingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.error != null) ...[
            SetupErrorDisplay(
              error: widget.error!,
              showTechnicalDetails: true,
              allowRetry: false,
              allowSkip: false,
            ),
            const SizedBox(height: 16),
          ],
          _buildTroubleshootingGuides(),
        ],
      ),
    );
  }

  Widget _buildSupportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SetupSupportWidget(
        error: widget.error,
        currentStep: widget.currentStep,
        platform: widget.platform,
        context: widget.context,
        onFeedbackSubmitted: widget.onFeedbackSubmitted,
      ),
    );
  }

  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help Us Improve',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps us improve the setup experience for everyone.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SetupFeedbackForm(
            error: widget.error,
            currentStep: widget.currentStep,
            isSubmitting: false,
            onSubmit: (feedback) {
              widget.onFeedbackSubmitted?.call(feedback);

              // Show success message and close dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: Colors.green,
                ),
              );

              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingGuides() {
    final guides =
        _troubleshootingSession?.guides ??
        _troubleshootingService.getContextualHelp(
          widget.currentStep ?? 'general',
          platform: widget.platform,
          context: widget.context,
        );

    if (guides.isEmpty) {
      return _buildNoGuidesMessage();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Troubleshooting Guides',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...guides.map((guide) => _buildTroubleshootingGuideCard(guide)),
      ],
    );
  }

  Widget _buildTroubleshootingGuideCard(TroubleshootingGuide guide) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(
          _getIconForCategory(guide.category),
          color: _getColorForDifficulty(guide.difficulty),
        ),
        title: Text(
          guide.title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(guide.description),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getColorForDifficulty(
              guide.difficulty,
            ).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            guide.difficulty.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getColorForDifficulty(guide.difficulty),
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...guide.steps.map((step) => _buildTroubleshootingStep(step)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingStep(TroubleshootingStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (step.isOptional)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OPTIONAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_arrow,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.action,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (step.url != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                // In a real implementation, you would open the URL
                debugPrint('Opening URL: ${step.url}');
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Learn More'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoGuidesMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No specific troubleshooting guides available',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try the Support tab for general help resources, or submit feedback to help us improve.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Still need help? Check the Support tab for more resources.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _tabController.animateTo(1); // Switch to Support tab
            },
            child: const Text('Get Support'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(TroubleshootingCategory category) {
    switch (category) {
      case TroubleshootingCategory.general:
        return Icons.help_outline;
      case TroubleshootingCategory.technical:
        return Icons.build_outlined;
      case TroubleshootingCategory.network:
        return Icons.wifi_outlined;
      case TroubleshootingCategory.download:
        return Icons.download_outlined;
      case TroubleshootingCategory.installation:
        return Icons.install_desktop_outlined;
      case TroubleshootingCategory.connection:
        return Icons.link_outlined;
      case TroubleshootingCategory.authentication:
        return Icons.lock_outline;
      case TroubleshootingCategory.service:
        return Icons.cloud_outlined;
    }
  }

  Color _getColorForDifficulty(TroubleshootingDifficulty difficulty) {
    switch (difficulty) {
      case TroubleshootingDifficulty.easy:
        return Colors.green;
      case TroubleshootingDifficulty.medium:
        return Colors.orange;
      case TroubleshootingDifficulty.hard:
        return Colors.red;
    }
  }

  String _getStepDisplayName(String step) {
    switch (step) {
      case 'platform-detection':
        return 'Platform Detection';
      case 'container-creation':
        return 'Container Creation';
      case 'download':
        return 'Download';
      case 'installation':
        return 'Installation';
      case 'tunnel-configuration':
        return 'Tunnel Configuration';
      case 'connection-validation':
        return 'Connection Validation';
      default:
        return step
            .replaceAll('-', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }
}
