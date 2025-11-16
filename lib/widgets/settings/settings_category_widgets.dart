/// Settings Category Widgets
///
/// Provides base classes for implementing specific settings categories.
library;

import 'package:flutter/material.dart';

/// Base widget for a settings category content
abstract class SettingsCategoryContentWidget extends StatelessWidget {
  /// Category ID
  final String categoryId;

  /// Whether the category is currently active
  final bool isActive;

  /// Callback when settings are modified
  final VoidCallback? onSettingsChanged;

  const SettingsCategoryContentWidget({
    super.key,
    required this.categoryId,
    this.isActive = true,
    this.onSettingsChanged,
  });

  /// Build the category content
  Widget buildCategoryContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: buildCategoryContent(context),
    );
  }
}

/// Settings category list item widget
class SettingsCategoryListItem extends StatelessWidget {
  /// Category ID
  final String categoryId;

  /// Category title
  final String title;

  /// Category icon
  final IconData icon;

  /// Category description
  final String? description;

  /// Whether this category is currently selected
  final bool isSelected;

  /// Callback when category is tapped
  final VoidCallback? onTap;

  const SettingsCategoryListItem({
    super.key,
    required this.categoryId,
    required this.title,
    required this.icon,
    this.description,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.blue.shade50 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border(
                    left: BorderSide(
                      color: Colors.blue.shade600,
                      width: 4,
                    ),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color:
                      isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? Colors.blue.shade600 : null,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings search result item
class SettingsSearchResultItem extends StatelessWidget {
  /// Category ID where the result was found
  final String categoryId;

  /// Category title
  final String categoryTitle;

  /// Setting name/label
  final String settingLabel;

  /// Setting description
  final String? settingDescription;

  /// Callback when result is tapped
  final VoidCallback? onTap;

  const SettingsSearchResultItem({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    required this.settingLabel,
    this.settingDescription,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      settingLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      categoryTitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.blue.shade600,
                          ),
                    ),
                  ),
                ],
              ),
              if (settingDescription != null) ...[
                const SizedBox(height: 4),
                Text(
                  settingDescription!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings validation error display
class SettingsValidationError extends StatelessWidget {
  /// Error message
  final String message;

  /// Optional field name that has the error
  final String? fieldName;

  /// Callback to dismiss the error
  final VoidCallback? onDismiss;

  const SettingsValidationError({
    super.key,
    required this.message,
    this.fieldName,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fieldName != null)
                  Text(
                    fieldName!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                Text(
                  message,
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, color: Colors.red.shade600),
              onPressed: onDismiss,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

/// Settings success message display
class SettingsSuccessMessage extends StatefulWidget {
  /// Success message
  final String message;

  /// Duration to show the message
  final Duration duration;

  /// Callback when message is dismissed
  final VoidCallback? onDismiss;

  const SettingsSuccessMessage({
    super.key,
    required this.message,
    this.duration = const Duration(seconds: 2),
    this.onDismiss,
  });

  @override
  State<SettingsSuccessMessage> createState() => _SettingsSuccessMessageState();
}

class _SettingsSuccessMessageState extends State<SettingsSuccessMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss?.call();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(color: Colors.green.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
