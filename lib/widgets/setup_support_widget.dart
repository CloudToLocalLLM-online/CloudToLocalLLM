import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/setup_error.dart';
import '../services/setup_troubleshooting_service.dart';

/// Widget for providing support and escalation options
///
/// This widget provides:
/// - Links to documentation and support resources
/// - Escalation paths for complex setup issues
/// - Feedback collection for setup improvements
/// - Context-sensitive help based on current setup step
class SetupSupportWidget extends StatefulWidget {
  final SetupError? error;
  final String? currentStep;
  final String? platform;
  final Map<String, dynamic> context;
  final Function(TroubleshootingFeedback)? onFeedbackSubmitted;

  const SetupSupportWidget({
    super.key,
    this.error,
    this.currentStep,
    this.platform,
    this.context = const {},
    this.onFeedbackSubmitted,
  });

  @override
  State<SetupSupportWidget> createState() => _SetupSupportWidgetState();
}

class _SetupSupportWidgetState extends State<SetupSupportWidget> {
  final SetupTroubleshootingService _troubleshootingService =
      SetupTroubleshootingService();
  List<SupportEscalationOption> _escalationOptions = [];
  List<TroubleshootingGuide> _contextualHelp = [];
  bool _showFeedbackForm = false;
  bool _isSubmittingFeedback = false;

  @override
  void initState() {
    super.initState();
    _loadSupportOptions();
  }

