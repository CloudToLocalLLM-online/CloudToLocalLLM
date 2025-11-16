import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Reusable card widget for Admin Center
/// Provides consistent styling and layout for admin content
class AdminCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? elevation;

  const AdminCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.only(
              left: AppTheme.spacingM,
              right: AppTheme.spacingM,
              top: AppTheme.spacingM,
              bottom: AppTheme.spacingS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: theme.textTheme.headlineSmall,
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        Padding(
          padding: padding ??
              EdgeInsets.all(
                title != null ? AppTheme.spacingM : AppTheme.spacingM,
              ),
          child: child,
        ),
      ],
    );

    return Card(
      elevation: elevation ?? 2,
      color: backgroundColor ?? theme.cardTheme.color,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              child: cardContent,
            )
          : cardContent,
    );
  }
}
