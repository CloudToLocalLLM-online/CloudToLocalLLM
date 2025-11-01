import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';

/// Modern tunnel setup dialog
/// 
/// Guides users through tunnel connection setup with clear steps
class TunnelSetupDialog extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const TunnelSetupDialog({
    super.key,
    required this.authService,
    this.onComplete,
    this.onCancel,
  });

  @override
  State<TunnelSetupDialog> createState() => _TunnelSetupDialogState();
}

class _TunnelSetupDialogState extends State<TunnelSetupDialog> {
  int _currentStep = 0;
  bool _isProcessing = false;
  String? _error;

  final List<SetupStep> _steps = [
    SetupStep(
      title: 'Authentication',
      description: 'Ensure you are logged in to your account',
      icon: Icons.login,
    ),
    SetupStep(
      title: 'Connection Setup',
      description: 'Establish secure tunnel connection',
      icon: Icons.settings_ethernet,
    ),
    SetupStep(
      title: 'Verification',
      description: 'Test and verify connection',
      icon: Icons.check_circle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildProgress(context),
            const SizedBox(height: 24),
            _buildCurrentStep(context),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildError(context),
            ],
            const SizedBox(height: 24),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.settings_ethernet, color: AppTheme.primaryColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Tunnel Setup',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: widget.onCancel,
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context) {
    return Row(
      children: _steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? Colors.green
                            : isActive
                                ? AppTheme.primaryColor
                                : Colors.grey.shade300,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive ? AppTheme.primaryColor : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (index < _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? Colors.green : Colors.grey.shade300,
                    margin: const EdgeInsets.only(bottom: 20),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    final step = _steps[_currentStep];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(step.icon, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textColorLight,
            ),
          ),
          if (_currentStep == 0) ...[
            const SizedBox(height: 16),
            _buildAuthStatus(context),
          ],
          if (_currentStep == 1) ...[
            const SizedBox(height: 16),
            _buildConnectionStatus(context),
          ],
          if (_currentStep == 2) ...[
            const SizedBox(height: 16),
            _buildVerificationStatus(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthStatus(BuildContext context) {
    final isAuthenticated = widget.authService.isAuthenticated.value;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAuthenticated 
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isAuthenticated ? Icons.check_circle : Icons.warning,
            color: isAuthenticated ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAuthenticated 
                  ? 'You are authenticated'
                  : 'Please log in to continue',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isAuthenticated)
            TextButton(
              onPressed: () async {
                setState(() => _isProcessing = true);
                try {
                  await widget.authService.login();
                  if (widget.authService.isAuthenticated.value) {
                    _nextStep();
                  }
                } catch (e) {
                  setState(() => _error = 'Authentication failed: $e');
                } finally {
                  setState(() => _isProcessing = false);
                }
              },
              child: const Text('Login'),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The tunnel connection will be established automatically once you proceed.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _nextStep,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(_isProcessing ? 'Connecting...' : 'Connect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStatus(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Testing tunnel connection...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_isProcessing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              _isProcessing ? 'Verifying...' : 'Connection verified',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        if (_currentStep < _steps.length - 1)
          ElevatedButton(
            onPressed: _isProcessing ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Next'),
          )
        else
          ElevatedButton(
            onPressed: _isProcessing ? null : () {
              widget.onComplete?.call();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
      ],
    );
  }

  void _nextStep() {
    setState(() {
      _error = null;
      if (_currentStep < _steps.length - 1) {
        _currentStep++;
      }
    });
  }
}

class SetupStep {
  final String title;
  final String description;
  final IconData icon;

  SetupStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

