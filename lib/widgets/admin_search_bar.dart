import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Reusable search bar widget for Admin Center
/// Provides consistent search input styling with optional filters
class AdminSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String) onChanged;
  final VoidCallback? onClear;
  final List<Widget>? filters;
  final bool showFilters;

  const AdminSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.filters,
    this.showFilters = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search input
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(
              Icons.search,
              color: AppTheme.textColorLight,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: AppTheme.textColorLight,
                    ),
                    onPressed: () {
                      controller.clear();
                      if (onClear != null) {
                        onClear!();
                      } else {
                        onChanged('');
                      }
                    },
                    tooltip: 'Clear search',
                  )
                : null,
            filled: true,
            fillColor: AppTheme.backgroundCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              borderSide: BorderSide(
                color: AppTheme.secondaryColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              borderSide: BorderSide(
                color: AppTheme.secondaryColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),

        // Filters
        if (showFilters && filters != null && filters!.isNotEmpty) ...[
          SizedBox(height: AppTheme.spacingM),
          Wrap(
            spacing: AppTheme.spacingS,
            runSpacing: AppTheme.spacingS,
            children: filters!,
          ),
        ],
      ],
    );
  }
}
