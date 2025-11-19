/// Stub implementation for platform helper
/// Used when neither dart:io nor dart:html is available (should not happen)
class PlatformHelperImpl {
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
}
