/// Responsive Screen Wrapper
///
/// Provides a wrapper for screens that need responsive layout support
/// with automatic reflow and data preservation.
library;

import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';

/// Responsive screen wrapper that handles layout reflow
class ResponsiveScreenWrapper extends StatefulWidget {
  /// Mobile layout builder (< 600px)
  final Widget Function(BuildContext context)? mobileBuilder;

  /// Tablet layout builder (600-1024px)
  final Widget Function(BuildContext context)? tabletBuilder;

  /// Desktop layout builder (> 1024px)
  final Widget Function(BuildContext context)? desktopBuilder;

  /// Unified builder that receives screen size
  final Widget Function(BuildContext context, ScreenSize screenSize)?
      unifiedBuilder;

  /// Child widget (if using default responsive behavior)
  final Widget? child;

  /// Whether to preserve state during reflow
  final bool preserveState;

  /// Callback when screen size changes
  final void Function(ScreenSize oldSize, ScreenSize newSize)?
      onScreenSizeChanged;

  const ResponsiveScreenWrapper({
    super.key,
    this.mobileBuilder,
    this.tabletBuilder,
    this.desktopBuilder,
    this.unifiedBuilder,
    this.child,
    this.preserveState = true,
    this.onScreenSizeChanged,
  }) : assert(
          unifiedBuilder != null ||
              (mobileBuilder != null &&
                  tabletBuilder != null &&
                  desktopBuilder != null) ||
              child != null,
          'Either provide unifiedBuilder, all three builders, or a child',
        );

  @override
  State<ResponsiveScreenWrapper> createState() =>
      _ResponsiveScreenWrapperState();
}

class _ResponsiveScreenWrapperState extends State<ResponsiveScreenWrapper> {
  ScreenSize? _previousScreenSize;
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentScreenSize = ResponsiveLayout.getScreenSize(context);

        // Notify about screen size changes
        if (_previousScreenSize != null &&
            _previousScreenSize != currentScreenSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onScreenSizeChanged?.call(
              _previousScreenSize!,
              currentScreenSize,
            );
          });
        }
        _previousScreenSize = currentScreenSize;

        // Build content based on screen size
        Widget content;

        if (widget.unifiedBuilder != null) {
          content = widget.unifiedBuilder!(context, currentScreenSize);
        } else if (widget.child != null) {
          content = widget.child!;
        } else {
          content = _buildForScreenSize(context, currentScreenSize);
        }

        // Wrap with AnimatedSwitcher for smooth transitions
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: KeyedSubtree(
            key: widget.preserveState
                ? ValueKey(currentScreenSize)
                : _contentKey,
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildForScreenSize(BuildContext context, ScreenSize screenSize) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return widget.mobileBuilder!(context);
      case ScreenSize.tablet:
        return widget.tabletBuilder!(context);
      case ScreenSize.desktop:
        return widget.desktopBuilder!(context);
    }
  }
}

/// Responsive grid that adapts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  /// Children widgets
  final List<Widget> children;

  /// Spacing between items
  final double spacing;

  /// Aspect ratio for grid items
  final double childAspectRatio;

  /// Custom column count per screen size
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.childAspectRatio = 1.0,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);
    final columnCount = _getColumnCount(screenSize);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  int _getColumnCount(ScreenSize screenSize) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return mobileColumns ?? 1;
      case ScreenSize.tablet:
        return tabletColumns ?? 2;
      case ScreenSize.desktop:
        return desktopColumns ?? 3;
    }
  }
}

/// Responsive row/column that switches based on screen size
class ResponsiveRowColumn extends StatelessWidget {
  /// Children widgets
  final List<Widget> children;

  /// Main axis alignment
  final MainAxisAlignment mainAxisAlignment;

  /// Cross axis alignment
  final CrossAxisAlignment crossAxisAlignment;

  /// Spacing between children
  final double spacing;

  /// Force column layout on mobile
  final bool columnOnMobile;

  /// Force column layout on tablet
  final bool columnOnTablet;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = 8.0,
    this.columnOnMobile = true,
    this.columnOnTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);
    final useColumn = _shouldUseColumn(screenSize);

    final spacedChildren = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(
          width: useColumn ? 0 : spacing,
          height: useColumn ? spacing : 0,
        ));
      }
    }

    if (useColumn) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: spacedChildren,
      );
    } else {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: spacedChildren,
      );
    }
  }

  bool _shouldUseColumn(ScreenSize screenSize) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return columnOnMobile;
      case ScreenSize.tablet:
        return columnOnTablet;
      case ScreenSize.desktop:
        return false;
    }
  }
}

/// Responsive padding that adapts to screen size
class ResponsivePadding extends StatelessWidget {
  /// Child widget
  final Widget child;

  /// Custom padding per screen size
  final EdgeInsets? mobilePadding;
  final EdgeInsets? tabletPadding;
  final EdgeInsets? desktopPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);
    final padding = _getPadding(screenSize) ??
        ResponsiveLayout.getResponsivePadding(context);

    return Padding(
      padding: padding,
      child: child,
    );
  }

  EdgeInsets? _getPadding(ScreenSize screenSize) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return mobilePadding;
      case ScreenSize.tablet:
        return tabletPadding;
      case ScreenSize.desktop:
        return desktopPadding;
    }
  }
}
