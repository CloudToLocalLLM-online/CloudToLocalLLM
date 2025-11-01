import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/desktop_client_detection_service.dart';
import '../services/user_container_service.dart';
import '../services/platform_detection_service.dart';
import '../services/download_management_service.dart';
import '../services/tunnel_service.dart';
import '../services/connection_validation_service.dart';
import '../services/auth_service.dart';
import '../models/container_creation_result.dart';
import '../models/platform_config.dart';
import '../models/download_option.dart';
import '../models/installation_step.dart';
import 'loading_animation.dart';
import 'accessibility_helpers.dart';
import 'step_transition.dart';

/// Setup wizard component that appears for first-time users or when no desktop client is detected
///
/// This component guides users through:
/// - Understanding the desktop client requirement for local Ollama connectivity
/// - Downloading the appropriate client for their platform
/// - Step-by-step installation instructions
/// - Connection verification steps
class SetupWizard extends StatefulWidget {
  final bool isFirstTimeUser;
  final VoidCallback? onDismiss;
  final VoidCallback? onComplete;

  const SetupWizard({
    super.key,
    this.isFirstTimeUser = false,
    this.onDismiss,
    this.onComplete,
  });

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _currentStep = 0;
  bool _isDismissed = false;

  // Tunnel configuration state
  bool _isTunnelConfiguring = false;
  bool _isTunnelValidating = false;
  bool _tunnelConfigured = false;
  String? _tunnelError;

  // Connection validation state
  bool _isValidatingConnection = false;
  bool _connectionValidated = false;
  String? _validationError;

