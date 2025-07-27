import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/installation_step.dart';

/// Widget that displays a single installation step with visual aids and interactive elements
class InstallationStepWidget extends StatefulWidget {
  final InstallationStep step;
  final int stepNumber;
  final bool isCompleted;
  final bool isCurrent;
  final bool isExpanded;
  final VoidCallback? onStepCompleted;
  final VoidCallback? onStepExpanded;
  final Function(String)? onCommandCopy;

  const InstallationStepWidget({
    super.key,
    required this.step,
    required this.stepNumber,
    this.isCompleted = false,
    this.isCurrent = false,
    this.isExpanded = false,
    this.onStepCompleted,
    this.onStepExpanded,
    this.onCommandCopy,
  });

  @override
  State<InstallationStepWidget> createState() => _InstallationStepWidgetState();
}

class _InstallationStepWidgetState extends State<InstallationStepWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

    if (widget.isCurrent) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(InstallationStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _animationController.forward();
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: widget.isCurrent ? 4 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: widget.isCurrent
              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
              : null,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: widget.isExpanded || widget.isCurrent,
            onExpansionChanged: (expanded) {
              if (expanded) {
                widget.onStepExpanded?.call();
              }
            },
            leading: _buildStepIndicator(),
            title: _buildStepTitle(),
            subtitle: _buildStepSubtitle(),
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildStepContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: CircleAvatar(
        backgroundColor: widget.isCompleted
            ? Colors.green
            : widget.isCurrent
            ? Theme.of(context).primaryColor
            : Colors.grey.shade400,
        child: widget.isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(
                '${widget.stepNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildStepTitle() {
    return Text(
      widget.step.title,
      style: TextStyle(
        fontWeight: widget.isCurrent ? FontWeight.bold : FontWeight.w500,
        color: widget.isCompleted
            ? Colors.green.shade700
            : widget.isCurrent
            ? Theme.of(context).primaryColor
            : null,
      ),
    );
  }

  Widget _buildStepSubtitle() {
    if (widget.step.isOptional) {
      return Text(
        'Optional',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStepContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.step.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (widget.step.imageUrl != null) ...[
            const SizedBox(height: 12),
            _buildStepImage(),
          ],
          if (widget.step.commands.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCommandsSection(),
          ],
          if (widget.step.troubleshootingTips.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTroubleshootingSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildStepImage() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          widget.step.imageUrl!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 100,
              color: Colors.grey.shade100,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommandsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commands:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.step.commands.map((command) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        command,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => _copyToClipboard(command),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTroubleshootingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Troubleshooting Tips:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...widget.step.troubleshootingTips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(tip)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Copied to clipboard: $text')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('Failed to copy to clipboard')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
