/// Responsive Layout Utilities
///
/// Provides utilities for building responsive layouts with breakpoints
/// and accessibility considerations.
library;

import 'package:flutter/material.dart';

/// Responsive breakpoints for different screen sizes
class ResponsiveBreakpoints {
  /// Mobile breakpoint (< 600px)
  static const double mobile = 600;

  /// Tablet breakpoint (600px - 1024px)
  static const double tablet = 1024;

  /// Desktop breakpoint (> 1024px)
  static const double desktop = 1024;

  /// Minimum touch target size (44x44 pixels)
  static const double minTouchTarget = 44;

  /// Minimum desktop touch target size (32x32 pixels)
  static const double minDesktopTouchTarget = 32;
}

/// Screen size classification
enum ScreenSize {
  /// Mobile device (< 600px)
  mobile,

  /// Tablet device (600px - 1024px)
  tablet,

  /// Desktop device (> 1024px)
  desktop,
}

/// Responsive layout helper
class ResponsiveLayout {
  /// Get the current screen size classification
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.mobile) {
      return ScreenSize.mobile;
    } else if (width < ResponsiveBreakpoints.tablet) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.desktop;
    }
  }

  /// Check if the current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
  }

  /// Check if the current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobile &&
        width < ResponsiveBreakpoints.tablet;
  }

  /// Check if the current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tablet;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return const EdgeInsets.all(12);
      case ScreenSize.tablet:
        return const EdgeInsets.all(16);
      case ScreenSize.desktop:
        return const EdgeInsets.all(24);
    }
  }

  /// Get responsive font size based on screen size
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobileSize,
    required double tabletSize,
    required double desktopSize,
  }) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return mobileSize;
      case ScreenSize.tablet:
        return tabletSize;
      case ScreenSize.desktop:
        return desktopSize;
    }
  }

  /// Get responsive width for a container
  static double getResponsiveWidth(
    BuildContext context, {
    required double mobileWidth,
    required double tabletWidth,
    required double desktopWidth,
  }) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return mobileWidth;
      case ScreenSize.tablet:
        return tabletWidth;
      case ScreenSize.desktop:
        return desktopWidth;
    }
  }

  /// Get responsive column count for grid layouts
  static int getResponsiveColumnCount(BuildContext context) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return 1;
      case ScreenSize.tablet:
        return 2;
      case ScreenSize.desktop:
        return 3;
    }
  }

  /// Get minimum touch target size based on platform
  static double getMinTouchTargetSize(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return isDesktop
        ? ResponsiveBreakpoints.minDesktopTouchTarget
        : ResponsiveBreakpoints.minTouchTarget;
  }
}

/// Responsive widget that rebuilds when screen size changes
class ResponsiveWidget extends StatelessWidget {
  /// Builder function that receives the current screen size
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveWidget({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);
    return builder(context, screenSize);
  }
}

/// Responsive container that adapts to screen size
class ResponsiveContainer extends StatelessWidget {
  /// Child widget
  final Widget child;

  /// Maximum width for the container
  final double? maxWidth;

  /// Padding for the container
  final EdgeInsets? padding;

  /// Background color
  final Color? backgroundColor;

  /// Border radius
  final BorderRadius? borderRadius;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding =
        padding ?? ResponsiveLayout.getResponsivePadding(context);

    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
      ),
      padding: responsivePadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}
