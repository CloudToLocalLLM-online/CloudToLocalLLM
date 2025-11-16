/// Settings Input Widgets
///
/// Provides reusable input widgets for settings forms.
library;

import 'package:flutter/material.dart';

/// Settings text input widget
class SettingsTextInput extends StatelessWidget {
  /// Input label
  final String label;

  /// Input description
  final String? description;

  /// Current value
  final String value;

  /// Callback when value changes
  final ValueChanged<String>? onChanged;

  /// Input hint text
  final String? hintText;

  /// Error message
  final String? errorMessage;

  /// Whether the input is enabled
  final bool enabled;

  /// Input type (text, email, number, password, url)
  final TextInputType keyboardType;

  /// Maximum lines for multiline input
  final int? maxLines;

  /// Minimum lines for multiline input
  final int minLines;

  /// Input prefix icon
  final IconData? prefixIcon;

  /// Input suffix icon
  final IconData? suffixIcon;

  /// Callback for suffix icon tap
  final VoidCallback? onSuffixIconTap;

  const SettingsTextInput({
    super.key,
    required this.label,
    required this.value,
    this.description,
    this.onChanged,
    this.hintText,
    this.errorMessage,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = errorMessage != null
        ? '$label. Error: $errorMessage'
        : description != null
            ? '$label. $description'
            : label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Semantics(
        label: semanticLabel,
        textField: true,
        enabled: enabled,
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
            TextField(
              controller: TextEditingController(text: value),
              onChanged: enabled ? onChanged : null,
              enabled: enabled,
              keyboardType: keyboardType,
              maxLines: maxLines,
              minLines: minLines,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
                suffixIcon: suffixIcon != null
                    ? IconButton(
                        icon: Icon(suffixIcon),
                        onPressed: onSuffixIconTap,
                        tooltip: 'Action button',
                      )
                    : null,
                errorText: errorMessage,
                errorMaxLines: 2,
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

/// Settings toggle/switch widget
class SettingsToggle extends StatelessWidget {
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

  const SettingsToggle({
    super.key,
    required this.label,
    required this.value,
    this.description,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = description != null ? '$label. $description' : label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Semantics(
        label: semanticLabel,
        toggled: value,
        enabled: enabled,
        onTap: enabled ? () => onChanged?.call(!value) : null,
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

/// Settings dropdown widget
class SettingsDropdown<T> extends StatelessWidget {
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

  const SettingsDropdown({
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
    final semanticLabel = errorMessage != null
        ? '$label. Error: $errorMessage'
        : description != null
            ? '$label. $description'
            : label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Semantics(
        label: semanticLabel,
        enabled: enabled,
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
                errorMaxLines: 2,
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

/// Settings button widget
class SettingsButton extends StatelessWidget {
  /// Button label
  final String label;

  /// Button description
  final String? description;

  /// Button text
  final String buttonText;

  /// Callback when button is pressed
  final VoidCallback? onPressed;

  /// Whether the button is loading
  final bool isLoading;

  /// Button style (primary, secondary, danger)
  final String style;

  /// Button icon
  final IconData? icon;

  const SettingsButton({
    super.key,
    required this.label,
    required this.buttonText,
    this.description,
    this.onPressed,
    this.isLoading = false,
    this.style = 'primary',
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = description != null ? '$label. $description' : label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Semantics(
        label: semanticLabel,
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
            _buildButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
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
              Text(buttonText),
            ],
          );

    final button = switch (style) {
      'secondary' => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: buttonContent,
        ),
      'danger' => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
          ),
          onPressed: isLoading ? null : onPressed,
          child: buttonContent,
        ),
      _ => FilledButton(
          onPressed: isLoading ? null : onPressed,
          child: buttonContent,
        ),
    };

    return Semantics(
      button: true,
      enabled: !isLoading && onPressed != null,
      onTap: isLoading ? null : onPressed,
      child: button,
    );
  }
}

/// Settings slider widget
class SettingsSlider extends StatelessWidget {
  /// Slider label
  final String label;

  /// Slider description
  final String? description;

  /// Current value
  final double value;

  /// Minimum value
  final double min;

  /// Maximum value
  final double max;

  /// Number of divisions
  final int? divisions;

  /// Callback when value changes
  final ValueChanged<double>? onChanged;

  /// Whether the slider is enabled
  final bool enabled;

  /// Value label builder
  final String Function(double)? valueLabel;

  const SettingsSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.description,
    this.divisions,
    this.onChanged,
    this.enabled = true,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = description != null
        ? '$label. $description. Current value: ${valueLabel?.call(value) ?? value}'
        : '$label. Current value: ${valueLabel?.call(value) ?? value}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Semantics(
        label: semanticLabel,
        slider: true,
        enabled: enabled,
        onIncrease:
            enabled && value < max ? () => onChanged?.call(value + 1) : null,
        onDecrease:
            enabled && value > min ? () => onChanged?.call(value - 1) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                if (valueLabel != null)
                  Text(
                    valueLabel!(value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
              label: valueLabel?.call(value),
            ),
          ],
        ),
      ),
    );
  }
}
