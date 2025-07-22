import 'package:flutter/foundation.dart';
import '../models/platform_config.dart';
import '../models/download_option.dart';
import '../models/installation_step.dart';
import '../config/app_config.dart';

/// Service for detecting user's platform and providing appropriate download options
class PlatformDetectionService extends ChangeNotifier {
  PlatformType? _detectedPlatform;
  PlatformType? _selectedPlatform;
  bool _isInitialized = false;

  // Platform configurations
  late final Map<PlatformType, PlatformConfig> _platformConfigs;

  PlatformDetectionService() {
    _initializePlatformConfigs();
    if (kIsWeb) {
      detectPlatform();
    }
  }

  // Getters
  PlatformType? get detectedPlatform => _detectedPlatform;
  PlatformType? get selectedPlatform => _selectedPlatform;
  PlatformType get currentPlatform =>
      _selectedPlatform ?? _detectedPlatform ?? PlatformType.unknown;
  bool get isInitialized => _isInitialized;

  /// Initialize platform configurations with download options and installation steps
  void _initializePlatformConfigs() {
    _platformConfigs = {
      PlatformType.windows: _createWindowsConfig(),
      PlatformType.linux: _createLinuxConfig(),
      PlatformType.macos: _createMacOSConfig(),
    };
    _isInitialized = true;
  }

  /// Detect platform from browser user agent
  PlatformType detectPlatform() {
    if (!kIsWeb) {
      _detectedPlatform = PlatformType.unknown;
      return _detectedPlatform!;
    }

    try {
      // For non-web platforms, we can't detect from user agent
      // Default to unknown and let user select manually
      _detectedPlatform = PlatformType.unknown;

      debugPrint(
        '🔍 [PlatformDetection] Non-web platform detected, defaulting to unknown',
      );
      notifyListeners();
      return _detectedPlatform!;
    } catch (e) {
      debugPrint('🔍 [PlatformDetection] Error detecting platform: $e');
      _detectedPlatform = PlatformType.unknown;
      notifyListeners();
      return _detectedPlatform!;
    }
  }

  /// Manually set the selected platform (override detection)
  void selectPlatform(PlatformType platform) {
    _selectedPlatform = platform;
    debugPrint('🔍 [PlatformDetection] Manually selected platform: $platform');
    notifyListeners();
  }

  /// Clear manual platform selection (revert to detection)
  void clearPlatformSelection() {
    _selectedPlatform = null;
    debugPrint(
      '🔍 [PlatformDetection] Cleared manual platform selection, reverting to detected: $_detectedPlatform',
    );
    notifyListeners();
  }

  /// Get download options for the current platform
  List<DownloadOption> getDownloadOptions([PlatformType? platform]) {
    final targetPlatform = platform ?? currentPlatform;
    final config = _platformConfigs[targetPlatform];
    return config?.downloadOptions ?? [];
  }

