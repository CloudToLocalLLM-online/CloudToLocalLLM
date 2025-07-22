import 'download_option.dart';
import 'installation_step.dart';

/// Configuration for a specific platform including download options and installation steps
class PlatformConfig {
  final PlatformType platform;
  final List<DownloadOption> downloadOptions;
  final List<InstallationStep> installationSteps;
  final Map<String, String> troubleshootingGuides;
  final List<String> requiredDependencies;
  final String displayName;
  final String? iconPath;

  const PlatformConfig({
    required this.platform,
    required this.downloadOptions,
    required this.installationSteps,
    required this.troubleshootingGuides,
    required this.requiredDependencies,
    required this.displayName,
    this.iconPath,
  });

  /// Get the recommended download option for this platform
  DownloadOption? get recommendedDownload {
    try {
      return downloadOptions.firstWhere((option) => option.isRecommended);
    } catch (e) {
      return downloadOptions.isNotEmpty ? downloadOptions.first : null;
    }
  }

  /// Get installation steps for a specific download type
  List<InstallationStep> getInstallationSteps(String installationType) {
    return installationSteps
        .where((step) => step.applicableTypes.contains(installationType))
        .toList();
  }

  /// Get troubleshooting guide for a specific error type
  String? getTroubleshootingGuide(String errorType) {
    return troubleshootingGuides[errorType];
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'platform': platform.name,
      'downloadOptions': downloadOptions.map((o) => o.toJson()).toList(),
      'installationSteps': installationSteps.map((s) => s.toJson()).toList(),
      'troubleshootingGuides': troubleshootingGuides,
      'requiredDependencies': requiredDependencies,
      'displayName': displayName,
      'iconPath': iconPath,
    };
  }

  /// Create from JSON
  factory PlatformConfig.fromJson(Map<String, dynamic> json) {
    return PlatformConfig(
      platform: PlatformType.values.firstWhere(
        (p) => p.name == json['platform'],
        orElse: () => PlatformType.unknown,
      ),
      downloadOptions: (json['downloadOptions'] as List<dynamic>)
          .map((o) => DownloadOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      installationSteps: (json['installationSteps'] as List<dynamic>)
          .map((s) => InstallationStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      troubleshootingGuides: Map<String, String>.from(
        json['troubleshootingGuides'] as Map<String, dynamic>,
      ),
      requiredDependencies: (json['requiredDependencies'] as List<dynamic>)
          .map((d) => d as String)
          .toList(),
      displayName: json['displayName'] as String,
      iconPath: json['iconPath'] as String?,
    );
  }

  @override
  String toString() {
    return 'PlatformConfig(platform: $platform, displayName: $displayName, downloadOptions: ${downloadOptions.length})';
  }
}

/// Enumeration of supported platforms
enum PlatformType {
  windows('Windows'),
  linux('Linux'),
  macos('macOS'),
  unknown('Unknown');

  const PlatformType(this.displayName);

  final String displayName;

  /// Get platform type from user agent string
  static PlatformType fromUserAgent(String userAgent) {
    final ua = userAgent.toLowerCase();

    if (ua.contains('windows') ||
        ua.contains('win32') ||
        ua.contains('win64')) {
      return PlatformType.windows;
    } else if (ua.contains('mac') || ua.contains('darwin')) {
      return PlatformType.macos;
    } else if (ua.contains('linux') || ua.contains('x11')) {
      return PlatformType.linux;
    }

    return PlatformType.unknown;
  }

  /// Get platform type from Flutter's platform detection
  static PlatformType fromFlutterPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return PlatformType.windows;
      case 'linux':
        return PlatformType.linux;
      case 'macos':
        return PlatformType.macos;
      default:
        return PlatformType.unknown;
    }
  }

  /// Check if this platform supports a specific installation type
  bool supportsInstallationType(String installationType) {
    switch (this) {
      case PlatformType.windows:
        return ['msi', 'zip', 'exe'].contains(installationType.toLowerCase());
      case PlatformType.linux:
        return [
          'deb',
          'appimage',
          'tar.gz',
          'snap',
          'aur',
        ].contains(installationType.toLowerCase());
      case PlatformType.macos:
        return ['dmg', 'pkg', 'zip'].contains(installationType.toLowerCase());
      case PlatformType.unknown:
        return false;
    }
  }
}
