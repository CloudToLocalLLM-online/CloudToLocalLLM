import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

/// Accessible button with proper focus management and keyboard support
class AccessibleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? tooltip;
  final ButtonStyle? style;
  final bool autofocus;
  final FocusNode? focusNode;

  const AccessibleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.tooltip,
    this.style,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<AccessibleButton> createState() => _AccessibleButtonState();
}

class _AccessibleButtonState extends State<AccessibleButton> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      enabled: widget.onPressed != null,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onPressed?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: _isFocused
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                )
              : null,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: widget.style,
            focusNode: _focusNode,
            child: widget.tooltip != null
                ? Tooltip(message: widget.tooltip!, child: widget.child)
                : widget.child,
          ),
        ),
      ),
    );
  }
}

/// Accessible card with proper semantic structure
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool isInteractive;

  const AccessibleCard({
    super.key,
    required this.child,
    this.semanticLabel,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.isInteractive = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: backgroundColor,
      child: Padding(
        padding: padding ?? EdgeInsets.all(AppTheme.spacingM),
        child: child,
      ),
    );

    if (isInteractive && onTap != null) {
      return Semantics(
        label: semanticLabel,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          child: card,
        ),
      );
    }

    return Semantics(label: semanticLabel, child: card);
  }
}

/// Accessible form field with proper labeling and error handling
class AccessibleFormField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool required;
  final String? semanticLabel;

  const AccessibleFormField({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.required = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? '$label${required ? ', required' : ''}',
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textColor,
                fontWeight: FontWeight.w500,
              ),
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: AppTheme.dangerColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacingXS),
          TextFormField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
            ),
          ),
          if (errorText != null) ...[
            SizedBox(height: AppTheme.spacingXS),
            Semantics(
              label: 'Error: $errorText',
              liveRegion: true,
              child: Text(
                errorText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.dangerColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Accessible step indicator for wizards
class AccessibleStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;
  final bool isHorizontal;

  const AccessibleStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
    this.isHorizontal = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step indicator: Step ${currentStep + 1} of $totalSteps',
      child: isHorizontal
          ? _buildHorizontalIndicator(context)
          : _buildVerticalIndicator(context),
    );
  }

  Widget _buildHorizontalIndicator(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Semantics(
                      label:
                          '${stepLabels[index]}: ${isCompleted
                              ? 'completed'
                              : isActive
                              ? 'current'
                              : 'upcoming'}',
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? AppTheme.successColor
                              : isActive
                              ? AppTheme.primaryColor
                              : AppTheme.backgroundMain,
                          border: Border.all(
                            color: isActive
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isCompleted
                              ? Icon(Icons.check, color: Colors.white, size: 16)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : AppTheme.textColorLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      stepLabels[index],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? AppTheme.primaryColor
                            : isCompleted
                            ? AppTheme.successColor
                            : AppTheme.textColorLight,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (index < totalSteps - 1)
                Container(
                  width: 24,
                  height: 2,
                  color: isCompleted
                      ? AppTheme.successColor
                      : AppTheme.borderColor,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildVerticalIndicator(BuildContext context) {
    return Column(
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;

        return Column(
          children: [
            Row(
              children: [
                Semantics(
                  label:
                      '${stepLabels[index]}: ${isCompleted
                          ? 'completed'
                          : isActive
                          ? 'current'
                          : 'upcoming'}',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppTheme.successColor
                          : isActive
                          ? AppTheme.primaryColor
                          : AppTheme.backgroundMain,
                      border: Border.all(
                        color: isActive
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(Icons.check, color: Colors.white, size: 16)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : AppTheme.textColorLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Text(
                    stepLabels[index],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isActive
                          ? AppTheme.primaryColor
                          : isCompleted
                          ? AppTheme.successColor
                          : AppTheme.textColorLight,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            if (index < totalSteps - 1) ...[
              SizedBox(height: AppTheme.spacingS),
              Container(
                margin: EdgeInsets.only(left: 16),
                width: 2,
                height: 24,
                color: isCompleted
                    ? AppTheme.successColor
                    : AppTheme.borderColor,
              ),
              SizedBox(height: AppTheme.spacingS),
            ],
          ],
        );
      }),
    );
  }
}

/// Accessible alert/notification component
class AccessibleAlert extends StatelessWidget {
  final String title;
  final String message;
  final AlertType type;
  final VoidCallback? onDismiss;
  final List<Widget>? actions;

  const AccessibleAlert({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.onDismiss,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getAlertConfig(type);

    return Semantics(
      label: '${config.semanticPrefix}: $title. $message',
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          border: Border.all(color: config.borderColor, width: 1),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(config.icon, color: config.iconColor, size: 24),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: config.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  Semantics(
                    label: 'Dismiss alert',
                    button: true,
                    child: IconButton(
                      onPressed: onDismiss,
                      icon: Icon(
                        Icons.close,
                        color: config.textColor,
                        size: 20,
                      ),
                      tooltip: 'Dismiss',
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: config.textColor),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              SizedBox(height: AppTheme.spacingM),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
            ],
          ],
        ),
      ),
    );
  }

  _AlertConfig _getAlertConfig(AlertType type) {
    switch (type) {
      case AlertType.success:
        return _AlertConfig(
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
          borderColor: AppTheme.successColor.withValues(alpha: 0.3),
          iconColor: AppTheme.successColor,
          textColor: AppTheme.successColor.withValues(alpha: 0.9),
          icon: Icons.check_circle_outline,
          semanticPrefix: 'Success',
        );
      case AlertType.warning:
        return _AlertConfig(
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.1),
          borderColor: AppTheme.warningColor.withValues(alpha: 0.3),
          iconColor: AppTheme.warningColor,
          textColor: AppTheme.warningColor.withValues(alpha: 0.9),
          icon: Icons.warning_outlined,
          semanticPrefix: 'Warning',
        );
      case AlertType.error:
        return _AlertConfig(
          backgroundColor: AppTheme.dangerColor.withValues(alpha: 0.1),
          borderColor: AppTheme.dangerColor.withValues(alpha: 0.3),
          iconColor: AppTheme.dangerColor,
          textColor: AppTheme.dangerColor.withValues(alpha: 0.9),
          icon: Icons.error_outline,
          semanticPrefix: 'Error',
        );
      case AlertType.info:
        return _AlertConfig(
          backgroundColor: AppTheme.infoColor.withValues(alpha: 0.1),
          borderColor: AppTheme.infoColor.withValues(alpha: 0.3),
          iconColor: AppTheme.infoColor,
          textColor: AppTheme.infoColor.withValues(alpha: 0.9),
          icon: Icons.info_outline,
          semanticPrefix: 'Information',
        );
    }
  }
}

class _AlertConfig {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;
  final String semanticPrefix;

  _AlertConfig({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
    required this.semanticPrefix,
  });
}

enum AlertType { success, warning, error, info }

/// Keyboard navigation helper
class KeyboardNavigationHelper {
  static Widget wrapWithKeyboardNavigation({
    required Widget child,
    required List<FocusNode> focusNodes,
    bool trapFocus = false,
  }) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.tab) {
            final currentIndex = focusNodes.indexWhere((node) => node.hasFocus);
            if (currentIndex != -1) {
              final nextIndex = HardwareKeyboard.instance.isShiftPressed
                  ? (currentIndex - 1) % focusNodes.length
                  : (currentIndex + 1) % focusNodes.length;

              focusNodes[nextIndex].requestFocus();
              return KeyEventResult.handled;
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.escape && trapFocus) {
            // Handle escape key for modal dialogs
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
