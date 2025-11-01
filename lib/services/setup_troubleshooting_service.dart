import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/setup_error.dart';

/// Service for providing context-sensitive troubleshooting and support
///
/// This service provides:
/// - Context-aware troubleshooting guides
/// - Links to documentation and support resources
/// - Escalation paths for complex issues
/// - Feedback collection for setup improvements
class SetupTroubleshootingService extends ChangeNotifier {
  final List<TroubleshootingSession> _activeSessions = [];
  final Map<String, List<TroubleshootingGuide>> _guideCache = {};
  final StreamController<TroubleshootingFeedback> _feedbackController =
      StreamController<TroubleshootingFeedback>.broadcast();

  /// Stream of troubleshooting feedback for analytics
  Stream<TroubleshootingFeedback> get feedbackStream =>
      _feedbackController.stream;

  /// Get active troubleshooting sessions
  List<TroubleshootingSession> get activeSessions =>
      List.unmodifiable(_activeSessions);

  /// Start a troubleshooting session for an error
  TroubleshootingSession startTroubleshootingSession(
    SetupError error, {
    String? userId,
    Map<String, dynamic> context = const {},
  }) {
    final session = TroubleshootingSession(
      id: _generateSessionId(),
      error: error,
      userId: userId,
      context: context,
      startTime: DateTime.now(),
      guides: _getTroubleshootingGuides(error),
    );

    _activeSessions.add(session);
    debugPrint(
      ' [Troubleshooting] Started session ${session.id} for error: ${error.code}',
    );

    notifyListeners();
    return session;
  }

  /// Get troubleshooting guides for an error
  List<TroubleshootingGuide> getTroubleshootingGuides(SetupError error) {
    final cacheKey = '${error.type.name}_${error.code}';

    if (_guideCache.containsKey(cacheKey)) {
      return _guideCache[cacheKey]!;
    }

    final guides = _getTroubleshootingGuides(error);
    _guideCache[cacheKey] = guides;
    return guides;
  }

  /// Get context-sensitive help for a setup step
  List<TroubleshootingGuide> getContextualHelp(
    String setupStep, {
    String? platform,
    Map<String, dynamic> context = const {},
  }) {
    final guides = <TroubleshootingGuide>[];

    switch (setupStep) {
      case 'platform-detection':
        guides.addAll(_getPlatformDetectionHelp(platform, context));
        break;
      case 'container-creation':
        guides.addAll(_getContainerCreationHelp(context));
        break;
      case 'download':
        guides.addAll(_getDownloadHelp(platform, context));
        break;
      case 'installation':
        guides.addAll(_getInstallationHelp(platform, context));
        break;
      case 'tunnel-configuration':
        guides.addAll(_getTunnelConfigurationHelp(context));
        break;
      case 'connection-validation':
        guides.addAll(_getConnectionValidationHelp(context));
        break;
      default:
        guides.addAll(_getGeneralHelp());
    }

    return guides;
  }

  /// Submit feedback for a troubleshooting session
  Future<void> submitFeedback(TroubleshootingFeedback feedback) async {
    _feedbackController.add(feedback);

    // Update session if it exists
    final sessionIndex = _activeSessions.indexWhere(
      (s) => s.id == feedback.sessionId,
    );
    if (sessionIndex != -1) {
      _activeSessions[sessionIndex] = _activeSessions[sessionIndex].copyWith(
        feedback: feedback,
        endTime: DateTime.now(),
      );
    }

    debugPrint(
      ' [Troubleshooting] Received feedback for session ${feedback.sessionId}: ${feedback.wasHelpful}',
    );
    notifyListeners();
  }

