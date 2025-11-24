import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'platform_detection_service.dart';

/// Component type enumeration
enum ComponentType {
  button,
  textField,
  switch_,
  slider,
  dialog,
  progressIndicator,
  appBar,
  navigationBar,
  listTile,
  card,
  checkbox,
  radio,
  dropdown,
}

/// Adapter for selecting platform-appropriate UI components
///
/// This class provides automatic component selection based on the detected platform:
/// - Material Design for Web and Android
/// - Cupertino for iOS
/// - Native-feeling desktop components for Windows and Linux
class PlatformAdapter {
  final PlatformDetectionService platformService;

  PlatformAdapter(this.platformService);

  /// Build a platform-appropriate button
  Widget buildButton({
    required VoidCallback? onPressed,
    required Widget child,
    bool isPrimary = true,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      if (isPrimary) {
        return ElevatedButton(
          onPressed: onPressed,
          child: child,
        );
      } else {
        return TextButton(
          onPressed: onPressed,
          child: child,
        );
      }
    } else {
      // Fallback to Material (Cupertino would be added for iOS)
      if (isPrimary) {
        return ElevatedButton(
          onPressed: onPressed,
          child: child,
        );
      } else {
        return TextButton(
          onPressed: onPressed,
          child: child,
        );
      }
    }
  }

  /// Build a platform-appropriate text field
  Widget buildTextField({
    TextEditingController? controller,
    String? placeholder,
    String? label,
    ValueChanged<String>? onChanged,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
        ),
        onChanged: onChanged,
        obscureText: obscureText,
        keyboardType: keyboardType,
      );
    } else {
      // Fallback to Material
      return TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
        ),
        onChanged: onChanged,
        obscureText: obscureText,
        keyboardType: keyboardType,
      );
    }
  }

  /// Build a platform-appropriate switch
  Widget buildSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return Switch(
        value: value,
        onChanged: onChanged,
      );
    } else {
      // Fallback to Material
      return Switch(
        value: value,
        onChanged: onChanged,
      );
    }
  }

  /// Build a platform-appropriate slider
  Widget buildSlider({
    required double value,
    required ValueChanged<double>? onChanged,
    double min = 0.0,
    double max = 1.0,
    int? divisions,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
      );
    } else {
      // Fallback to Material
      return Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
      );
    }
  }

  /// Build a platform-appropriate progress indicator
  Widget buildProgressIndicator({
    double? value,
    Color? color,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      if (value != null) {
        return CircularProgressIndicator(
          value: value,
          color: color,
        );
      } else {
        return CircularProgressIndicator(
          color: color,
        );
      }
    } else {
      // Fallback to Material
      if (value != null) {
        return CircularProgressIndicator(
          value: value,
          color: color,
        );
      } else {
        return CircularProgressIndicator(
          color: color,
        );
      }
    }
  }

  /// Build a platform-appropriate dialog
  Future<T?> showPlatformDialog<T>({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return showDialog<T>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (cancelText != null)
              TextButton(
                onPressed: () {
                  onCancel?.call();
                  Navigator.of(context).pop();
                },
                child: Text(cancelText),
              ),
            if (confirmText != null)
              TextButton(
                onPressed: () {
                  onConfirm?.call();
                  Navigator.of(context).pop();
                },
                child: Text(confirmText),
              ),
          ],
        ),
      );
    } else {
      // Fallback to Material
      return showDialog<T>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (cancelText != null)
              TextButton(
                onPressed: () {
                  onCancel?.call();
                  Navigator.of(context).pop();
                },
                child: Text(cancelText),
              ),
            if (confirmText != null)
              TextButton(
                onPressed: () {
                  onConfirm?.call();
                  Navigator.of(context).pop();
                },
                child: Text(confirmText),
              ),
          ],
        ),
      );
    }
  }

  /// Build a platform-appropriate app bar
  PreferredSizeWidget buildAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
      );
    } else {
      // Fallback to Material
      return AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
      );
    }
  }

  /// Build a platform-appropriate list tile
  Widget buildListTile({
    Widget? leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
      );
    } else {
      // Fallback to Material
      return ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
      );
    }
  }

  /// Build a platform-appropriate card
  Widget buildCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return Card(
        margin: margin,
        child:
            padding != null ? Padding(padding: padding, child: child) : child,
      );
    } else {
      // Fallback to Material
      return Card(
        margin: margin,
        child:
            padding != null ? Padding(padding: padding, child: child) : child,
      );
    }
  }

  /// Build a platform-appropriate checkbox
  Widget buildCheckbox({
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return Checkbox(
        value: value,
        onChanged: onChanged,
      );
    } else {
      // Fallback to Material
      return Checkbox(
        value: value,
        onChanged: onChanged,
      );
    }
  }

  /// Build a platform-appropriate radio button
  Widget buildRadio<T>({
    required T value,
    required T groupValue,
    required ValueChanged<T?>? onChanged,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return Radio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
      );
    } else {
      // Fallback to Material
      return Radio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
      );
    }
  }

  /// Build a platform-appropriate dropdown
  Widget buildDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    String? hint,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        hint: hint != null ? Text(hint) : null,
      );
    } else {
      // Fallback to Material
      return DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        hint: hint != null ? Text(hint) : null,
      );
    }
  }

  /// Get the component type for the current platform
  String getComponentType(ComponentType type) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      return 'Material';
    } else {
      return 'Material'; // Fallback
    }
  }

  /// Check if platform supports a specific feature
  bool supportsFeature(String feature) {
    switch (feature) {
      case 'system_tray':
        return platformService.isDesktop && !platformService.isWeb;
      case 'window_management':
        return platformService.isDesktop && !platformService.isWeb;
      case 'file_system':
        return !platformService.isWeb;
      case 'notifications':
        return true; // All platforms support notifications
      case 'biometric_auth':
        return platformService.isMobile;
      default:
        return false;
    }
  }

  /// Get platform-specific styling adjustments
  Map<String, dynamic> getPlatformStyling() {
    if (platformService.isWeb) {
      return {
        'buttonPadding':
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        'inputPadding': const EdgeInsets.all(12),
        'borderRadius': 4.0,
        'elevation': 2.0,
      };
    } else if (platformService.isDesktop) {
      return {
        'buttonPadding':
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        'inputPadding': const EdgeInsets.all(10),
        'borderRadius': 4.0,
        'elevation': 1.0,
      };
    } else {
      // Mobile fallback
      return {
        'buttonPadding':
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        'inputPadding': const EdgeInsets.all(12),
        'borderRadius': 8.0,
        'elevation': 2.0,
      };
    }
  }

  /// Build a platform-appropriate loading indicator
  Widget buildLoadingIndicator({
    double? size,
    Color? color,
  }) {
    if (platformService.isWeb ||
        platformService.isLinux ||
        platformService.isWindows) {
      // Material Design for web and desktop
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          valueColor:
              color != null ? AlwaysStoppedAnimation<Color>(color) : null,
          strokeWidth: size != null ? size / 12 : 4.0,
        ),
      );
    } else {
      // Fallback to Material
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          valueColor:
              color != null ? AlwaysStoppedAnimation<Color>(color) : null,
          strokeWidth: size != null ? size / 12 : 4.0,
        ),
      );
    }
  }
}