  final List<SetupStep> _steps = [
    SetupStep(
      title: 'Welcome to CloudToLocalLLM',
      description:
          'Connect your local Ollama instance to this web interface for secure, private AI conversations.',
      icon: Icons.cloud_download_outlined,
    ),
    SetupStep(
      title: 'Container Setup',
      description:
          'Creating your secure streaming proxy container for isolated communication with your local LLM.',
      icon: Icons.storage,
    ),
    SetupStep(
      title: 'Desktop Client Required',
      description:
          'To use your local Ollama models, you need to install the CloudToLocalLLM desktop client. It creates a secure tunnel between your local Ollama instance and this web app.',
      icon: Icons.desktop_windows,
    ),
    SetupStep(
      title: 'Download Desktop Client',
      description: 'Choose the appropriate version for your operating system.',
      icon: Icons.download,
    ),
    SetupStep(
      title: 'Installation Instructions',
      description: 'Follow the platform-specific installation guide.',
      icon: Icons.install_desktop,
    ),
    SetupStep(
      title: 'Connection Verification',
      description:
          'Verify that your desktop client is connected and ready to use.',
      icon: Icons.check_circle_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Don't show if dismissed
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    // For web platform, use the existing download-focused wizard
    if (kIsWeb) {
      return Consumer<DesktopClientDetectionService>(
        builder: (context, clientDetection, child) {
          // Don't show if clients are connected (unless it's first time user)
          if (clientDetection.hasConnectedClients && !widget.isFirstTimeUser) {
            return const SizedBox.shrink();
          }

          return _buildWizardDialog(context, clientDetection);
        },
      );
    }

    // For desktop platform, show desktop-specific setup wizard
    return _buildDesktopWizardDialog(context);
  }

  Widget _buildWizardDialog(
    BuildContext context,
    DesktopClientDetectionService clientDetection,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    final isMobile = screenSize.width < 480;

    // Responsive sizing
    final dialogWidth = isMobile
        ? screenSize.width * 0.95
        : isSmallScreen
        ? screenSize.width * 0.9
        : 600.0;
    final dialogHeight = isMobile
        ? screenSize.height * 0.9
        : isSmallScreen
        ? screenSize.height * 0.85
        : 500.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child: Semantics(
        label: 'Setup wizard dialog',
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard,
            borderRadius: BorderRadius.circular(
              isMobile ? AppTheme.borderRadiusM : AppTheme.borderRadiusL,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(isMobile),

              // Progress indicator
              _buildProgressIndicator(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                  ),
                  child: StepTransition(
                    currentStep: _currentStep,
                    reduceMotion: MediaQuery.of(context).disableAnimations,
                    child: _buildStepContent(clientDetection, isMobile),
                  ),
                ),
              ),

              // Footer with navigation buttons
              _buildFooter(clientDetection, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Semantics(
      label: 'Setup wizard header',
      child: Container(
        padding: EdgeInsets.all(
          isMobile ? AppTheme.spacingM : AppTheme.spacingL,
        ),
        decoration: BoxDecoration(
          gradient: AppTheme.headerGradient,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(
              isMobile ? AppTheme.borderRadiusM : AppTheme.borderRadiusL,
            ),
            topRight: Radius.circular(
              isMobile ? AppTheme.borderRadiusM : AppTheme.borderRadiusL,
            ),
          ),
        ),
        child: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        Semantics(
          label: 'Step icon: ${_steps[_currentStep].title}',
          child: Icon(_steps[_currentStep].icon, color: Colors.white, size: 32),
        ),
        SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Current step: ${_steps[_currentStep].title}',
                child: Text(
                  _steps[_currentStep].title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacingXS),
              Semantics(
                label: 'Progress: Step ${_currentStep + 1} of ${_steps.length}',
                child: Text(
                  'Step ${_currentStep + 1} of ${_steps.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.onDismiss != null)
          Semantics(
            label: 'Close setup wizard',
            button: true,
            child: IconButton(
              onPressed: _dismissWizard,
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close setup wizard',
              iconSize: 24,
            ),
          ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        Row(
          children: [
            Semantics(
              label: 'Step icon: ${_steps[_currentStep].title}',
              child: Icon(
                _steps[_currentStep].icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Semantics(
                label: 'Current step: ${_steps[_currentStep].title}',
                child: Text(
                  _steps[_currentStep].title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (widget.onDismiss != null)
              Semantics(
                label: 'Close setup wizard',
                button: true,
                child: IconButton(
                  onPressed: _dismissWizard,
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close setup wizard',
                  iconSize: 20,
                ),
              ),
          ],
        ),
        SizedBox(height: AppTheme.spacingXS),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: 'Progress: Step ${_currentStep + 1} of ${_steps.length}',
            child: Text(
              'Step ${_currentStep + 1} of ${_steps.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final progress = (_currentStep + 1) / _steps.length;
    final progressPercent = (progress * 100).round();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      child: Column(
        children: [
          AnimatedProgressBar(
            value: progress,
            backgroundColor: AppTheme.backgroundMain,
            valueColor: AppTheme.primaryColor,
            height: 4,
            reduceMotion: MediaQuery.of(context).disableAnimations,
            semanticLabel: 'Setup progress: $progressPercent percent complete',
          ),
          SizedBox(height: AppTheme.spacingXS),
          // Visual progress text for better accessibility
          Text(
            '$progressPercent% Complete',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(
    DesktopClientDetectionService clientDetection,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Step description',
          child: Text(
            _steps[_currentStep].description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textColor,
              height: 1.5,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
        ),
        SizedBox(height: isMobile ? AppTheme.spacingM : AppTheme.spacingL),
        _buildStepSpecificContent(clientDetection, isMobile),
      ],
    );
  }

  Widget _buildStepSpecificContent(
    DesktopClientDetectionService clientDetection,
    bool isMobile,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeContent(isMobile);
      case 1:
        return _buildContainerCreationContent(isMobile);
      case 2:
        return _buildRequirementContent(isMobile);
      case 3:
        return _buildDownloadContent(isMobile);
      case 4:
        return _buildInstallationContent(isMobile);
      case 5:
        return _buildVerificationContent(clientDetection, isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeContent(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'Welcome icon',
            child: Icon(
              Icons.waving_hand,
              size: isMobile ? 48 : 64,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: isMobile ? AppTheme.spacingM : AppTheme.spacingL),
          Semantics(
            label: 'Welcome message',
            child: Text(
              'Let\'s get you set up!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 20 : 24,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppTheme.spacingM),
          Semantics(
            label: 'Setup description',
            child: Text(
              'This wizard will guide you through connecting your local Ollama instance to this web interface.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textColorLight,
                fontSize: isMobile ? 14 : 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppTheme.spacingL),
          // Add accessibility tips for first-time users
          Container(
            padding: EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.infoColor.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.accessibility,
                      color: AppTheme.infoColor,
                      size: 20,
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Semantics(
                        label: 'Accessibility tip',
                        child: Text(
                          'Accessibility Tip',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.infoColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingXS),
                Semantics(
                  label: 'Navigation instructions',
                  child: Text(
                    'Use Tab to navigate between buttons, Enter or Space to activate them, and Escape to close dialogs.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.infoColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerCreationContent(bool isMobile) {
    return Consumer<UserContainerService>(
      builder: (context, containerService, child) {
        final isCreating = containerService.isCreatingContainer;
        final lastResult = containerService.lastCreationResult;
        final hasActiveContainer = containerService.hasActiveContainer;

        return Column(
          children: [
            // Container creation status with accessibility
            Semantics(
              label: _getContainerStatusAccessibilityLabel(
                lastResult,
                hasActiveContainer,
                isCreating,
              ),
              liveRegion: true,
              child: Container(
                padding: EdgeInsets.all(
                  isMobile ? AppTheme.spacingS : AppTheme.spacingM,
                ),
                decoration: BoxDecoration(
                  color: _getContainerStatusColor(
                    lastResult,
                    hasActiveContainer,
                  ).withValues(alpha: 0.1),
                  border: Border.all(
                    color: _getContainerStatusColor(
                      lastResult,
                      hasActiveContainer,
                    ).withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _getContainerStatusIcon(
                          lastResult,
                          hasActiveContainer,
                          isCreating,
                        ),
                        SizedBox(
                          width: isMobile
                              ? AppTheme.spacingS
                              : AppTheme.spacingM,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getContainerStatusTitle(
                                  lastResult,
                                  hasActiveContainer,
                                  isCreating,
                                ),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: _getContainerStatusColor(
                                        lastResult,
                                        hasActiveContainer,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 14 : 16,
                                    ),
                              ),
                              SizedBox(height: AppTheme.spacingXS),
                              Text(
                                _getContainerStatusDescription(
                                  lastResult,
                                  hasActiveContainer,
                                  isCreating,
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _getContainerStatusColor(
                                        lastResult,
                                        hasActiveContainer,
                                      ).withValues(alpha: 0.8),
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isCreating) ...[
                      SizedBox(height: AppTheme.spacingM),
                      LoadingAnimation(
                        message: 'Creating container...',
                        size: isMobile ? 20 : 24,
                        showMessage: false,
                        reduceMotion: MediaQuery.of(context).disableAnimations,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: isMobile ? AppTheme.spacingM : AppTheme.spacingL),

            // Container creation explanation
            Semantics(
              label: 'Information about streaming proxy containers',
              child: Container(
                padding: EdgeInsets.all(
                  isMobile ? AppTheme.spacingS : AppTheme.spacingM,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: isMobile ? 20 : 24,
                        ),
                        SizedBox(
                          width: isMobile
                              ? AppTheme.spacingS
                              : AppTheme.spacingM,
                        ),
                        Expanded(
                          child: Text(
                            'What is a streaming proxy container?',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Your streaming proxy container provides secure, isolated communication between this web interface and your local LLM. Each user gets their own ephemeral container for complete privacy and security.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.blue.shade700,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: isMobile ? AppTheme.spacingM : AppTheme.spacingL),

            // Action button with accessibility
            if (!hasActiveContainer && !isCreating)
              Center(
                child: AccessibleButton(
                  onPressed: () => _createUserContainer(containerService),
                  semanticLabel: 'Create container button',
                  tooltip: 'Create your secure streaming proxy container',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile
                          ? AppTheme.spacingM
                          : AppTheme.spacingL,
                      vertical: AppTheme.spacingM,
                    ),
                    minimumSize: Size(
                      isMobile ? 120 : 160,
                      44,
                    ), // Minimum touch target
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storage),
                      SizedBox(width: AppTheme.spacingS),
                      const Text('Create Container'),
                    ],
                  ),
                ),
              ),

            // Error handling with accessibility
            if (lastResult != null && lastResult.isFailure && !isCreating) ...[
              SizedBox(height: AppTheme.spacingM),
              ErrorAnimation(
                message: lastResult.errorMessage ?? 'Container creation failed',
                size: isMobile ? 48 : 64,
                reduceMotion: MediaQuery.of(context).disableAnimations,
                onRetry: () => _createUserContainer(containerService),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRequirementContent(bool isMobile) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 24),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  'The desktop client acts as a secure bridge between this web interface and your local Ollama installation.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppTheme.spacingL),
        _buildFeatureList(),
      ],
    );
  }

  Widget _buildFeatureList() {
    final features = [
      'Secure tunnel connection',
      'No data leaves your machine',
      'Works with any Ollama model',
      'Real-time streaming responses',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features
          .map(
            (feature) => Padding(
              padding: EdgeInsets.only(bottom: AppTheme.spacingS),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                  SizedBox(width: AppTheme.spacingS),
                  Text(
                    feature,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDownloadContent(bool isMobile) {
    return Consumer2<PlatformDetectionService, DownloadManagementService>(
      builder: (context, platformService, downloadService, child) {
        return Column(
          children: [
            // Platform detection status
            if (platformService.detectedPlatform != null) ...[
              Container(
                padding: EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                    SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform Detected: ${platformService.detectedPlatform!.displayName}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'We\'ve automatically detected your operating system.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppTheme.spacingL),
            ],

            // Download options for detected/selected platform
            Text(
              platformService.selectedPlatform != null
                  ? 'Download options for ${platformService.selectedPlatform!.displayName}:'
                  : platformService.detectedPlatform != null
                  ? 'Recommended downloads for ${platformService.detectedPlatform!.displayName}:'
                  : 'Choose your platform:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppTheme.spacingL),

            // Show download options for current platform
            if (platformService.currentPlatform != PlatformType.unknown)
              _buildDownloadOptions(platformService, downloadService)
            else
              _buildPlatformSelection(platformService),

            // Manual platform override option
            if (platformService.detectedPlatform != null &&
                platformService.selectedPlatform == null) ...[
              SizedBox(height: AppTheme.spacingL),
              TextButton.icon(
                onPressed: () => _showPlatformSelectionDialog(platformService),
                icon: const Icon(Icons.edit),
                label: const Text('Wrong platform? Choose manually'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDownloadOptions(
    PlatformDetectionService platformService,
    DownloadManagementService downloadService,
  ) {
    final downloadOptions = platformService.getDownloadOptions();

    if (downloadOptions.isEmpty) {
      return Container(
        padding: EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                'No download options available for this platform. Please visit our GitHub releases page.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.orange.shade700),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: downloadOptions
          .map(
            (option) => _buildDownloadOptionCard(
              option,
              platformService,
              downloadService,
            ),
          )
          .toList(),
    );
  }

  Widget _buildDownloadOptionCard(
    DownloadOption option,
    PlatformDetectionService platformService,
    DownloadManagementService downloadService,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: option.isRecommended
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : AppTheme.backgroundCard,
        border: Border.all(
          color: option.isRecommended
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.secondaryColor.withValues(alpha: 0.3),
          width: option.isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          option.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppTheme.textColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (option.isRecommended) ...[
                          SizedBox(width: AppTheme.spacingS),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      option.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Size: ${option.fileSize}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              ElevatedButton.icon(
                onPressed: () => _downloadOption(option, downloadService),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: option.isRecommended
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (option.requirements.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingS),
            Text(
              'Requirements:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            ...option.requirements.map(
              (req) => Padding(
                padding: EdgeInsets.only(left: AppTheme.spacingS, top: 2),
                child: Text(
                  '• $req',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformSelection(PlatformDetectionService platformService) {
    final supportedPlatforms = platformService.getSupportedPlatforms();

    return Column(
      children: supportedPlatforms
          .map(
            (platform) =>
                _buildPlatformSelectionButton(platform, platformService),
          )
          .toList(),
    );
  }

  Widget _buildPlatformSelectionButton(
    PlatformType platform,
    PlatformDetectionService platformService,
  ) {
    IconData icon;
    switch (platform) {
      case PlatformType.windows:
        icon = Icons.desktop_windows;
        break;
      case PlatformType.macos:
        icon = Icons.laptop_mac;
        break;
      case PlatformType.linux:
        icon = Icons.computer;
        break;
      default:
        icon = Icons.help_outline;
    }

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingM),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => platformService.selectPlatform(platform),
          icon: Icon(icon),
          label: Text('Select ${platform.displayName}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.all(AppTheme.spacingM),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            ),
          ),
        ),
      ),
    );
  }

  void _showPlatformSelectionDialog(PlatformDetectionService platformService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Platform'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: platformService
              .getSupportedPlatforms()
              .map(
                (platform) => ListTile(
                  leading: Icon(_getPlatformIcon(platform)),
                  title: Text(platform.displayName),
                  onTap: () {
                    platformService.selectPlatform(platform);
                    Navigator.of(context).pop();
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (platformService.selectedPlatform != null)
            TextButton(
              onPressed: () {
                platformService.clearPlatformSelection();
                Navigator.of(context).pop();
              },
              child: const Text('Use Auto-Detection'),
            ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(PlatformType platform) {
    switch (platform) {
      case PlatformType.windows:
        return Icons.desktop_windows;
      case PlatformType.macos:
        return Icons.laptop_mac;
      case PlatformType.linux:
        return Icons.computer;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _downloadOption(
    DownloadOption option,
    DownloadManagementService downloadService,
  ) async {
    try {
      // Track the download event
      downloadService.trackDownloadEvent(
        'wizard_user', // In a real app, this would be the actual user ID
        option.installationType,
        option.installationType,
      );

      // Open the download URL
      final url = Uri.parse(option.downloadUrl);

      // For all platforms, use url_launcher
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch download URL');
      }

      debugPrint('� [SetupWizard] Download initiated: ${option.downloadUrl}');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download started: ${option.name}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('� [SetupWizard] Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInstallationContent(bool isMobile) {
    return Consumer<PlatformDetectionService>(
      builder: (context, platformService, child) {
        final platformConfig = platformService.getPlatformConfig();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Installation Instructions for ${platformService.currentPlatform.displayName}:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppTheme.spacingM),

              if (platformConfig != null)
                _buildPlatformSpecificSteps(platformConfig)
              else
                _buildGenericInstallationSteps(),

              SizedBox(height: AppTheme.spacingL),

              // Troubleshooting section
              if (platformConfig != null &&
                  platformConfig.troubleshootingGuides.isNotEmpty)
                _buildTroubleshootingSection(platformConfig),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlatformSpecificSteps(PlatformConfig platformConfig) {
    // Get installation steps for the most common installation type
    final recommendedOption = platformConfig.recommendedDownload;
    final installationType = recommendedOption?.installationType ?? 'default';
    final steps = platformConfig.getInstallationSteps(installationType);

    if (steps.isEmpty) {
      return _buildGenericInstallationSteps();
    }

    return Column(
      children: steps.map((step) => _buildInstallationStepCard(step)).toList(),
    );
  }

  Widget _buildInstallationStepCard(InstallationStep step) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${step.order + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (step.isOptional)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OPTIONAL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            step.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
          ),

          // Commands section
          if (step.commands.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingS),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commands:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingXS),
                  ...step.commands.map(
                    (command) => Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text(
                        command,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade300,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Troubleshooting tips
          if (step.troubleshootingTips.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingS),
            ExpansionTile(
              title: Text(
                'Troubleshooting Tips',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: Icon(Icons.help_outline, color: Colors.orange),
              children: step.troubleshootingTips
                  .map(
                    (tip) => ListTile(
                      leading: Icon(
                        Icons.lightbulb_outline,
                        color: Colors.orange,
                        size: 16,
                      ),
                      title: Text(
                        tip,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textColor,
                        ),
                      ),
                      dense: true,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenericInstallationSteps() {
    final steps = [
      'Download the desktop client for your platform',
      'Run the installer or extract the portable version',
      'Launch the CloudToLocalLLM desktop application',
      'The client will automatically connect to this web interface',
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;

        return Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spacingM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  step,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTroubleshootingSection(PlatformConfig platformConfig) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange, size: 24),
              SizedBox(width: AppTheme.spacingM),
              Text(
                'Common Issues & Solutions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingS),
          ...platformConfig.troubleshootingGuides.entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(bottom: AppTheme.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.replaceAll('_', ' ').toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationContent(
    DesktopClientDetectionService clientDetection,
    bool isMobile,
  ) {
    final hasConnectedClients = clientDetection.hasConnectedClients;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Desktop Client Status
          _buildConnectionStatusCard(
            title: 'Desktop Client Connection',
            isConnected: hasConnectedClients,
            connectedMessage: 'Desktop client is connected and ready',
            waitingMessage: 'Waiting for desktop client connection...',
            icon: Icons.desktop_windows,
          ),

          SizedBox(height: AppTheme.spacingM),

          // Tunnel Configuration Status
          _buildTunnelConfigurationCard(hasConnectedClients),

          SizedBox(height: AppTheme.spacingM),

          // Connection Validation Status
          _buildConnectionValidationCard(
            hasConnectedClients && _tunnelConfigured,
          ),

          if (hasConnectedClients &&
              _tunnelConfigured &&
              _connectionValidated) ...[
            SizedBox(height: AppTheme.spacingL),
            Center(
              child: ElevatedButton.icon(
                onPressed: _completeWizard,
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete Setup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                    vertical: AppTheme.spacingM,
                  ),
                ),
              ),
            ),
          ],

          if (!hasConnectedClients) ...[
            SizedBox(height: AppTheme.spacingL),
            _buildConnectionInstructions(),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionStatusCard({
    required String title,
    required bool isConnected,
    required String connectedMessage,
    required String waitingMessage,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.pending,
              size: 32,
              color: isConnected
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
            ),
            SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    isConnected ? connectedMessage : waitingMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textColorLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, color: AppTheme.textColorLight),
          ],
        ),
      ),
    );
  }

  Widget _buildTunnelConfigurationCard(bool hasConnectedClients) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _tunnelConfigured
                      ? Icons.check_circle
                      : _isTunnelConfiguring || _isTunnelValidating
                      ? Icons.sync
                      : Icons.pending,
                  size: 32,
                  color: _tunnelConfigured
                      ? AppTheme.successColor
                      : _tunnelError != null
                      ? AppTheme.dangerColor
                      : AppTheme.warningColor,
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tunnel Configuration',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: AppTheme.spacingS),
                      Text(
                        _getTunnelStatusMessage(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textColorLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.vpn_lock, color: AppTheme.textColorLight),
              ],
            ),

            if (_tunnelError != null) ...[
              SizedBox(height: AppTheme.spacingM),
              Container(
                padding: EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.dangerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: AppTheme.dangerColor, size: 16),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        _tunnelError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.dangerColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (hasConnectedClients &&
                !_tunnelConfigured &&
                !_isTunnelConfiguring &&
                !_isTunnelValidating) ...[
              SizedBox(height: AppTheme.spacingM),
              ElevatedButton.icon(
                onPressed: _configureTunnel,
                icon: const Icon(Icons.settings),
                label: const Text('Configure Tunnel'),
              ),
            ],

            if (_isTunnelConfiguring || _isTunnelValidating) ...[
              SizedBox(height: AppTheme.spacingM),
              LinearProgressIndicator(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionValidationCard(bool canValidate) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _connectionValidated
                      ? Icons.check_circle
                      : _isValidatingConnection
                      ? Icons.sync
                      : Icons.pending,
                  size: 32,
                  color: _connectionValidated
                      ? AppTheme.successColor
                      : _validationError != null
                      ? AppTheme.dangerColor
                      : AppTheme.warningColor,
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Validation',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: AppTheme.spacingS),
                      Text(
                        _getValidationStatusMessage(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textColorLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.verified_user, color: AppTheme.textColorLight),
              ],
            ),

            if (_validationError != null) ...[
              SizedBox(height: AppTheme.spacingM),
              Container(
                padding: EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.dangerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: AppTheme.dangerColor, size: 16),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.dangerColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (canValidate &&
                !_connectionValidated &&
                !_isValidatingConnection) ...[
              SizedBox(height: AppTheme.spacingM),
              ElevatedButton.icon(
                onPressed: _validateConnection,
                icon: const Icon(Icons.verified_user),
                label: const Text('Validate Connection'),
              ),
            ],

            if (_isValidatingConnection) ...[
              SizedBox(height: AppTheme.spacingM),
              LinearProgressIndicator(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionInstructions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: AppTheme.primaryColor),
                SizedBox(width: AppTheme.spacingS),
                Text(
                  'Connection Instructions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'To complete the setup:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: AppTheme.spacingS),
            _buildInstructionStep(
              '1',
              'Launch the CloudToLocalLLM desktop client',
            ),
            _buildInstructionStep(
              '2',
              'Ensure Ollama is running on your system',
            ),
            _buildInstructionStep(
              '3',
              'Wait for the connection to be established',
            ),
            _buildInstructionStep(
              '4',
              'The tunnel will be configured automatically',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String instruction) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              instruction,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _getTunnelStatusMessage() {
    if (_tunnelConfigured) {
      return 'Tunnel is configured and ready for secure communication';
    } else if (_isTunnelValidating) {
      return 'Validating tunnel connection...';
    } else if (_isTunnelConfiguring) {
      return 'Configuring secure tunnel...';
    } else if (_tunnelError != null) {
      return 'Tunnel configuration failed';
    } else {
      return 'Tunnel configuration pending';
    }
  }

  String _getValidationStatusMessage() {
    if (_connectionValidated) {
      return 'All connection tests passed successfully';
    } else if (_isValidatingConnection) {
      return 'Running comprehensive connection tests...';
    } else if (_validationError != null) {
      return 'Connection validation failed';
    } else {
      return 'Connection validation pending';
    }
  }

  Future<void> _configureTunnel() async {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.id;

    if (userId == null) {
      setState(() {
        _tunnelError = 'User not authenticated';
      });
      return;
    }

    setState(() {
      _isTunnelConfiguring = true;
      _tunnelError = null;
    });

    try {
      // Get tunnel service from provider
      final tunnelService = Provider.of<TunnelService>(context, listen: false);

      // Connect tunnel
      await tunnelService.connect();

      setState(() {
        _isTunnelConfiguring = false;
        _isTunnelValidating = true;
      });

      // Test tunnel connection
      final success = await tunnelService.testConnection();

      setState(() {
        _isTunnelValidating = false;
        _tunnelConfigured = success;
        if (!success) {
          _tunnelError = 'Connection test failed';
        }
      });

      if (success) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: AppTheme.spacingS),
                  const Expanded(
                    child: Text('Tunnel configured successfully!'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isTunnelConfiguring = false;
        _isTunnelValidating = false;
        _tunnelError = 'Configuration failed: ${e.toString()}';
      });
    }
  }

  Future<void> _validateConnection() async {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.id;

    if (userId == null) {
      setState(() {
        _validationError = 'User not authenticated';
      });
      return;
    }

    setState(() {
      _isValidatingConnection = true;
      _validationError = null;
    });

    try {
      // Create connection validation service
      final validationService = ConnectionValidationService(
        authService: authService,
      );

      // Run comprehensive validation
      final validationResult = await validationService
          .runComprehensiveValidation(userId);

      setState(() {
        _isValidatingConnection = false;
        _connectionValidated = validationResult.isSuccess;
        if (!validationResult.isSuccess) {
          _validationError = validationResult.message;
        }
      });

      if (validationResult.isSuccess) {
        // Show success message with test details
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'All ${validationResult.tests.length} validation tests passed!',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Show detailed error information
        final failedTests = validationResult.failedTests;
        if (mounted && failedTests.isNotEmpty) {
          _showValidationDetailsDialog(validationResult);
        }
      }
    } catch (e) {
      setState(() {
        _isValidatingConnection = false;
        _validationError = 'Validation failed: ${e.toString()}';
      });
    }
  }

  void _showValidationDetailsDialog(dynamic validationResult) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation Results'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tests: ${validationResult.successfulTestCount}/${validationResult.tests.length} passed',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppTheme.spacingM),
              if (validationResult.failedTests.isNotEmpty) ...[
                Text(
                  'Failed Tests:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dangerColor,
                  ),
                ),
                SizedBox(height: AppTheme.spacingS),
                ...validationResult.failedTests
                    .map<Widget>(
                      (test) => Padding(
                        padding: EdgeInsets.only(bottom: AppTheme.spacingS),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error,
                              color: AppTheme.dangerColor,
                              size: 16,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    test.name,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    test.message,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _validateConnection(); // Retry validation
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    DesktopClientDetectionService clientDetection,
    bool isMobile,
  ) {
    return Consumer<UserContainerService>(
      builder: (context, containerService, child) {
        final canProceed = _canProceedToNextStep(
          containerService,
          clientDetection,
        );

        return Semantics(
          label: 'Navigation controls',
          child: Container(
            padding: EdgeInsets.all(
              isMobile ? AppTheme.spacingM : AppTheme.spacingL,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: isMobile
                ? _buildMobileFooter(canProceed)
                : _buildDesktopFooter(canProceed),
          ),
        );
      },
    );
  }

  Widget _buildDesktopFooter(bool canProceed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          Semantics(
            label: 'Go to previous step',
            button: true,
            child: TextButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: TextButton.styleFrom(minimumSize: const Size(100, 44)),
            ),
          )
        else
          const SizedBox.shrink(),

        Row(
          children: [
            if (widget.onDismiss != null && _currentStep < _steps.length - 1)
              Semantics(
                label: 'Skip setup wizard for now',
                button: true,
                child: TextButton(
                  onPressed: _dismissWizard,
                  style: TextButton.styleFrom(minimumSize: const Size(100, 44)),
                  child: const Text('Skip for now'),
                ),
              ),
            SizedBox(width: AppTheme.spacingM),
            if (_currentStep < _steps.length - 1)
              Semantics(
                label: canProceed
                    ? 'Go to next step'
                    : 'Next step disabled, complete current step first',
                button: true,
                child: AnimatedActionButton(
                  onPressed: canProceed ? _nextStep : null,
                  reduceMotion: MediaQuery.of(context).disableAnimations,
                  semanticLabel: canProceed
                      ? 'Go to next step'
                      : 'Next step disabled, complete current step first',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 44),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_forward),
                      SizedBox(width: AppTheme.spacingXS),
                      const Text('Next'),
                    ],
                  ),
                ),
              )
            else
              Semantics(
                label: 'Complete setup wizard',
                button: true,
                child: AnimatedActionButton(
                  onPressed: _completeWizard,
                  reduceMotion: MediaQuery.of(context).disableAnimations,
                  semanticLabel: 'Complete setup wizard',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 44),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check),
                      SizedBox(width: AppTheme.spacingXS),
                      const Text('Complete Setup'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFooter(bool canProceed) {
    return Column(
      children: [
        // Primary action button (full width on mobile)
        SizedBox(
          width: double.infinity,
          child: _currentStep < _steps.length - 1
              ? AnimatedActionButton(
                  onPressed: canProceed ? _nextStep : null,
                  reduceMotion: MediaQuery.of(context).disableAnimations,
                  semanticLabel: canProceed
                      ? 'Go to next step'
                      : 'Next step disabled, complete current step first',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward),
                      SizedBox(width: AppTheme.spacingXS),
                      const Text('Next'),
                    ],
                  ),
                )
              : AnimatedActionButton(
                  onPressed: _completeWizard,
                  reduceMotion: MediaQuery.of(context).disableAnimations,
                  semanticLabel: 'Complete setup wizard',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check),
                      SizedBox(width: AppTheme.spacingXS),
                      const Text('Complete Setup'),
                    ],
                  ),
                ),
        ),

        // Secondary actions row
        if (_currentStep > 0 ||
            (widget.onDismiss != null && _currentStep < _steps.length - 1)) ...[
          SizedBox(height: AppTheme.spacingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: Semantics(
                    label: 'Go to previous step',
                    button: true,
                    child: TextButton.icon(
                      onPressed: _previousStep,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                ),
              if (_currentStep > 0 &&
                  widget.onDismiss != null &&
                  _currentStep < _steps.length - 1)
                SizedBox(width: AppTheme.spacingS),
              if (widget.onDismiss != null && _currentStep < _steps.length - 1)
                Expanded(
                  child: Semantics(
                    label: 'Skip setup wizard for now',
                    button: true,
                    child: TextButton(
                      onPressed: _dismissWizard,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      child: const Text('Skip for now'),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _dismissWizard() {
    setState(() {
      _isDismissed = true;
    });
    widget.onDismiss?.call();
  }

  String _getContainerStatusAccessibilityLabel(
    ContainerCreationResult? result,
    bool hasActiveContainer,
    bool isCreating,
  ) {
    if (isCreating) {
      return 'Creating container, please wait';
    } else if (hasActiveContainer) {
      return 'Container created successfully and is active';
    } else if (result != null && result.isFailure) {
      return 'Container creation failed: ${result.errorMessage ?? "Unknown error"}';
    } else {
      return 'Container not yet created';
    }
  }

  void _completeWizard() {
    // Show celebration animation before completing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: CelebrationAnimation(
          message: 'Setup Complete!',
          reduceMotion: MediaQuery.of(context).disableAnimations,
          onComplete: () {
            Navigator.of(context).pop();
            setState(() {
              _isDismissed = true;
            });
            widget.onComplete?.call();
          },
        ),
      ),
    );
  }

  // Container creation helper methods
  Future<void> _createUserContainer(
    UserContainerService containerService,
  ) async {
    try {
      final result = await containerService.createUserContainer();

      if (result.isSuccess) {
        // Automatically proceed to next step after successful container creation
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _nextStep();
          }
        });
      }
    } catch (e) {
      debugPrint('Container creation error: $e');
      // Error is handled by the UI through the service state
    }
  }

  Color _getContainerStatusColor(
    ContainerCreationResult? result,
    bool hasActiveContainer,
  ) {
    if (hasActiveContainer || (result?.isSuccess == true)) {
      return AppTheme.successColor;
    } else if (result?.isFailure == true) {
      return Colors.red;
    } else {
      return AppTheme.warningColor;
    }
  }

  Widget _getContainerStatusIcon(
    ContainerCreationResult? result,
    bool hasActiveContainer,
    bool isCreating,
  ) {
    if (isCreating) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    } else if (hasActiveContainer || (result?.isSuccess == true)) {
      return Icon(Icons.check_circle, color: AppTheme.successColor, size: 24);
    } else if (result?.isFailure == true) {
      return Icon(Icons.error, color: Colors.red, size: 24);
    } else {
      return Icon(Icons.storage, color: AppTheme.warningColor, size: 24);
    }
  }

  String _getContainerStatusTitle(
    ContainerCreationResult? result,
    bool hasActiveContainer,
    bool isCreating,
  ) {
    if (isCreating) {
      return 'Creating Container...';
    } else if (hasActiveContainer || (result?.isSuccess == true)) {
      return 'Container Ready';
    } else if (result?.isFailure == true) {
      return 'Container Creation Failed';
    } else {
      return 'Container Not Created';
    }
  }

  String _getContainerStatusDescription(
    ContainerCreationResult? result,
    bool hasActiveContainer,
    bool isCreating,
  ) {
    if (isCreating) {
      return 'Setting up your secure streaming proxy container...';
    } else if (hasActiveContainer || (result?.isSuccess == true)) {
      return 'Your streaming proxy container is ready for secure communication.';
    } else if (result?.isFailure == true) {
      return result?.errorMessage ??
          'Failed to create container. Please try again.';
    } else {
      return 'Click the button below to create your streaming proxy container.';
    }
  }

  bool _canProceedToNextStep(
    UserContainerService containerService,
    DesktopClientDetectionService clientDetection,
  ) {
    switch (_currentStep) {
      case 0: // Welcome step
        return true;
      case 1: // Container creation step
        return containerService.hasActiveContainer ||
            (containerService.lastCreationResult?.isSuccess == true);
      case 2: // Desktop client requirement step
        return true;
      case 3: // Download step
        return true;
      case 4: // Installation step
        return true;
      case 5: // Verification step
        return clientDetection.hasConnectedClients;
      default:
        return true;
    }
  }

  /// Build desktop-specific setup wizard dialog
  Widget _buildDesktopWizardDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 500,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Welcome to CloudToLocalLLM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _dismissWizard,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Let\'s get you set up!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CloudToLocalLLM connects to your local Ollama instance to provide secure, private AI conversations. Let\'s configure your setup.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    _buildDesktopSetupSteps(),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _dismissWizard,
                    child: const Text('Skip Setup'),
                  ),
                  ElevatedButton(
                    onPressed: _completeDesktopSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start Setup'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build desktop setup steps
  Widget _buildDesktopSetupSteps() {
    final steps = [
      'Configure Ollama connection',
      'Set up authentication',
      'Test local model access',
      'Complete initial configuration',
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(step, style: const TextStyle(fontSize: 14))),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Complete desktop setup
  void _completeDesktopSetup() {
    // Mark wizard as seen and setup as completed
    widget.onComplete?.call();
    _dismissWizard();
  }
}

/// Data class for setup wizard steps
class SetupStep {
  final String title;
  final String description;
  final IconData icon;

  const SetupStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