  /// End a troubleshooting session
  void endTroubleshootingSession(String sessionId, {bool resolved = false}) {
    final sessionIndex = _activeSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      _activeSessions[sessionIndex] = _activeSessions[sessionIndex].copyWith(
        endTime: DateTime.now(),
        resolved: resolved,
      );

      debugPrint(
        ' [Troubleshooting] Ended session $sessionId (resolved: $resolved)',
      );
      notifyListeners();
    }
  }

  /// Get support escalation options
  List<SupportEscalationOption> getSupportEscalationOptions(SetupError error) {
    final options = <SupportEscalationOption>[];

    // Always provide documentation link
    options.add(
      SupportEscalationOption(
        type: SupportEscalationType.documentation,
        title: 'View Documentation',
        description: 'Check our comprehensive setup guide',
        url: 'https://docs.cloudtolocalllm.com/setup',
        priority: 1,
      ),
    );

    // Provide FAQ for common issues
    if (_isCommonIssue(error)) {
      options.add(
        SupportEscalationOption(
          type: SupportEscalationType.faq,
          title: 'Frequently Asked Questions',
          description: 'Find answers to common setup problems',
          url: 'https://docs.cloudtolocalllm.com/faq',
          priority: 2,
        ),
      );
    }

    // Provide community support for non-critical issues
    if (!error.isCritical) {
      options.add(
        SupportEscalationOption(
          type: SupportEscalationType.community,
          title: 'Community Support',
          description: 'Get help from the community',
          url: 'https://github.com/cloudtolocalllm/discussions',
          priority: 3,
        ),
      );
    }

    // Provide direct support for critical issues
    if (error.isCritical) {
      options.add(
        SupportEscalationOption(
          type: SupportEscalationType.directSupport,
          title: 'Contact Support',
          description: 'Get direct help from our support team',
          url: 'mailto:support@cloudtolocalllm.com',
          priority: 1,
        ),
      );
    }

    // Sort by priority
    options.sort((a, b) => a.priority.compareTo(b.priority));
    return options;
  }

  /// Generate troubleshooting guides for an error
  List<TroubleshootingGuide> _getTroubleshootingGuides(SetupError error) {
    final guides = <TroubleshootingGuide>[];

    switch (error.type) {
      case SetupErrorType.platformDetection:
        guides.addAll(_getPlatformDetectionTroubleshooting());
        break;
      case SetupErrorType.containerCreation:
        guides.addAll(_getContainerCreationTroubleshooting());
        break;
      case SetupErrorType.downloadFailure:
        guides.addAll(_getDownloadTroubleshooting());
        break;
      case SetupErrorType.tunnelConfiguration:
        guides.addAll(_getTunnelConfigurationTroubleshooting());
        break;
      case SetupErrorType.connectionValidation:
        guides.addAll(_getConnectionValidationTroubleshooting());
        break;
      case SetupErrorType.networkError:
        guides.addAll(_getNetworkTroubleshooting());
        break;
      case SetupErrorType.authentication:
        guides.addAll(_getAuthenticationTroubleshooting());
        break;
      default:
        guides.addAll(_getGeneralTroubleshooting());
    }

    return guides;
  }

  List<TroubleshootingGuide> _getPlatformDetectionTroubleshooting() {
    return [
      TroubleshootingGuide(
        id: 'platform-detection-basic',
        title: 'Platform Detection Issues',
        description: 'Troubleshoot automatic platform detection problems',
        steps: [
          TroubleshootingStep(
            title: 'Check Browser Compatibility',
            description:
                'Ensure you\'re using a modern browser with JavaScript enabled',
            action: 'Try refreshing the page or using a different browser',
          ),
          TroubleshootingStep(
            title: 'Manual Platform Selection',
            description:
                'If automatic detection fails, you can select your platform manually',
            action: 'Use the manual platform selection buttons below',
          ),
          TroubleshootingStep(
            title: 'Clear Browser Cache',
            description: 'Cached data might interfere with platform detection',
            action: 'Clear your browser cache and cookies, then try again',
          ),
        ],
        category: TroubleshootingCategory.technical,
        difficulty: TroubleshootingDifficulty.easy,
      ),
    ];
  }

  List<TroubleshootingGuide> _getContainerCreationTroubleshooting() {
    return [
      TroubleshootingGuide(
        id: 'container-creation-basic',
        title: 'Container Creation Issues',
        description: 'Troubleshoot container provisioning problems',
        steps: [
          TroubleshootingStep(
            title: 'Check Internet Connection',
            description:
                'Container creation requires a stable internet connection',
            action: 'Verify your internet connection and try again',
          ),
          TroubleshootingStep(
            title: 'Server Status',
            description: 'Our servers might be experiencing high load',
            action: 'Wait a few minutes and try again',
          ),
          TroubleshootingStep(
            title: 'Browser Issues',
            description: 'Some browsers may block container creation requests',
            action: 'Try using a different browser or disable ad blockers',
          ),
        ],
        category: TroubleshootingCategory.service,
        difficulty: TroubleshootingDifficulty.medium,
      ),
    ];
  }

  List<TroubleshootingGuide> _getDownloadTroubleshooting() {
    return [
      TroubleshootingGuide(
        id: 'download-basic',
        title: 'Download Issues',
        description: 'Troubleshoot desktop client download problems',
        steps: [
          TroubleshootingStep(
            title: 'Check Internet Connection',
            description: 'Ensure you have a stable internet connection',
            action: 'Test your connection and try downloading again',
          ),
          TroubleshootingStep(
            title: 'Disable Ad Blockers',
            description: 'Ad blockers might interfere with downloads',
            action: 'Temporarily disable ad blockers and try again',
          ),
          TroubleshootingStep(
            title: 'Try Different Browser',
            description: 'Some browsers have stricter download policies',
            action: 'Try downloading with Chrome, Firefox, or Edge',
          ),
          TroubleshootingStep(
            title: 'Direct Download',
            description: 'Use direct download links if the main download fails',
            action: 'Right-click the download button and select "Save link as"',
          ),
        ],
        category: TroubleshootingCategory.download,
        difficulty: TroubleshootingDifficulty.easy,
      ),
    ];
  }

  List<TroubleshootingGuide> _getTunnelConfigurationTroubleshooting() {
    return [
      TroubleshootingGuide(
        id: 'tunnel-config-basic',
        title: 'Tunnel Configuration Issues',
        description: 'Troubleshoot connection tunnel setup problems',
        steps: [
          TroubleshootingStep(
            title: 'Check Firewall Settings',
            description: 'Firewalls might block tunnel connections',
            action: 'Add CloudToLocalLLM to your firewall exceptions',
          ),
          TroubleshootingStep(
            title: 'Verify Port Availability',
            description: 'The tunnel requires specific ports to be available',
            action: 'Ensure ports 8080-8090 are not blocked',
          ),
          TroubleshootingStep(
            title: 'Antivirus Software',
            description: 'Antivirus software might interfere with connections',
            action: 'Add CloudToLocalLLM to your antivirus exceptions',
          ),
          TroubleshootingStep(
            title: 'Network Configuration',
            description:
                'Complex network setups might require manual configuration',
            action: 'Contact your network administrator for assistance',
          ),
        ],
        category: TroubleshootingCategory.network,
        difficulty: TroubleshootingDifficulty.hard,
      ),
    ];
  }

  List<TroubleshootingGuide> _getConnectionValidationTroubleshooting() {
    return [
      TroubleshootingGuide(
        id: 'connection-validation-basic',
        title: 'Connection Validation Issues',
        description: 'Troubleshoot connection testing problems',
        steps: [
          TroubleshootingStep(
            title: 'Ensure Desktop Client is Running',
            description:
                'The desktop client must be running for validation to work',
            action: 'Start the CloudToLocalLLM desktop client',
          ),
          TroubleshootingStep(
            title: 'Check Network Connectivity',
            description: 'Verify that the web app can reach the desktop client',
            action: 'Test your local network connection',
          ),
          TroubleshootingStep(
            title: 'Restart Desktop Client',
            description:
                'Sometimes restarting the client resolves connection issues',
            action: 'Close and restart the desktop client application',
          ),
          TroubleshootingStep(
            title: 'Manual Connection Test',
            description: 'Try connecting manually to verify the setup',
            action: 'Use the manual connection option in settings',
          ),
        ],
        category: TroubleshootingCategory.connection,
        difficulty: TroubleshootingDifficulty.medium,
      ),
    ];
  }

  List<TroubleshootingGuide> _getNetworkTroubleshooting() {
    return [
      TroubleshootingGuide(
        id: 'network-basic',
        title: 'Network Connection Issues',
        description: 'Troubleshoot general network connectivity problems',
        steps: [
          TroubleshootingStep(
            title: 'Check Internet Connection',
            description: 'Verify your internet connection is working',
            action: 'Try visiting other websites to test connectivity',
          ),
          TroubleshootingStep(
            title: 'Disable VPN Temporarily',
            description: 'VPNs might interfere with the connection',
            action: 'Temporarily disable your VPN and try again',
          ),
          TroubleshootingStep(
            title: 'Check DNS Settings',
            description: 'DNS issues can cause connection problems',
            action:
                'Try using Google DNS (8.8.8.8) or Cloudflare DNS (1.1.1.1)',
          ),
          TroubleshootingStep(
            title: 'Contact Network Administrator',
            description: 'Corporate networks might have restrictions',
            action: 'Contact your IT department for assistance',
          ),
        ],
        category: TroubleshootingCategory.network,
        difficulty: TroubleshootingDifficulty.medium,
      ),
    ];
  }

  List<TroubleshootingGuide> _getAuthenticationTroubleshooting() {
    return [
      TroubleshootingGuide(
        id: 'auth-basic',
        title: 'Authentication Issues',
        description: 'Troubleshoot login and authentication problems',
        steps: [
          TroubleshootingStep(
            title: 'Clear Browser Data',
            description: 'Cached authentication data might be corrupted',
            action: 'Clear cookies and local storage for this site',
          ),
          TroubleshootingStep(
            title: 'Try Incognito Mode',
            description: 'Test if the issue is related to browser extensions',
            action: 'Open an incognito/private browsing window and try again',
          ),
          TroubleshootingStep(
            title: 'Check Account Status',
            description: 'Verify your account is active and in good standing',
            action: 'Contact support if you suspect account issues',
          ),
          TroubleshootingStep(
            title: 'Try Different Browser',
            description: 'Some browsers have stricter security policies',
            action: 'Try logging in with a different browser',
          ),
        ],
        category: TroubleshootingCategory.authentication,
        difficulty: TroubleshootingDifficulty.medium,
      ),
    ];
  }

  List<TroubleshootingGuide> _getGeneralTroubleshooting() {
    return [
      TroubleshootingGuide(
        id: 'general-basic',
        title: 'General Troubleshooting',
        description: 'Basic troubleshooting steps for common issues',
        steps: [
          TroubleshootingStep(
            title: 'Refresh the Page',
            description: 'Sometimes a simple refresh resolves temporary issues',
            action: 'Press F5 or Ctrl+R to refresh the page',
          ),
          TroubleshootingStep(
            title: 'Clear Browser Cache',
            description: 'Cached data might be causing conflicts',
            action: 'Clear your browser cache and cookies',
          ),
          TroubleshootingStep(
            title: 'Try Different Browser',
            description: 'Browser-specific issues are common',
            action: 'Try using Chrome, Firefox, Safari, or Edge',
          ),
          TroubleshootingStep(
            title: 'Check for Updates',
            description: 'Outdated browsers might have compatibility issues',
            action: 'Update your browser to the latest version',
          ),
        ],
        category: TroubleshootingCategory.general,
        difficulty: TroubleshootingDifficulty.easy,
      ),
    ];
  }

  // Helper methods for contextual help
  List<TroubleshootingGuide> _getPlatformDetectionHelp(
    String? platform,
    Map<String, dynamic> context,
  ) {
    return _getPlatformDetectionTroubleshooting();
  }

  List<TroubleshootingGuide> _getContainerCreationHelp(
    Map<String, dynamic> context,
  ) {
    return _getContainerCreationTroubleshooting();
  }

  List<TroubleshootingGuide> _getDownloadHelp(
    String? platform,
    Map<String, dynamic> context,
  ) {
    return _getDownloadTroubleshooting();
  }

  List<TroubleshootingGuide> _getInstallationHelp(
    String? platform,
    Map<String, dynamic> context,
  ) {
    final guides = <TroubleshootingGuide>[];

    // Platform-specific installation help
    if (platform != null) {
      guides.add(
        TroubleshootingGuide(
          id: 'installation-$platform',
          title: '${platform.toUpperCase()} Installation Help',
          description: 'Platform-specific installation guidance',
          steps: _getInstallationStepsForPlatform(platform),
          category: TroubleshootingCategory.installation,
          difficulty: TroubleshootingDifficulty.medium,
        ),
      );
    }

    return guides;
  }

  List<TroubleshootingGuide> _getTunnelConfigurationHelp(
    Map<String, dynamic> context,
  ) {
    return _getTunnelConfigurationTroubleshooting();
  }

  List<TroubleshootingGuide> _getConnectionValidationHelp(
    Map<String, dynamic> context,
  ) {
    return _getConnectionValidationTroubleshooting();
  }

  List<TroubleshootingGuide> _getGeneralHelp() {
    return _getGeneralTroubleshooting();
  }

  List<TroubleshootingStep> _getInstallationStepsForPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return [
          TroubleshootingStep(
            title: 'Run as Administrator',
            description: 'Windows might require administrator privileges',
            action:
                'Right-click the installer and select "Run as administrator"',
          ),
          TroubleshootingStep(
            title: 'Check Windows Defender',
            description: 'Windows Defender might block the installation',
            action: 'Add the installer to Windows Defender exceptions',
          ),
        ];
      case 'linux':
        return [
          TroubleshootingStep(
            title: 'Make Executable',
            description: 'The AppImage might not have execute permissions',
            action: 'Run: chmod +x CloudToLocalLLM.AppImage',
          ),
          TroubleshootingStep(
            title: 'Install Dependencies',
            description: 'Some Linux distributions require additional packages',
            action: 'Install libfuse2 if AppImage doesn\'t run',
          ),
        ];
      case 'macos':
        return [
          TroubleshootingStep(
            title: 'Allow Unsigned Apps',
            description: 'macOS might block unsigned applications',
            action:
                'Go to System Preferences > Security & Privacy and allow the app',
          ),
          TroubleshootingStep(
            title: 'Gatekeeper Override',
            description: 'You might need to override Gatekeeper',
            action: 'Control-click the app and select "Open"',
          ),
        ];
      default:
        return [];
    }
  }

  bool _isCommonIssue(SetupError error) {
    // Define common issues that have FAQ entries
    const commonErrorCodes = {
      'PLATFORM_DETECTION_FAILED',
      'DOWNLOAD_FAILED',
      'NETWORK_ERROR',
      'CONNECTION_VALIDATION_FAILED',
    };

    return commonErrorCodes.contains(error.code);
  }

  String _generateSessionId() {
    return 'ts_${DateTime.now().millisecondsSinceEpoch}_${_activeSessions.length}';
  }

  @override
  void dispose() {
    _feedbackController.close();
    super.dispose();
  }
}