  void _loadSupportOptions() {
    // Get escalation options based on error
    if (widget.error != null) {
      _escalationOptions = _troubleshootingService.getSupportEscalationOptions(
        widget.error!,
      );
    } else {
      // Default escalation options
      _escalationOptions = [
        SupportEscalationOption(
          type: SupportEscalationType.documentation,
          title: 'View Documentation',
          description: 'Check our comprehensive setup guide',
          url: 'https://docs.cloudtolocalllm.com/setup',
          priority: 1,
        ),
        SupportEscalationOption(
          type: SupportEscalationType.faq,
          title: 'Frequently Asked Questions',
          description: 'Find answers to common setup problems',
          url: 'https://docs.cloudtolocalllm.com/faq',
          priority: 2,
        ),
        SupportEscalationOption(
          type: SupportEscalationType.community,
          title: 'Community Support',
          description: 'Get help from the community',
          url: 'https://github.com/cloudtolocalllm/discussions',
          priority: 3,
        ),
      ];
    }

    // Get contextual help
    if (widget.currentStep != null) {
      _contextualHelp = _troubleshootingService.getContextualHelp(
        widget.currentStep!,
        platform: widget.platform,
        context: widget.context,
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            if (_contextualHelp.isNotEmpty) ...[
              _buildContextualHelp(),
              const SizedBox(height: 16),
            ],
            _buildEscalationOptions(),
            const SizedBox(height: 16),
            _buildFeedbackSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Need Help?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const Spacer(),
        if (widget.error != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.error!.type.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContextualHelp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Help for ${_getStepDisplayName(widget.currentStep!)}',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._contextualHelp
            .take(1)
            .map((guide) => _buildTroubleshootingGuide(guide)),
      ],
    );
  }

  Widget _buildTroubleshootingGuide(TroubleshootingGuide guide) {
    return Container(
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
              Icon(
                _getIconForDifficulty(guide.difficulty),
                size: 16,
                color: _getColorForDifficulty(guide.difficulty, context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  guide.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getColorForDifficulty(
                    guide.difficulty,
                    context,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  guide.difficulty.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getColorForDifficulty(guide.difficulty, context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(guide.description, style: Theme.of(context).textTheme.bodySmall),
          if (guide.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...guide.steps
                .take(3)
                .map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${guide.steps.indexOf(step) + 1}.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.action,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildEscalationOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get More Help',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._escalationOptions.map((option) => _buildEscalationOption(option)),
      ],
    );
  }

  Widget _buildEscalationOption(SupportEscalationOption option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _handleEscalationOption(option),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _getIconForEscalationType(option.type),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      option.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Feedback',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _showFeedbackForm = !_showFeedbackForm;
                });
              },
              child: Text(_showFeedbackForm ? 'Cancel' : 'Give Feedback'),
            ),
          ],
        ),
        if (_showFeedbackForm) ...[
          const SizedBox(height: 8),
          _buildFeedbackForm(),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Help us improve the setup experience by sharing your feedback.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeedbackForm() {
    return SetupFeedbackForm(
      error: widget.error,
      currentStep: widget.currentStep,
      isSubmitting: _isSubmittingFeedback,
      onSubmit: _handleFeedbackSubmission,
    );
  }

  void _handleEscalationOption(SupportEscalationOption option) {
    // In a real implementation, you would handle URL opening
    // For now, we'll copy to clipboard and show a message
    Clipboard.setData(ClipboardData(text: option.url));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${option.title} link copied to clipboard'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            // In a real implementation, you would open the URL
            debugPrint('Opening URL: ${option.url}');
          },
        ),
      ),
    );
  }

  Future<void> _handleFeedbackSubmission(
    TroubleshootingFeedback feedback,
  ) async {
    setState(() {
      _isSubmittingFeedback = true;
    });

    try {
      // Submit feedback through the service
      await _troubleshootingService.submitFeedback(feedback);

      // Notify parent widget
      widget.onFeedbackSubmitted?.call(feedback);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _showFeedbackForm = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingFeedback = false;
        });
      }
    }
  }

  IconData _getIconForEscalationType(SupportEscalationType type) {
    switch (type) {
      case SupportEscalationType.documentation:
        return Icons.book_outlined;
      case SupportEscalationType.faq:
        return Icons.quiz_outlined;
      case SupportEscalationType.community:
        return Icons.forum_outlined;
      case SupportEscalationType.directSupport:
        return Icons.support_agent_outlined;
    }
  }

  IconData _getIconForDifficulty(TroubleshootingDifficulty difficulty) {
    switch (difficulty) {
      case TroubleshootingDifficulty.easy:
        return Icons.sentiment_satisfied;
      case TroubleshootingDifficulty.medium:
        return Icons.sentiment_neutral;
      case TroubleshootingDifficulty.hard:
        return Icons.sentiment_dissatisfied;
    }
  }

  Color _getColorForDifficulty(
    TroubleshootingDifficulty difficulty,
    BuildContext context,
  ) {
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

/// Feedback form widget for collecting user feedback
class SetupFeedbackForm extends StatefulWidget {
  final SetupError? error;
  final String? currentStep;
  final bool isSubmitting;
  final Function(TroubleshootingFeedback) onSubmit;

  const SetupFeedbackForm({
    super.key,
    this.error,
    this.currentStep,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  State<SetupFeedbackForm> createState() => _SetupFeedbackFormState();
}

class _SetupFeedbackFormState extends State<SetupFeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  bool _wasHelpful = true;
  final List<String> _helpfulGuides = [];
  final List<String> _unhelpfulGuides = [];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Text(
              'How was your experience?',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Helpful'),
                    value: true,
                    groupValue: _wasHelpful,
                    onChanged: (value) {
                      setState(() {
                        _wasHelpful = value ?? true;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Not Helpful'),
                    value: false,
                    groupValue: _wasHelpful,
                    onChanged: (value) {
                      setState(() {
                        _wasHelpful = value ?? true;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Additional comments (optional)',
                hintText: 'Tell us how we can improve...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: widget.isSubmitting
                      ? null
                      : () {
                          _commentController.clear();
                          setState(() {
                            _wasHelpful = true;
                          });
                        },
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.isSubmitting ? null : _submitFeedback,
                  child: widget.isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitFeedback() {
    if (!_formKey.currentState!.validate()) return;

    final feedback = TroubleshootingFeedback(
      sessionId: 'feedback_${DateTime.now().millisecondsSinceEpoch}',
      wasHelpful: _wasHelpful,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      helpfulGuides: _helpfulGuides,
      unhelpfulGuides: _unhelpfulGuides,
      timestamp: DateTime.now(),
    );

    widget.onSubmit(feedback);
  }
}

/// Compact support widget for inline help
class CompactSetupSupportWidget extends StatelessWidget {
  final String? currentStep;
  final VoidCallback? onGetHelp;

  const CompactSetupSupportWidget({
    super.key,
    this.currentStep,
    this.onGetHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.help_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Need help with ${_getStepDisplayName(currentStep ?? 'setup')}?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          TextButton(onPressed: onGetHelp, child: const Text('Get Help')),
        ],
      ),
    );
  }

  String _getStepDisplayName(String step) {
    switch (step) {
      case 'platform-detection':
        return 'platform detection';
      case 'container-creation':
        return 'container creation';
      case 'download':
        return 'downloading';
      case 'installation':
        return 'installation';
      case 'tunnel-configuration':
        return 'tunnel setup';
      case 'connection-validation':
        return 'connection testing';
      default:
        return step.replaceAll('-', ' ');
    }
  }
}
