import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Responsive layout utilities for Admin Center
/// Provides breakpoints and responsive layout helpers
class AdminResponsive {
  // Prevent instantiation
  AdminResponsive._();

  /// Breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  /// Check if screen is mobile size
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if screen is tablet size
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if screen is desktop size
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Get responsive value based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Build responsive layout with different widgets for different screen sizes
  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Get responsive padding
  static EdgeInsets padding(BuildContext context) {
    return EdgeInsets.all(
      value(
        context,
        mobile: AppTheme.spacingM,
        tablet: AppTheme.spacingL,
        desktop: AppTheme.spacingXL,
      ),
    );
  }

  /// Get responsive grid column count
  static int gridColumns(BuildContext context, {int maxColumns = 4}) {
    return value(
      context,
      mobile: 1,
      tablet: 2,
      desktop: maxColumns,
    );
  }

  /// Get responsive sidebar width
  static double sidebarWidth(BuildContext context) {
    return value(
      context,
      mobile: 0, // Hidden on mobile
      tablet: 200,
      desktop: 250,
    );
  }

  /// Get responsive content max width
  static double contentMaxWidth(BuildContext context) {
    return value(
      context,
      mobile: double.infinity,
      tablet: 900,
      desktop: 1200,
    );
  }
}

/// Responsive grid layout widget
class AdminResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxColumns;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;

  const AdminResponsiveGrid({
    super.key,
    required this.children,
    this.maxColumns = 4,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final columns =
        AdminResponsive.gridColumns(context, maxColumns: maxColumns);

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

/// Responsive row/column layout widget
/// Displays children in a row on desktop/tablet, column on mobile
class AdminResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const AdminResponsiveRowColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AdminResponsive.isMobile(context);

    if (isMobile) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: _addSpacing(children, spacing, isVertical: true),
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _addSpacing(children, spacing, isVertical: false),
    );
  }

  List<Widget> _addSpacing(
    List<Widget> children,
    double spacing, {
    required bool isVertical,
  }) {
    if (children.isEmpty) return children;

    final spacedChildren = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(
          isVertical ? SizedBox(height: spacing) : SizedBox(width: spacing),
        );
      }
    }
    return spacedChildren;
  }
}

/// Responsive sidebar layout widget
/// Shows sidebar on desktop/tablet, drawer on mobile
class AdminResponsiveSidebar extends StatelessWidget {
  final Widget sidebar;
  final Widget content;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const AdminResponsiveSidebar({
    super.key,
    required this.sidebar,
    required this.content,
    required this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AdminResponsive.isMobile(context);

    if (isMobile) {
      return Scaffold(
        key: scaffoldKey,
        drawer: Drawer(
          child: sidebar,
        ),
        body: content,
      );
    }

    return Row(
      children: [
        Container(
          width: AdminResponsive.sidebarWidth(context),
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard,
            border: Border(
              right: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
          ),
          child: sidebar,
        ),
        Expanded(child: content),
      ],
    );
  }
}

/// Responsive table wrapper
/// Enables horizontal scrolling on small screens
class AdminResponsiveTable extends StatelessWidget {
  final Widget child;
  final double minWidth;

  const AdminResponsiveTable({
    super.key,
    required this.child,
    this.minWidth = 800,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < minWidth) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: child,
        ),
      );
    }

    return child;
  }
}

/// Responsive dialog wrapper
/// Adjusts dialog size based on screen size
class AdminResponsiveDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const AdminResponsiveDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AdminResponsive.isMobile(context);
    final maxWidth = AdminResponsive.value(
      context,
      mobile: double.infinity,
      tablet: 600,
      desktop: 800,
    );

    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth.toDouble(),
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: EdgeInsets.all(
                  isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                ),
                child: child,
              ),
            ),
            if (actions != null)
              Padding(
                padding: EdgeInsets.all(
                  isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: actions!
                            .map((action) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: AppTheme.spacingS,
                                  ),
                                  child: action,
                                ))
                            .toList(),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!
                            .map((action) => Padding(
                                  padding: EdgeInsets.only(
                                    left: AppTheme.spacingS,
                                  ),
                                  child: action,
                                ))
                            .toList(),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
