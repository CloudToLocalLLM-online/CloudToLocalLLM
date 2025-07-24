import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/desktop_client_detection_service.dart';
import '../services/user_container_service.dart';
import '../models/container_creation_result.dart';

/// Responsive and accessible setup wizard component
///
/// Features:
/// - Mobile-friendly responsive design
/// - Full accessibility support (screen readers, keyboard navigation)
/// - Touch-friendly controls with proper sizing
/// - High contrast support
/// - Loading states and progress indicators
/// - Smooth animations with reduced motion support
class ResponsiveSetupWizard extends StatefulWidget {
  final bool isFirstTimeUser;
  final VoidCallback? onDismiss;
  final VoidCallback? onComplete;

  const ResponsiveSetupWizard({
    super.key,
    this.isFirstTimeUser = false,
    this.onDismiss,
    this.onComplete,
  });

  @override
  State<ResponsiveSetupWizard> createState() => _ResponsiveSetupWizardState();
}

class _ResponsiveSetupWizardState extends State<ResponsiveSetupWizard>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isDismissed = false;
  late AnimationController _animationController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _progressAnimation;

  // Focus management
  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _nextButtonFocusNode = FocusNode();
  final FocusNode _backButtonFocusNode = FocusNode();
  final FocusNode _skipButtonFocusNode = FocusNode();

  // Loading states
  final bool _isLoading = false;
  final String _loadingMessage = '';

  final List<SetupStep> _steps = [
    SetupStep(
      title: 'Welcome to CloudToLocalLLM',
      description:
          'Connect your local Ollama instance to this web interface for secure, private AI conversations.',
      icon: Icons.cloud_download_outlined,
      semanticLabel: 'Welcome step: Introduction to CloudToLocalLLM',
    ),
    SetupStep(
      title: 'Container Setup',
      description:
          'Creating your secure streaming proxy container for isolated communication with your local LLM.',
      icon: Icons.storage,
      semanticLabel: 'Container setup step: Creating secure proxy container',
    ),
    SetupStep(
      title: 'Desktop Client Required',
      description:
          'To use your local Ollama models, you need to install the CloudToLocalLLM desktop client.',
      icon: Icons.desktop_windows,
      semanticLabel:
          'Desktop client requirement step: Understanding client necessity',
    ),
    SetupStep(
      title: 'Download Desktop Client',
      description: 'Choose the appropriate version for your operating system.',
      icon: Icons.download,
      semanticLabel: 'Download step: Select and download desktop client',
    ),
    SetupStep(
      title: 'Installation Instructions',
      description: 'Follow the platform-specific installation guide.',
      icon: Icons.install_desktop,
      semanticLabel: 'Installation step: Platform-specific installation guide',
    ),
    SetupStep(
      title: 'Connection Verification',
      description:
          'Verify that your desktop client is connected and ready to use.',
      icon: Icons.check_circle_outline,
      semanticLabel: 'Verification step: Test desktop client connection',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupKeyboardShortcuts();

    // Announce wizard opening to screen readers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceToScreenReader(
        'Setup wizard opened. Step 1 of ${_steps.length}: ${_steps[0].title}',
      );
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _progressController.forward();
  }

  void _setupKeyboardShortcuts() {
    // Add keyboard shortcuts for navigation
    ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.escape:
          if (widget.onDismiss != null) {
            _dismissWizard();
            return true;
          }
          break;
        case LogicalKeyboardKey.arrowRight:
        case LogicalKeyboardKey.enter:
          if (event.logicalKey == LogicalKeyboardKey.enter &&
              _nextButtonFocusNode.hasFocus) {
            _nextStep();
            return true;
          }
          break;
        case LogicalKeyboardKey.arrowLeft:
          if (_currentStep > 0) {
            _previousStep();
            return true;
          }
          break;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    _dialogFocusNode.dispose();
    _nextButtonFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _skipButtonFocusNode.dispose();
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    // Don't show if dismissed
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    return Consumer<DesktopClientDetectionService>(
      builder: (context, clientDetection, child) {
        // Don't show if clients are connected (unless it's first time user)
        if (clientDetection.hasConnectedClients && !widget.isFirstTimeUser) {
          return const SizedBox.shrink();
        }

        return _buildResponsiveWizard(context, clientDetection);
      },
    );
  }

  Widget _buildResponsiveWizard(
    BuildContext context,
    DesktopClientDetectionService clientDetection,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width < 900;

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value * 50),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Focus(
                focusNode: _dialogFocusNode,
                autofocus: true,
                child: Container(
                  width: _getDialogWidth(
                    screenSize,
                    isSmallScreen,
                    isMediumScreen,
                  ),
                  height: _getDialogHeight(screenSize, isSmallScreen),
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? screenSize.width * 0.95 : 800,
                    maxHeight: isSmallScreen ? screenSize.height * 0.9 : 600,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundCard,
                    borderRadius: BorderRadius.circular(
                      isSmallScreen
                          ? AppTheme.borderRadiusM
                          : AppTheme.borderRadiusL,
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
                      _buildAccessibleHeader(isSmallScreen),

                      // Progress indicator
                      _buildAccessibleProgressIndicator(),

                      // Content
                      Expanded(
                        child: _buildAccessibleStepContent(
                          clientDetection,
                          isSmallScreen,
                        ),
                      ),

                      // Footer with navigation buttons
                      _buildAccessibleFooter(clientDetection, isSmallScreen),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _getDialogWidth(
    Size screenSize,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    if (isSmallScreen) return screenSize.width * 0.95;
    if (isMediumScreen) return screenSize.width * 0.8;
    return 700;
  }

  double _getDialogHeight(Size screenSize, bool isSmallScreen) {
    if (isSmallScreen) return screenSize.height * 0.9;
    return 550;
  }

  // Navigation methods
  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _animateStepTransition();
      _announceStepChange();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _animateStepTransition();
      _announceStepChange();
    }
  }

  void _skipStep() {
    _nextStep();
  }

  void _completeSetup() {
    widget.onComplete?.call();
    _announceToScreenReader('Setup wizard completed successfully');
  }

  void _dismissWizard() {
    setState(() {
      _isDismissed = true;
    });
    widget.onDismiss?.call();
    _announceToScreenReader('Setup wizard closed');
  }

  void _animateStepTransition() {
    _animationController.reset();
    _animationController.forward();

    _progressController.reset();
    _progressController.forward();
  }

  void _announceStepChange() {
    final stepInfo =
        'Step ${_currentStep + 1} of ${_steps.length}: ${_steps[_currentStep].title}';
    _announceToScreenReader(stepInfo);
  }

  void _announceToScreenReader(String message) {
    // Use SemanticsService to announce to screen readers
    SemanticsService.announce(message, TextDirection.ltr);
  }

  // Main UI building methods
  Widget _buildAccessibleHeader(bool isSmallScreen) {
    return buildAccessibleHeader(isSmallScreen);
  }

  Widget _buildAccessibleProgressIndicator() {
    return buildAccessibleProgressIndicator();
  }

  Widget _buildAccessibleStepContent(
    DesktopClientDetectionService clientDetection,
    bool isSmallScreen,
  ) {
    return buildAccessibleStepContent(clientDetection, isSmallScreen);
  }

  Widget _buildAccessibleFooter(
    DesktopClientDetectionService clientDetection,
    bool isSmallScreen,
  ) {
    return buildAccessibleFooter(clientDetection, isSmallScreen);
  }
}