/// Troubleshooting session tracking
@immutable
class TroubleshootingSession {
  final String id;
  final SetupError error;
  final String? userId;
  final Map<String, dynamic> context;
  final DateTime startTime;
  final DateTime? endTime;
  final List<TroubleshootingGuide> guides;
  final TroubleshootingFeedback? feedback;
  final bool resolved;

  const TroubleshootingSession({
    required this.id,
    required this.error,
    this.userId,
    this.context = const {},
    required this.startTime,
    this.endTime,
    required this.guides,
    this.feedback,
    this.resolved = false,
  });

  TroubleshootingSession copyWith({
    String? id,
    SetupError? error,
    String? userId,
    Map<String, dynamic>? context,
    DateTime? startTime,
    DateTime? endTime,
    List<TroubleshootingGuide>? guides,
    TroubleshootingFeedback? feedback,
    bool? resolved,
  }) {
    return TroubleshootingSession(
      id: id ?? this.id,
      error: error ?? this.error,
      userId: userId ?? this.userId,
      context: context ?? this.context,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      guides: guides ?? this.guides,
      feedback: feedback ?? this.feedback,
      resolved: resolved ?? this.resolved,
    );
  }

  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }
}

/// Troubleshooting guide
@immutable
class TroubleshootingGuide {
  final String id;
  final String title;
  final String description;
  final List<TroubleshootingStep> steps;
  final TroubleshootingCategory category;
  final TroubleshootingDifficulty difficulty;
  final List<String> tags;

