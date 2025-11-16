/// Base Settings Widgets
///
/// Provides base classes and utilities for building settings UI components.
library;

import 'package:flutter/material.dart';

/// Base widget for a settings section
abstract class SettingsSectionWidget extends StatelessWidget {
  /// Title of the section
  final String title;

  /// Optional description of the section
  final String? description;

  /// Whether this section is enabled
  final bool enabled;

  const SettingsSectionWidget({
    super.key,
    required this.title,
    this.description,
    this.enabled = true,
  });

  /// Build the content of this section
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Semantics(
          label: title,
          enabled: enabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
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
              buildContent(context),
            ],
          ),
        ),
      ),
    );
  }
}

/// Base widget for a single settings item
abstract class SettingsItemWidget extends StatelessWidget {
  /// Label for the setting
  final String label;

  /// Optional description of the setting
  final String? description;

  /// Whether this item is enabled
  final bool enabled;

  /// Optional error message to display
  final String? errorMessage;

  const SettingsItemWidget({
    super.key,
    required this.label,
    this.description,
    this.enabled = true,
    this.errorMessage,
  });

  /// Build the control widget (e.g., TextField, Switch, Dropdown)
  Widget buildControl(BuildContext context);

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: enabled ? null : Colors.grey.shade600,
                            ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Opacity(
                  opacity: enabled ? 1.0 : 0.6,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: buildControl(context),
                  ),
                ),
              ],
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'Error: $errorMessage',
                child: Text(
                  errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Settings group container with dividers
class SettingsGroup extends StatelessWidget {
  /// Child widgets to display in the group
  final List<Widget> children;

  /// Optional title for the group
  final String? title;

  /// Optional description for the group
  final String? description;

  const SettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title ?? 'Settings group',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
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
          ],
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.grey.shade300,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings form container with save/cancel buttons
class SettingsForm extends StatelessWidget {
  /// Child widgets to display in the form
  final List<Widget> children;

  /// Callback when save button is pressed
  final VoidCallback? onSave;

  /// Callback when cancel button is pressed
  final VoidCallback? onCancel;

  /// Whether the form is currently saving
  final bool isSaving;

  /// Whether the form has unsaved changes
  final bool isDirty;

  /// Optional error message to display
  final String? errorMessage;

  const SettingsForm({
    super.key,
    required this.children,
    this.onSave,
    this.onCancel,
    this.isSaving = false,
    this.isDirty = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: children,
            ),
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: 'Error: $errorMessage',
              enabled: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onCancel != null)
                Semantics(
                  button: true,
                  enabled: !isSaving,
                  onTap: isSaving ? null : onCancel,
                  child: TextButton(
                    onPressed: isSaving ? null : onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              const SizedBox(width: 12),
              if (onSave != null)
                Semantics(
                  button: true,
                  enabled: !isSaving && isDirty,
                  onTap: (isSaving || !isDirty) ? null : onSave,
                  child: FilledButton(
                    onPressed: (isSaving || !isDirty) ? null : onSave,
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
