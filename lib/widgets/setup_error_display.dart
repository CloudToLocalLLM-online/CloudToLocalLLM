import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/setup_error.dart';

/// Widget for displaying setup errors with troubleshooting guidance
///
/// This widget provides:
/// - User-friendly error messages
/// - Actionable troubleshooting steps
/// - Retry and skip options
/// - Support escalation paths
class SetupErrorDisplay extends StatefulWidget {
  final SetupError error;
  final VoidCallback? onRetry;
  final VoidCallback? onSkip;
  final VoidCallback? onGetHelp;
  final bool showTechnicalDetails;
  final bool allowRetry;
  final bool allowSkip;
  final SetupRetryState? retryState;

  const SetupErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.onSkip,
    this.onGetHelp,
    this.showTechnicalDetails = false,
    this.allowRetry = true,
    this.allowSkip = false,
    this.retryState,
  });

  @override
  State<SetupErrorDisplay> createState() => _SetupErrorDisplayState();
}

class _SetupErrorDisplayState extends State<SetupErrorDisplay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showTechnicalDetails = false;
  bool _showTroubleshooting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _showTechnicalDetails = widget.showTechnicalDetails;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildErrorHeader(),
              const SizedBox(height: 16),
              _buildErrorMessage(),
              const SizedBox(height: 16),
              _buildActionableGuidance(),
              if (_showTroubleshooting) ...[
                const SizedBox(height: 16),
                _buildTroubleshootingSteps(),
              ],
              if (_showTechnicalDetails) ...[
                const SizedBox(height: 16),
                _buildTechnicalDetails(),
              ],
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getErrorColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.error.getErrorIcon(),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.error.userFriendlyMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getErrorColor(),
                ),
              ),
              if (widget.error.setupStep != null)
                Text(
                  'Step: ${widget.error.setupStep}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (widget.error.isCritical)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Text(
              'CRITICAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorMessage() {
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
      child: Text(
        widget.error.actionableGuidance,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildActionableGuidance() {
    if (widget.error.troubleshootingSteps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Quick fixes to try:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _showTroubleshooting = !_showTroubleshooting;
                });
              },
              child: Text(_showTroubleshooting ? 'Hide details' : 'Show more'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.error.troubleshootingSteps
            .take(3)
            .map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildTroubleshootingSteps() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Detailed Troubleshooting',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.error.troubleshootingSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.error.troubleshootingSteps.indexOf(step) + 1}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetails() {
    if (widget.error.technicalDetails == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.code,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Technical Details',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.error.technicalDetails!),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Technical details copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy to clipboard',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              widget.error.technicalDetails!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            if (widget.allowRetry && widget.error.isRetryable) ...[
              Expanded(child: _buildRetryButton()),
              const SizedBox(width: 8),
            ],
            if (widget.allowSkip) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onSkip,
                  child: const Text('Skip This Step'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onGetHelp,
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text('Get Help'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showTechnicalDetails = !_showTechnicalDetails;
                });
              },
              icon: Icon(
                _showTechnicalDetails ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(
                '${_showTechnicalDetails ? 'Hide' : 'Show'} technical details',
              ),
            ),
            const Spacer(),
            if (widget.retryState != null &&
                widget.retryState!.attemptCount > 0)
              Text(
                'Attempt ${widget.retryState!.attemptCount}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRetryButton() {
    final canRetry = widget.retryState?.canRetry ?? true;
    final timeUntilRetry = widget.retryState?.timeUntilNextRetry;

    if (!canRetry && timeUntilRetry != null && timeUntilRetry > Duration.zero) {
      return StreamBuilder<int>(
        stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
        builder: (context, snapshot) {
          final remaining = widget.retryState!.timeUntilNextRetry;
          if (remaining == null || remaining <= Duration.zero) {
            return ElevatedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            );
          }

          return ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.timer, size: 16),
            label: Text('Retry in ${remaining.inSeconds}s'),
          );
        },
      );
    }

    return ElevatedButton.icon(
      onPressed: canRetry ? widget.onRetry : null,
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('Retry'),
    );
  }

  Color _getErrorColor() {
    switch (widget.error.getErrorColor()) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'amber':
        return Colors.amber;
      default:
        return Colors.red;
    }
  }
}

/// Compact error display for inline use
class CompactSetupErrorDisplay extends StatelessWidget {
  final SetupError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const CompactSetupErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getErrorColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getErrorColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(error.getErrorIcon(), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.userFriendlyMessage,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  error.actionableGuidance,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (error.isRetryable && onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              tooltip: 'Dismiss',
            ),
          ],
        ],
      ),
    );
  }

  Color _getErrorColor(BuildContext context) {
    switch (error.getErrorColor()) {
      case 'red':
        return Theme.of(context).colorScheme.error;
      case 'orange':
        return Colors.orange;
      case 'amber':
        return Colors.amber;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }
}

/// Error summary widget for analytics display
class SetupErrorSummaryWidget extends StatelessWidget {
  final List<SetupError> errors;
  final VoidCallback? onViewDetails;

  const SetupErrorSummaryWidget({
    super.key,
    required this.errors,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return const SizedBox.shrink();
    }

    final errorsByType = <SetupErrorType, int>{};
    for (final error in errors) {
      errorsByType[error.type] = (errorsByType[error.type] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Setup Issues (${errors.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onViewDetails != null)
                  TextButton(
                    onPressed: onViewDetails,
                    child: const Text('View Details'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...errorsByType.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getColorForErrorType(entry.key, context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getErrorTypeDisplayName(entry.key),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForErrorType(SetupErrorType type, BuildContext context) {
    switch (type) {
      case SetupErrorType.authentication:
        return Colors.red;
      case SetupErrorType.networkError:
        return Colors.orange;
      case SetupErrorType.downloadFailure:
        return Colors.blue;
      case SetupErrorType.containerCreation:
        return Colors.purple;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getErrorTypeDisplayName(SetupErrorType type) {
    switch (type) {
      case SetupErrorType.platformDetection:
        return 'Platform Detection';
      case SetupErrorType.containerCreation:
        return 'Container Creation';
      case SetupErrorType.downloadFailure:
        return 'Download Issues';
      case SetupErrorType.installationFailure:
        return 'Installation Issues';
      case SetupErrorType.tunnelConfiguration:
        return 'Tunnel Configuration';
      case SetupErrorType.connectionValidation:
        return 'Connection Validation';
      case SetupErrorType.authentication:
        return 'Authentication';
      case SetupErrorType.networkError:
        return 'Network Issues';
      case SetupErrorType.serviceTimeout:
        return 'Service Timeout';
      case SetupErrorType.permissionError:
        return 'Permission Issues';
      case SetupErrorType.configurationError:
        return 'Configuration Issues';
      default:
        return 'Unknown Issues';
    }
  }
}