  const TroubleshootingGuide({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
    required this.category,
    required this.difficulty,
    this.tags = const [],
  });
}

/// Individual troubleshooting step
@immutable
class TroubleshootingStep {
  final String title;
  final String description;
  final String action;
  final String? url;
  final bool isOptional;

  const TroubleshootingStep({
    required this.title,
    required this.description,
    required this.action,
    this.url,
    this.isOptional = false,
  });
}

/// Troubleshooting categories
enum TroubleshootingCategory {
  general,
  technical,
  network,
  download,
  installation,
  connection,
  authentication,
  service,
}

/// Difficulty levels
enum TroubleshootingDifficulty { easy, medium, hard }

/// Support escalation options
@immutable
class SupportEscalationOption {
  final SupportEscalationType type;
  final String title;
  final String description;
  final String url;
  final int priority;

  const SupportEscalationOption({
    required this.type,
    required this.title,
    required this.description,
    required this.url,
    required this.priority,
  });
}

/// Support escalation types
enum SupportEscalationType { documentation, faq, community, directSupport }

/// Troubleshooting feedback
@immutable
class TroubleshootingFeedback {
  final String sessionId;
  final bool wasHelpful;
  final String? comment;
  final List<String> helpfulGuides;
  final List<String> unhelpfulGuides;
  final DateTime timestamp;

  const TroubleshootingFeedback({
    required this.sessionId,
    required this.wasHelpful,
    this.comment,
    this.helpfulGuides = const [],
    this.unhelpfulGuides = const [],
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'wasHelpful': wasHelpful,
      'comment': comment,
      'helpfulGuides': helpfulGuides,
      'unhelpfulGuides': unhelpfulGuides,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
