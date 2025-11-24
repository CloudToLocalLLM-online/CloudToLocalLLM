import 'package:flutter/material.dart';
import '../services/platform_adapter.dart';
import '../di/locator.dart';

/// A button widget that automatically adapts to the current platform
///
/// This widget uses the PlatformAdapter to render platform-appropriate
/// button styles based on the detected platform.
class PlatformAwareButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isPrimary;

  const PlatformAwareButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final platformAdapter = serviceLocator.get<PlatformAdapter>();

    return platformAdapter.buildButton(
      onPressed: onPressed,
      child: child,
      isPrimary: isPrimary,
    );
  }
}
