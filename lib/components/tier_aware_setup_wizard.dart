import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/enhanced_user_tier_service.dart';
import '../services/auth_service.dart';
import '../config/theme.dart';

/// Tier-aware setup wizard that adapts based on user subscription level
class TierAwareSetupWizard extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onDismiss;

  const TierAwareSetupWizard({super.key, this.onComplete, this.onDismiss});

  @override
  State<TierAwareSetupWizard> createState() => _TierAwareSetupWizardState();
}

class _TierAwareSetupWizardState extends State<TierAwareSetupWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<EnhancedUserTierService, AuthService>(
      builder: (context, tierService, authService, child) {
        if (!authService.isAuthenticated.value) {
          return _buildAuthenticationStep(context, authService);
        }

        if (tierService.isLoading) {
          return _buildLoadingStep(context);
        }

        return _buildSetupWizard(context, tierService);
      },
    );
  }

  Widget _buildAuthenticationStep(
    BuildContext context,
    AuthService authService,
  ) {
    return Card(
      margin: EdgeInsets.all(AppTheme.spacingL),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.login, size: 64, color: AppTheme.accentColor),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'Authentication Required',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'Please sign in to continue with the setup process.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: () => authService.login(),
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingM,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStep(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(AppTheme.spacingL),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'Detecting your subscription tier...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupWizard(
    BuildContext context,
    EnhancedUserTierService tierService,
  ) {
    final steps = _getStepsForTier(tierService);

    return Card(
      margin: EdgeInsets.all(AppTheme.spacingL),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with tier information
            _buildTierHeader(context, tierService),
            SizedBox(height: AppTheme.spacingL),

            // Stepper
            Flexible(
              child: Stepper(
                currentStep: _currentStep,
                onStepTapped: (step) {
                  setState(() {
                    _currentStep = step;
                  });
                },
                controlsBuilder: (context, details) {
                  return Row(
                    children: [
                      if (details.stepIndex < steps.length - 1)
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: const Text('Next'),
                        ),
                      if (details.stepIndex == steps.length - 1)
                        ElevatedButton(
                          onPressed: () {
                            widget.onComplete?.call();
                          },
                          child: const Text('Complete'),
                        ),
                      SizedBox(width: AppTheme.spacingM),
                      if (details.stepIndex > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                    ],
                  );
                },
                steps: steps,
              ),
            ),

            // Footer with upgrade prompt for free tier
            if (tierService.isFree) _buildUpgradePrompt(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTierHeader(
    BuildContext context,
    EnhancedUserTierService tierService,
  ) {
    final tierColor = tierService.isFree
        ? Colors.grey
        : tierService.isPremium
        ? AppTheme.accentColor
        : Colors.amber;

    final tierIcon = tierService.isFree
        ? Icons.person
        : tierService.isPremium
        ? Icons.star
        : Icons.diamond;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(tierIcon, color: tierColor),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tierService.currentTier.toUpperCase()} TIER',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tierColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getTierDescription(tierService),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTierDescription(EnhancedUserTierService tierService) {
    if (tierService.isFree) {
      return 'Basic tunnel functionality with direct connection';
    } else if (tierService.isPremium) {
      return 'Advanced features with container orchestration';
    } else {
      return 'Enterprise features with unlimited resources';
    }
  }

  List<Step> _getStepsForTier(EnhancedUserTierService tierService) {
    final steps = <Step>[
      Step(
        title: const Text('Welcome'),
        content: _buildWelcomeStep(tierService),
        isActive: _currentStep == 0,
      ),
      Step(
        title: const Text('Ollama Detection'),
        content: _buildOllamaDetectionStep(),
        isActive: _currentStep == 1,
      ),
      Step(
        title: const Text('Tunnel Configuration'),
        content: _buildTunnelConfigurationStep(tierService),
        isActive: _currentStep == 2,
      ),
    ];

    // Add container setup step only for premium/enterprise users
    if (!tierService.isFree) {
      steps.add(
        Step(
          title: const Text('Container Setup'),
          content: _buildContainerSetupStep(),
          isActive: _currentStep == 3,
        ),
      );
    }

    steps.add(
      Step(
        title: const Text('Complete'),
        content: _buildCompletionStep(tierService),
        isActive: _currentStep == steps.length,
      ),
    );

    return steps;
  }

  Widget _buildWelcomeStep(EnhancedUserTierService tierService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to CloudToLocalLLM!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: AppTheme.spacingM),
        Text(
          tierService.isFree
              ? 'This wizard will help you set up a direct tunnel connection to your local Ollama instance. No Docker installation required!'
              : 'This wizard will help you set up advanced container-based proxy features for your local Ollama instance.',
        ),
        if (tierService.isFree) ...[
          SizedBox(height: AppTheme.spacingM),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Text(
                    'Free tier provides direct tunnel access without requiring Docker or containers.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOllamaDetectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ollama Detection',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: AppTheme.spacingM),
        const Text(
          'We\'ll check if Ollama is installed and running on your system.',
        ),
        SizedBox(height: AppTheme.spacingM),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _detectOllama,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: Text(_isLoading ? 'Detecting...' : 'Detect Ollama'),
        ),
      ],
    );
  }

  Widget _buildTunnelConfigurationStep(EnhancedUserTierService tierService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tunnel Configuration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: AppTheme.spacingM),
        Text(
          tierService.isFree
              ? 'Setting up direct tunnel connection (no containers required).'
              : 'Configuring advanced tunnel with container orchestration.',
        ),
        SizedBox(height: AppTheme.spacingM),
        if (tierService.isFree)
          Container(
            padding: EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Text(
                    'Direct tunnel mode: Simple, fast, and requires no additional software.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContainerSetupStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Container Setup', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: AppTheme.spacingM),
        const Text(
          'Configuring container orchestration for advanced features.',
        ),
      ],
    );
  }

  Widget _buildCompletionStep(EnhancedUserTierService tierService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Setup Complete!', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: AppTheme.spacingM),
        Text(
          tierService.isFree
              ? 'Your direct tunnel connection is ready to use.'
              : 'Your advanced container-based setup is complete.',
        ),
      ],
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: AppTheme.spacingL),
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentColor.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: AppTheme.accentColor),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Get container orchestration, team features, and priority support.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Navigate to upgrade page - for now, show a dialog
              // In production, this would navigate to the upgrade page
              _showUpgradeDialog(context);
            },
            child: const Text('Learn More'),
          ),
        ],
      ),
    );
  }

  Future<void> _detectOllama() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate Ollama detection
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return; // Check if widget is still mounted

    setState(() {
      _isLoading = false;
    });

    // Get tier service before async gap
    final tierService = context.read<EnhancedUserTierService>();
    final maxSteps = _getStepsForTier(tierService).length - 1;

    // Move to next step
    if (_currentStep < maxSteps) {
      setState(() {
        _currentStep++;
      });
    }
  }

  /// Show upgrade dialog with premium features information
  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upgrade to Premium'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Premium features include:'),
              const SizedBox(height: 16),
              const Text('• Container orchestration'),
              const Text('• Team collaboration features'),
              const Text('• API access for integrations'),
              const Text('• Priority support'),
              const Text('• Advanced networking options'),
              const SizedBox(height: 16),
              const Text(
                'Contact us to learn more about upgrading your account.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // In production, this would navigate to the upgrade page
                // For now, we'll just close the dialog
              },
              child: const Text('Contact Sales'),
            ),
          ],
        );
      },
    );
  }
}