  /// Get installation instructions for a specific platform and download type
  String getInstallationInstructions(
    PlatformType platform,
    String downloadType,
  ) {
    final config = _platformConfigs[platform];
    if (config == null) {
      return 'Installation instructions not available for this platform.';
    }

    final steps = config.getInstallationSteps(downloadType);
    if (steps.isEmpty) {
      return 'No specific installation steps found for $downloadType on ${platform.displayName}.';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Installation Instructions for ${platform.displayName} ($downloadType):',
    );
    buffer.writeln();

    for (final step in steps..sort((a, b) => a.order.compareTo(b.order))) {
      buffer.writeln('${step.order + 1}. ${step.title}');
      buffer.writeln('   ${step.description}');

      if (step.commands.isNotEmpty) {
        buffer.writeln('   Commands:');
        for (final command in step.commands) {
          buffer.writeln('   \$ $command');
        }
      }

      if (step.troubleshootingTips.isNotEmpty) {
        buffer.writeln('   Troubleshooting:');
        for (final tip in step.troubleshootingTips) {
          buffer.writeln('   • $tip');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Get platform configuration
  PlatformConfig? getPlatformConfig([PlatformType? platform]) {
    final targetPlatform = platform ?? currentPlatform;
    return _platformConfigs[targetPlatform];
  }

  /// Get all supported platforms
  List<PlatformType> getSupportedPlatforms() {
    return _platformConfigs.keys.toList();
  }

  /// Check if a platform is supported
  bool isPlatformSupported(PlatformType platform) {
    return _platformConfigs.containsKey(platform);
  }

  /// Create Windows platform configuration
  PlatformConfig _createWindowsConfig() {
    return PlatformConfig(
      platform: PlatformType.windows,
      displayName: 'Windows',
      iconPath: 'assets/images/windows-icon.png',
      downloadOptions: [
        DownloadOption(
          name: 'Windows Installer (MSI)',
          description:
              'Recommended for most users. Includes automatic updates and system integration.',
          downloadUrl:
              'https://github.com/imrightguy/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-windows-x64.msi',
          fileSize: '~45 MB',
          installationType: 'msi',
          isRecommended: true,
          requirements: [
            'Windows 10 or later',
            'Administrator privileges for installation',
          ],
        ),
        DownloadOption(
          name: 'Portable ZIP',
          description: 'No installation required. Extract and run directly.',
          downloadUrl:
              'https://github.com/imrightguy/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-windows-x64-portable.zip',
          fileSize: '~42 MB',
          installationType: 'zip',
          requirements: ['Windows 10 or later'],
        ),
      ],
      installationSteps: [
        InstallationStep(
          title: 'Download the installer',
          description:
              'Click the download link above to get the MSI installer.',
          applicableTypes: ['msi'],
          order: 0,
        ),
        InstallationStep(
          title: 'Run the installer',
          description:
              'Double-click the downloaded MSI file and follow the installation wizard.',
          applicableTypes: ['msi'],
          order: 1,
          troubleshootingTips: [
            'If Windows Defender blocks the installer, click "More info" then "Run anyway"',
            'You may need administrator privileges to install',
          ],
        ),
        InstallationStep(
          title: 'Launch the application',
          description:
              'Find CloudToLocalLLM in your Start menu or desktop shortcut.',
          applicableTypes: ['msi'],
          order: 2,
        ),
        InstallationStep(
          title: 'Extract the archive',
          description:
              'Right-click the ZIP file and select "Extract All" or use your preferred archive tool.',
          applicableTypes: ['zip'],
          order: 0,
        ),
        InstallationStep(
          title: 'Run the executable',
          description:
              'Navigate to the extracted folder and double-click cloudtolocalllm.exe.',
          applicableTypes: ['zip'],
          order: 1,
          troubleshootingTips: [
            'If Windows Defender blocks the executable, add an exception',
            'You can create a desktop shortcut for easier access',
          ],
        ),
      ],
      troubleshootingGuides: {
        'windows_defender':
            'If Windows Defender blocks the application, go to Windows Security > Virus & threat protection > Manage settings > Add or remove exclusions.',
        'admin_rights':
            'If installation fails due to permissions, right-click the installer and select "Run as administrator".',
        'missing_dependencies':
            'Ensure you have the latest Visual C++ Redistributable installed from Microsoft.',
      },
      requiredDependencies: [
        'Windows 10 version 1903 or later',
        'Visual C++ Redistributable 2019 or later',
      ],
    );
  }

  /// Create Linux platform configuration
  PlatformConfig _createLinuxConfig() {
    return PlatformConfig(
      platform: PlatformType.linux,
      displayName: 'Linux',
      iconPath: 'assets/images/linux-icon.png',
      downloadOptions: [
        DownloadOption(
          name: 'AppImage (Universal)',
          description:
              'Portable application that runs on any Linux distribution. No installation required.',
          downloadUrl:
              'https://github.com/imrightguy/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-x86_64.AppImage',
          fileSize: '~48 MB',
          installationType: 'appimage',
          isRecommended: true,
          requirements: ['x86_64 architecture', 'FUSE or AppImage runtime'],
        ),
        DownloadOption(
          name: 'Debian Package (.deb)',
          description:
              'Native package for Ubuntu, Debian, and derivatives with proper dependency management.',
          downloadUrl:
              'https://github.com/imrightguy/CloudToLocalLLM/releases/latest/download/cloudtolocalllm_${AppConfig.appVersion}_amd64.deb',
          fileSize: '~44 MB',
          installationType: 'deb',
          requirements: [
            'Ubuntu 20.04+, Debian 11+, or compatible',
            'dpkg package manager',
          ],
        ),
        DownloadOption(
          name: 'Arch Linux (AUR)',
          description:
              'Pre-built binary package for Arch Linux and derivatives.',
          downloadUrl: 'https://aur.archlinux.org/packages/cloudtolocalllm',
          fileSize: '~42 MB',
          installationType: 'aur',
          requirements: [
            'Arch Linux or derivative',
            'AUR helper (yay, paru, etc.)',
          ],
        ),
      ],
      installationSteps: [
        InstallationStep(
          title: 'Download AppImage',
          description: 'Click the download link to get the AppImage file.',
          applicableTypes: ['appimage'],
          order: 0,
        ),
        InstallationStep(
          title: 'Make executable',
          description: 'Open terminal and make the AppImage executable.',
          commands: [
            'chmod +x cloudtolocalllm-${AppConfig.appVersion}-x86_64.AppImage',
          ],
          applicableTypes: ['appimage'],
          order: 1,
        ),
        InstallationStep(
          title: 'Run the application',
          description: 'Double-click the AppImage or run it from terminal.',
          commands: [
            './cloudtolocalllm-${AppConfig.appVersion}-x86_64.AppImage',
          ],
          applicableTypes: ['appimage'],
          order: 2,
          troubleshootingTips: [
            'If AppImage doesn\'t run, install FUSE: sudo apt install fuse',
            'For system tray support, install libayatana-appindicator',
          ],
        ),
        InstallationStep(
          title: 'Download DEB package',
          description: 'Download the .deb file for your system.',
          applicableTypes: ['deb'],
          order: 0,
        ),
        InstallationStep(
          title: 'Install package',
          description: 'Install using dpkg or your package manager.',
          commands: [
            'sudo dpkg -i cloudtolocalllm_${AppConfig.appVersion}_amd64.deb',
            'sudo apt-get install -f  # Fix dependencies if needed',
          ],
          applicableTypes: ['deb'],
          order: 1,
        ),
        InstallationStep(
          title: 'Install from AUR',
          description: 'Use your preferred AUR helper to install.',
          commands: [
            'yay -S cloudtolocalllm',
            '# Or: paru -S cloudtolocalllm',
            '# Or: pamac install cloudtolocalllm',
          ],
          applicableTypes: ['aur'],
          order: 0,
        ),
      ],
      troubleshootingGuides: {
        'appimage_not_running':
            'Install FUSE support: sudo apt install fuse libfuse2',
        'system_tray_missing':
            'Install system tray support: sudo apt install libayatana-appindicator3-1',
        'deb_dependencies': 'Fix broken dependencies: sudo apt-get install -f',
        'permission_denied': 'Ensure the file is executable: chmod +x filename',
      },
      requiredDependencies: [
        'x86_64 (64-bit) architecture',
        'GLIBC 2.31 or later',
        'libayatana-appindicator3-1 (for system tray)',
        'FUSE (for AppImage)',
      ],
    );
  }

  /// Create macOS platform configuration
  PlatformConfig _createMacOSConfig() {
    return PlatformConfig(
      platform: PlatformType.macos,
      displayName: 'macOS',
      iconPath: 'assets/images/macos-icon.png',
      downloadOptions: [
        DownloadOption(
          name: 'macOS Application (.dmg)',
          description:
              'Standard macOS installer with drag-and-drop installation.',
          downloadUrl:
              'https://github.com/imrightguy/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-macos.dmg',
          fileSize: '~50 MB',
          installationType: 'dmg',
          isRecommended: true,
          requirements: [
            'macOS 11.0 (Big Sur) or later',
            'Intel or Apple Silicon Mac',
          ],
        ),
      ],
      installationSteps: [
        InstallationStep(
          title: 'Download DMG file',
          description: 'Click the download link to get the macOS installer.',
          applicableTypes: ['dmg'],
          order: 0,
        ),
        InstallationStep(
          title: 'Open the installer',
          description: 'Double-click the downloaded DMG file to mount it.',
          applicableTypes: ['dmg'],
          order: 1,
        ),
        InstallationStep(
          title: 'Install the application',
          description: 'Drag CloudToLocalLLM to your Applications folder.',
          applicableTypes: ['dmg'],
          order: 2,
        ),
        InstallationStep(
          title: 'Launch the application',
          description:
              'Find CloudToLocalLLM in your Applications folder and launch it.',
          applicableTypes: ['dmg'],
          order: 3,
          troubleshootingTips: [
            'If macOS blocks the app, go to System Preferences > Security & Privacy and click "Open Anyway"',
            'You may need to right-click the app and select "Open" the first time',
          ],
        ),
      ],
      troubleshootingGuides: {
        'gatekeeper_blocked':
            'If Gatekeeper blocks the app, go to System Preferences > Security & Privacy > General and click "Open Anyway".',
        'quarantine_attribute':
            'Remove quarantine attribute: xattr -d com.apple.quarantine /Applications/CloudToLocalLLM.app',
        'permission_denied':
            'Ensure you have permission to write to Applications folder.',
      },
      requiredDependencies: [
        'macOS 11.0 (Big Sur) or later',
        'Intel x64 or Apple Silicon (M1/M2) processor',
      ],
    );
  }

  /// Re-detect platform (useful for testing or manual refresh)
  void refreshDetection() {
    detectPlatform();
  }
}
