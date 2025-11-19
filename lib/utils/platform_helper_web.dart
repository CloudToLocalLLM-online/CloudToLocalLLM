/// Web implementation for platform helper
class PlatformHelperImpl {
  // On web, we don't use these flags for OS detection typically, 
  // or we implement UA sniffing if strictly needed.
  // For now, returning false matches "kIsWeb is true, so don't use native features".
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
}
