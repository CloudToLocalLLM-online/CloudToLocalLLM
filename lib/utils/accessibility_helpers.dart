/// Accessibility Helpers
///
/// Provides utilities for building accessible UI components with proper
/// ARIA labels, semantic HTML, keyboard navigation, and screen reader support.
library;

import 'package:flutter/material.dart';

/// Accessibility utilities for building accessible UI
class AccessibilityHelpers {
  /// Minimum contrast ratio for WCAG AA compliance (4.5:1)
  static const double minContrastRatioAA = 4.5;

  /// Minimum contrast ratio for WCAG AAA compliance (7:1)
  static const double minContrastRatioAAA = 7.0;

  /// Get semantic label for a widget
  static String getSemanticLabel(String label, {String? description}) {
    if (description != null && description.isNotEmpty) {
      return '$label. $description';
    }
    return label;
  }

  /// Check if a color combination meets WCAG AA contrast requirements
  static bool meetsContrastRequirement(Color foreground, Color background) {
    final fgLuminance = _getRelativeLuminance(foreground);
    final bgLuminance = _getRelativeLuminance(background);

    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

    final contrast = (lighter + 0.05) / (darker + 0.05);
    return contrast >= minContrastRatioAA;
  }

  /// Calculate relative luminance for contrast calculation
  static double _getRelativeLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize color component for luminance calculation
  static double _linearize(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return ((component + 0.055) / 1.055) * ((component + 0.055) / 1.055);
  }
}

/// Accessible text input widget with proper labels and keyboard support
class AccessibleTextInput extends StatefulWidget {
  /// Input label (required for accessibility)
  final String label;

  /// Input description for screen readers
  final String? description;

  /// Current value
  final String value;

  /// Callback when value changes
  final ValueChanged<String>? onChanged;

  /// Callback when submitted
  final VoidCallback? onSubmitted;

  /// Input hint text
  final String? hintText;

  /// Error message
  final String? errorMessage;

  /// Whether the input is enabled
  final bool enabled;

  /// Input type
  final TextInputType keyboardType;

  /// Maximum lines
  final int? maxLines;

  /// Minimum lines
  final int minLines;

  /// Prefix icon
  final IconData? prefixIcon;

  /// Suffix icon
  final IconData? suffixIcon;

  /// Callback for suffix icon tap
  final VoidCallback? onSuffixIconTap;

  /// Whether to show character count
  final bool showCharacterCount;

  /// Maximum characters
  final int? maxLength;

  const AccessibleTextInput({
    super.key,
    required this.label,
    required this.value,
    this.description,
    this.onChanged,
    this.onSubmitted,
    this.hintText,
    this.errorMessage,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.showCharacterCount = false,
    this.maxLength,
  });

  @override
  State<AccessibleTextInput> createState() => _AccessibleTextInputState();
}

class _AccessibleTextInputState extends State<AccessibleTextInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(AccessibleTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final semanticLabel = AccessibilityHelpers.getSemanticLabel(
      widget.label,
      description: widget.description,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with required indicator if needed
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          // Description for additional context
          if (widget.description != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ),
          ],
          // Text field with accessibility features
          Semantics(
            label: semanticLabel,
            enabled: widget.enabled,
            textField: true,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: widget.enabled ? widget.onChanged : null,
              onSubmitted:
                  widget.enabled ? (_) => widget.onSubmitted?.call() : null,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              maxLength: widget.maxLength,
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon:
                    widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
                suffixIcon: widget.suffixIcon != null
                    ? IconButton(
                        icon: Icon(widget.suffixIcon),
                        onPressed: widget.onSuffixIconTap,
                        tooltip: 'Action button',
                      )
                    : null,
                errorText: widget.errorMessage,
                errorMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                counterText: widget.showCharacterCount ? null : '',
              ),
            ),
          ),
          // Error message with proper styling
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'Error: ${widget.errorMessage}',
              child: Text(
                widget.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// Accessible toggle/switch widget with proper labels
class AccessibleToggle extends StatelessWidget {
  /// Toggle label
  final String label;

  /// Toggle description
  final String? description;

  /// Current value
  final bool value;

  /// Callback when value changes
  final ValueChanged<bool>? onChanged;

  /// Whether the toggle is enabled
  final bool enabled;

  const AccessibleToggle({
    super.key,
    required this.label,
    required this.value,
    this.description,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = AccessibilityHelpers.getSemanticLabel(
      label,
      description: description,
    );

    return Semantics(
      label: semanticLabel,
      enabled: enabled,
      toggled: value,
      onTap: enabled ? () => onChanged?.call(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Accessible button with proper keyboard support
class AccessibleButton extends StatelessWidget {
  /// Button label
  final String label;

  /// Button description
  final String? description;

  /// Callback when pressed
  final VoidCallback? onPressed;

  /// Whether the button is loading
  final bool isLoading;

  /// Button icon
  final IconData? icon;

  /// Button style
  final String style;

  const AccessibleButton({
    super.key,
    required this.label,
    this.description,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.style = 'primary',
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = AccessibilityHelpers.getSemanticLabel(
      label,
      description: description,
    );

    final buttonContent = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    return Semantics(
      label: semanticLabel,
      enabled: !isLoading && onPressed != null,
      button: true,
      onTap: isLoading ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildButton(context, buttonContent),
      ),
    );
  }

  Widget _buildButton(BuildContext context, Widget content) {
    switch (style) {
      case 'secondary':
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
      case 'danger':
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
          ),
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
      default:
        return FilledButton(
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
    }
  }
}

/// Accessible dropdown widget
class AccessibleDropdown<T> extends StatelessWidget {
  /// Dropdown label
  final String label;

  /// Dropdown description
  final String? description;

  /// Current value
  final T? value;

  /// Available options
  final List<DropdownMenuItem<T>> items;

  /// Callback when value changes
  final ValueChanged<T?>? onChanged;

  /// Error message
  final String? errorMessage;

  /// Whether the dropdown is enabled
  final bool enabled;

  /// Hint text
  final String? hint;

  const AccessibleDropdown({
    super.key,
    required this.label,
    required this.items,
    this.description,
    this.value,
    this.onChanged,
    this.errorMessage,
    this.enabled = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = AccessibilityHelpers.getSemanticLabel(
      label,
      description: description,
    );

    return Semantics(
      label: semanticLabel,
      enabled: enabled,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<T>(
              initialValue: value,
              items: items,
              onChanged: enabled ? onChanged : null,
              decoration: InputDecoration(
                hintText: hint,
                errorText: errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
