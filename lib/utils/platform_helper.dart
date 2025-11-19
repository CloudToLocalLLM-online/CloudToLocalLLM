import 'platform_helper_stub.dart'
    if (dart.library.io) 'platform_helper_io.dart'
    if (dart.library.html) 'platform_helper_web.dart';

/// Platform helper class for cross-platform compatibility
///
/// Provides safe access to platform flags (isWindows, isMacOS, etc.) without
/// directly importing dart:io, which would break web builds.
class PlatformHelper {
  static bool get isWindows => PlatformHelperImpl.isWindows;
  static bool get isMacOS => PlatformHelperImpl.isMacOS;
  static bool get isLinux => PlatformHelperImpl.isLinux;
  static bool get isAndroid => PlatformHelperImpl.isAndroid;
  static bool get isIOS => PlatformHelperImpl.isIOS;
}
