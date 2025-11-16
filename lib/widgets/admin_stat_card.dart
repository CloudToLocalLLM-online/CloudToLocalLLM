import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Reusable stat card widget for Admin Center
/// Displays key metrics with icon, title, value, and optional trend
class AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final double? trend;
  final VoidCallback? onTap;

  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? AppTheme.primaryColor;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and trend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: effectiveIconColor.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.borderRadiusS),
                    ),
                    child: Icon(
                      icon,
                      color: effectiveIconColor,
                      size: 24,
                    ),
                  ),
                  if (trend != null) _buildTrendIndicator(theme),
                ],
              ),

              SizedBox(height: AppTheme.spacingM),

              // Title
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textColorLight,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: AppTheme.spacingXS),

              // Value
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),

              // Subtitle
              if (subtitle != null) ...[
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(ThemeData theme) {
    final isPositive = trend! >= 0;
    final trendColor =
        isPositive ? AppTheme.successColor : AppTheme.dangerColor;
    final trendIcon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trendIcon,
            size: 16,
            color: trendColor,
          ),
          SizedBox(width: AppTheme.spacingXS),
          Text(
            '${trend!.abs().toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: trendColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid layout for stat cards
/// Provides responsive grid layout for multiple stat cards
class AdminStatCardGrid extends StatelessWidget {
  final List<AdminStatCard> cards;
  final int crossAxisCount;
  final double childAspectRatio;

  const AdminStatCardGrid({
    super.key,
    required this.cards,
    this.crossAxisCount = 4,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveCrossAxisCount = screenWidth < 768
        ? 1
        : screenWidth < 1024
            ? 2
            : crossAxisCount;

    return GridView.count(
      crossAxisCount: effectiveCrossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: AppTheme.spacingM,
      mainAxisSpacing: AppTheme.spacingM,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: cards,
    );
  }
}