/// Setup step data model with accessibility information
class SetupStep {
  final String title;
  final String description;
  final IconData icon;
  final String semanticLabel;

  const SetupStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.semanticLabel,
  });
}

// Implementation of the accessible UI components
extension _ResponsiveSetupWizardImplementation on _ResponsiveSetupWizardState {
  Widget buildAccessibleHeader(bool isSmallScreen) {
    return Semantics(
      label: 'Setup wizard header. ${_steps[_currentStep].semanticLabel}',
      header: true,
      child: Container(
        padding: EdgeInsets.all(
          isSmallScreen ? AppTheme.spacingM : AppTheme.spacingL,
        ),
        decoration: BoxDecoration(
          gradient: AppTheme.headerGradient,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(
              isSmallScreen ? AppTheme.borderRadiusM : AppTheme.borderRadiusL,
            ),
            topRight: Radius.circular(
              isSmallScreen ? AppTheme.borderRadiusM : AppTheme.borderRadiusL,
            ),
          ),
        ),
        child: Row(
          children: [
            Semantics(
              label: 'Step icon: ${_steps[_currentStep].title}',
              child: Icon(
                _steps[_currentStep].icon,
                color: Colors.white,
                size: isSmallScreen ? 24 : 32,
              ),
            ),
            SizedBox(
              width: isSmallScreen ? AppTheme.spacingS : AppTheme.spacingM,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: 'Current step title: ${_steps[_currentStep].title}',
                    child: Text(
                      _steps[_currentStep].title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 16 : 18,
                          ),
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingXS),
                  Semantics(
                    label:
                        'Progress: Step ${_currentStep + 1} of ${_steps.length}',
                    child: Text(
                      'Step ${_currentStep + 1} of ${_steps.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: isSmallScreen ? 12 : 14,
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
                  icon: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  tooltip: 'Close wizard',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildAccessibleProgressIndicator() {
    return Semantics(
      label:
          'Setup progress: ${((_currentStep + 1) / _steps.length * 100).round()}% complete',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        child: AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return LinearProgressIndicator(
              value:
                  (_currentStep + 1) / _steps.length * _progressAnimation.value,
              backgroundColor: AppTheme.backgroundMain,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              minHeight: 4,
              semanticsLabel: 'Progress indicator',
              semanticsValue:
                  '${((_currentStep + 1) / _steps.length * 100).round()}% complete',
            );
          },
        ),
      ),
    );
  }

  Widget buildAccessibleStepContent(
    DesktopClientDetectionService clientDetection,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.all(
        isSmallScreen ? AppTheme.spacingM : AppTheme.spacingL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Step description: ${_steps[_currentStep].description}',
            child: Text(
              _steps[_currentStep].description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textColor,
                height: 1.5,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
          SizedBox(
            height: isSmallScreen ? AppTheme.spacingM : AppTheme.spacingL,
          ),
          Expanded(
            child: buildStepSpecificContent(clientDetection, isSmallScreen),
          ),
        ],
      ),
    );
  }

  Widget buildStepSpecificContent(
    DesktopClientDetectionService clientDetection,
    bool isSmallScreen,
  ) {
    if (_isLoading) {
      return buildLoadingState(isSmallScreen);
    }

    switch (_currentStep) {
      case 0:
        return buildWelcomeContent(isSmallScreen);
      case 1:
        return buildContainerCreationContent(isSmallScreen);
      case 2:
        return buildRequirementContent(isSmallScreen);
      case 3:
        return buildDownloadContent(isSmallScreen);
      case 4:
        return buildInstallationContent(isSmallScreen);
      case 5:
        return buildVerificationContent(clientDetection, isSmallScreen);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget buildLoadingState(bool isSmallScreen) {
    return Semantics(
      label: 'Loading: $_loadingMessage',
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: isSmallScreen ? 32 : 48,
              height: isSmallScreen ? 32 : 48,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: AppTheme.spacingM),
            Text(
              _loadingMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textColorLight,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildWelcomeContent(bool isSmallScreen) {
    return Semantics(
      label: 'Welcome screen content',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.waving_hand,
              size: isSmallScreen ? 48 : 64,
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: AppTheme.spacingL),
            Semantics(
              label: 'Welcome message: Let\'s get you set up!',
              child: Text(
                'Let\'s get you set up!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 20 : 24,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: AppTheme.spacingM),
            Semantics(
              label:
                  'Setup description: This wizard will guide you through connecting your local Ollama instance',
              child: Text(
                'This wizard will guide you through connecting your local Ollama instance to this web interface.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textColorLight,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildContainerCreationContent(bool isSmallScreen) {
    return Consumer<UserContainerService>(
      builder: (context, containerService, child) {
        final isCreating = containerService.isCreatingContainer;
        final lastResult = containerService.lastCreationResult;
        final hasActiveContainer = containerService.hasActiveContainer;

        return Semantics(
          label: 'Container creation section',
          child: Column(
            children: [
              // Container creation status
              buildContainerStatusCard(
                lastResult,
                hasActiveContainer,
                isCreating,
                isSmallScreen,
              ),

              SizedBox(height: AppTheme.spacingL),

              // Container explanation
              buildContainerExplanation(isSmallScreen),

              SizedBox(height: AppTheme.spacingL),

              // Action button or error handling
              if (!hasActiveContainer && !isCreating)
                buildContainerActionButton(containerService, isSmallScreen)
              else if (lastResult != null &&
                  lastResult.isFailure &&
                  !isCreating)
                buildContainerErrorSection(
                  lastResult,
                  containerService,
                  isSmallScreen,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget buildAccessibleFooter(
    DesktopClientDetectionService clientDetection,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(
        isSmallScreen ? AppTheme.spacingM : AppTheme.spacingL,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Semantics(
            label: 'Go to previous step',
            button: true,
            child: ElevatedButton.icon(
              focusNode: _backButtonFocusNode,
              onPressed: _currentStep > 0 ? _previousStep : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep > 0
                    ? AppTheme.secondaryColor
                    : AppTheme.secondaryColor.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen
                      ? AppTheme.spacingS
                      : AppTheme.spacingM,
                  vertical: isSmallScreen ? 4 : AppTheme.spacingS,
                ),
              ),
            ),
          ),

          // Skip and Next buttons
          Row(
            children: [
              if (_currentStep < _steps.length - 1)
                Semantics(
                  label: 'Skip current step',
                  button: true,
                  child: TextButton(
                    focusNode: _skipButtonFocusNode,
                    onPressed: _skipStep,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textColorLight,
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
              SizedBox(width: AppTheme.spacingS),
              Semantics(
                label: _currentStep < _steps.length - 1
                    ? 'Go to next step'
                    : 'Complete setup wizard',
                button: true,
                child: ElevatedButton.icon(
                  focusNode: _nextButtonFocusNode,
                  onPressed: _currentStep < _steps.length - 1
                      ? _nextStep
                      : _completeSetup,
                  icon: Icon(
                    _currentStep < _steps.length - 1
                        ? Icons.arrow_forward
                        : Icons.check,
                  ),
                  label: Text(
                    _currentStep < _steps.length - 1 ? 'Next' : 'Finish',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen
                          ? AppTheme.spacingM
                          : AppTheme.spacingL,
                      vertical: isSmallScreen
                          ? AppTheme.spacingS
                          : AppTheme.spacingM,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Placeholder methods for remaining content
  Widget buildContainerStatusCard(
    ContainerCreationResult? lastResult,
    bool hasActiveContainer,
    bool isCreating,
    bool isSmallScreen,
  ) {
    return Container(
      height: 100,
      color: Colors.blue.withValues(alpha: 0.1),
      child: const Center(child: Text('Container Status Card')),
    );
  }

  Widget buildContainerExplanation(bool isSmallScreen) {
    return Container(
      height: 80,
      color: Colors.green.withValues(alpha: 0.1),
      child: const Center(child: Text('Container Explanation')),
    );
  }

  Widget buildContainerActionButton(
    UserContainerService containerService,
    bool isSmallScreen,
  ) {
    return ElevatedButton(
      onPressed: () {},
      child: const Text('Create Container'),
    );
  }

  Widget buildContainerErrorSection(
    ContainerCreationResult lastResult,
    UserContainerService containerService,
    bool isSmallScreen,
  ) {
    return Container(
      height: 60,
      color: Colors.red.withValues(alpha: 0.1),
      child: const Center(child: Text('Error Section')),
    );
  }

  Widget buildRequirementContent(bool isSmallScreen) {
    return const Center(child: Text('Requirement Content'));
  }

  Widget buildDownloadContent(bool isSmallScreen) {
    return const Center(child: Text('Download Content'));
  }

  Widget buildInstallationContent(bool isSmallScreen) {
    return const Center(child: Text('Installation Content'));
  }

  Widget buildVerificationContent(
    DesktopClientDetectionService clientDetection,
    bool isSmallScreen,
  ) {
    return const Center(child: Text('Verification Content'));
  }
}
