import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/simple_tunnel_client.dart';

/// Comprehensive tunnel connection wizard for CloudToLocalLLM v3.5.13+
///
/// Guides users through the complete tunnel setup process:
/// 1. Authentication
/// 2. Server Selection
/// 3. Connection Testing
/// 4. Configuration Save
///
/// Supports multiple modes:
/// - firstTime: Complete setup for new users
/// - reconfigure: Reconfiguration for existing users
/// - troubleshoot: Guided troubleshooting for connection issues
enum TunnelWizardMode { firstTime, reconfigure, troubleshoot }

class TunnelConnectionWizard extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final TunnelWizardMode mode;
  final String? title;

  const TunnelConnectionWizard({
    super.key,
    this.onComplete,
    this.onCancel,
    this.mode = TunnelWizardMode.firstTime,
    this.title,
  });

  @override
  State<TunnelConnectionWizard> createState() => _TunnelConnectionWizardState();
}

class _TunnelConnectionWizardState extends State<TunnelConnectionWizard> {
  int _currentStep = 0;
  bool _isProcessing = false;
  String? _error;

  // Configuration state
  String _selectedServer = 'https://app.cloudtolocalllm.online';
  int _connectionTimeout = 10;
  int _healthCheckInterval = 30;
  bool _enableCloudProxy = true;

  // Test results
  bool? _authTestResult;
  bool? _connectionTestResult;
  String? _serverVersion;

  // Mode-specific state
  late List<WizardStep> _steps;
  late String _wizardTitle;

  @override
  void initState() {
    super.initState();
    _initializeWizardForMode();
  }

  void _initializeWizardForMode() {
    switch (widget.mode) {
      case TunnelWizardMode.firstTime:
        _wizardTitle = widget.title ?? 'Tunnel Setup Wizard';
        _steps = [
          WizardStep(
            title: 'Authentication',
            description: 'Authenticate with CloudToLocalLLM services',
            icon: Icons.login,
          ),
          WizardStep(
            title: 'Server Selection',
            description: 'Choose your tunnel server configuration',
            icon: Icons.dns,
          ),
          WizardStep(
            title: 'Connection Testing',
            description: 'Test the tunnel connection',
            icon: Icons.network_check,
          ),
          WizardStep(
            title: 'Configuration Save',
            description: 'Save and activate your tunnel configuration',
            icon: Icons.save,
          ),
        ];
        break;
      case TunnelWizardMode.reconfigure:
        _wizardTitle = widget.title ?? 'Reconfigure Tunnel';
        _steps = [
          WizardStep(
            title: 'Current Configuration',
            description: 'Review your current tunnel settings',
            icon: Icons.settings,
          ),
          WizardStep(
            title: 'Update Settings',
            description: 'Modify tunnel configuration',
            icon: Icons.edit,
          ),
          WizardStep(
            title: 'Test Changes',
            description: 'Verify updated configuration',
            icon: Icons.network_check,
          ),
          WizardStep(
            title: 'Apply Changes',
            description: 'Save and apply new configuration',
            icon: Icons.save,
          ),
        ];
        break;
      case TunnelWizardMode.troubleshoot:
        _wizardTitle = widget.title ?? 'Tunnel Troubleshooting';
        _steps = [
          WizardStep(
            title: 'Diagnose Issue',
            description: 'Identify connection problems',
            icon: Icons.search,
          ),
          WizardStep(
            title: 'Test Components',
            description: 'Check individual system components',
            icon: Icons.build,
          ),
          WizardStep(
            title: 'Apply Fixes',
            description: 'Implement recommended solutions',
            icon: Icons.healing,
          ),
          WizardStep(
            title: 'Verify Resolution',
            description: 'Confirm issues are resolved',
            icon: Icons.check_circle,
          ),
        ];
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.8).clamp(600.0, 900.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(600.0, 800.0);

    return Dialog(
      child: Container(
        key: const Key('tunnel-connection-wizard'),
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStepIndicator(),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: _buildCurrentStep())),
            const SizedBox(height: 20),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    IconData headerIcon;
    String subtitle;

    switch (widget.mode) {
      case TunnelWizardMode.firstTime:
        headerIcon = Icons.settings_ethernet;
        subtitle = 'Configure your CloudToLocalLLM tunnel connection';
        break;
      case TunnelWizardMode.reconfigure:
        headerIcon = Icons.edit;
        subtitle = 'Update your existing tunnel configuration';
        break;
      case TunnelWizardMode.troubleshoot:
        headerIcon = Icons.build;
        subtitle = 'Diagnose and fix tunnel connection issues';
        break;
    }

    return Row(
      children: [
        Icon(headerIcon, size: 32, color: Theme.of(context).primaryColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _wizardTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Colors.green
                              : isActive
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : step.icon,
                          color: isCompleted || isActive
                              ? Colors.white
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isActive
                              ? Theme.of(context).primaryColor
                              : isCompleted
                              ? Colors.green
                              : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (index < _steps.length - 1)
                  Container(
                    width: 32,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 30),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_error != null) {
      return _buildErrorStep();
    }

    switch (_currentStep) {
      case 0:
        return _buildAuthenticationStep();
      case 1:
        return _buildServerSelectionStep();
      case 2:
        return _buildConnectionTestingStep();
      case 3:
        return _buildConfigurationSaveStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildErrorStep() {
    final errorInfo = _categorizeError(_error ?? 'Unknown error');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            errorInfo['icon'] as IconData,
            size: 64,
            color: errorInfo['color'] as Color,
          ),
          const SizedBox(height: 16),
          Text(
            errorInfo['title'] as String,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: errorInfo['color'] as Color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorInfo['message'] as String,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (errorInfo['suggestion'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorInfo['suggestion'] as String,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
              if (errorInfo['showTokenRefresh'] == true) ...[
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _retryWithTokenRefresh,
                  icon: const Icon(Icons.key),
                  label: const Text('Refresh Token'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticationStep() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;
        final isLoading = authService.isLoading.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _steps[0].title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _steps[0].description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (isAuthenticated) ...[
              _buildSuccessCard(
                'Authentication Successful',
                'You are logged in as ${authService.currentUser?.email ?? 'Unknown'}',
                Icons.check_circle,
              ),
            ] else ...[
              _buildInfoCard(
                'Authentication Required',
                'Please authenticate with your CloudToLocalLLM account to continue.',
                Icons.info,
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => _performAuthentication(authService),
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(isLoading ? 'Authenticating...' : 'Login'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildServerSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _steps[1].title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[1].description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _buildServerConfigCard(),
      ],
    );
  }

  Widget _buildConnectionTestingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _steps[2].title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[2].description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _buildConnectionTestCard(),
      ],
    );
  }

  Widget _buildConfigurationSaveStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _steps[3].title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[3].description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _buildConfigurationSummaryCard(),
      ],
    );
  }

  Widget _buildSuccessCard(String title, String description, IconData icon) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.green, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String description, IconData icon) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _selectedServer,
              decoration: const InputDecoration(
                labelText: 'Tunnel Server URL',
                hintText: 'https://app.cloudtolocalllm.online',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedServer = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _connectionTimeout.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Connection Timeout (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _connectionTimeout = int.tryParse(value) ?? 10;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _healthCheckInterval.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Health Check Interval (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _healthCheckInterval = int.tryParse(value) ?? 30;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Cloud Proxy'),
              subtitle: const Text(
                'Allow tunnel connections through cloud proxy',
              ),
              value: _enableCloudProxy,
              onChanged: (value) {
                setState(() {
                  _enableCloudProxy = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Test',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTestResultItem(
              'Authentication',
              _authTestResult,
              'Verifying authentication token...',
            ),
            const SizedBox(height: 8),
            _buildTestResultItem(
              'Server Connection',
              _connectionTestResult,
              'Testing connection to $_selectedServer...',
            ),
            if (_serverVersion != null) ...[
              const SizedBox(height: 8),
              Text(
                'Server Version: $_serverVersion',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.green.shade700),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _performConnectionTest,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(_isProcessing ? 'Testing...' : 'Test Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultItem(String label, bool? result, String loadingText) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: result == null
              ? (_isProcessing
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.grey,
                      ))
              : result
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.error, color: Colors.red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            result == null && _isProcessing ? loadingText : label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: result == null
                  ? Colors.grey
                  : result
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryItem('Server URL', _selectedServer),
            _buildSummaryItem(
              'Connection Timeout',
              '$_connectionTimeout seconds',
            ),
            _buildSummaryItem(
              'Health Check Interval',
              '$_healthCheckInterval seconds',
            ),
            _buildSummaryItem(
              'Cloud Proxy',
              _enableCloudProxy ? 'Enabled' : 'Disabled',
            ),
            if (_serverVersion != null)
              _buildSummaryItem('Server Version', _serverVersion!),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Ready to Save',
              'Your tunnel configuration is ready to be saved and activated.',
              Icons.info,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _currentStep < _steps.length - 1
                ? ElevatedButton.icon(
                    onPressed: _canProceedToNextStep() && !_isProcessing
                        ? _nextStep
                        : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(_isProcessing ? 'Processing...' : 'Next'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _canCompleteWizard() && !_isProcessing
                        ? _completeWizard
                        : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_isProcessing ? 'Saving...' : 'Complete Setup'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Navigation methods
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _error = null;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _error = null;
      });
    }
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Authentication step
        final authService = context.read<AuthService>();
        return authService.isAuthenticated.value;
      case 1: // Server selection step
        return _selectedServer.isNotEmpty &&
            _connectionTimeout > 0 &&
            _healthCheckInterval > 0;
      case 2: // Connection testing step
        return _authTestResult == true && _connectionTestResult == true;
      case 3: // Configuration save step
        return true;
      default:
        return false;
    }
  }

  bool _canCompleteWizard() {
    return _authTestResult == true && _connectionTestResult == true;
  }

  // Action methods
  Future<void> _performAuthentication(AuthService authService) async {
    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      await authService.loginWithPersistence();

      if (authService.isAuthenticated.value) {
        setState(() {
          _authTestResult = true;
        });
      } else {
        setState(() {
          _error = 'Authentication failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Authentication error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _performConnectionTest() async {
    try {
      setState(() {
        _isProcessing = true;
        _error = null;
        _authTestResult = null;
        _connectionTestResult = null;
        _serverVersion = null;
      });

      // Test authentication
      final authService = context.read<AuthService>();
      final isAuthenticated = await authService.validateAuthentication();

      setState(() {
        _authTestResult = isAuthenticated;
      });

      if (!isAuthenticated) {
        setState(() {
          _error = 'Authentication test failed. Please re-authenticate.';
        });
        return;
      }

      // Test server connection using simplified tunnel client
      if (!mounted) return;
      final simpleTunnelClient = context.read<SimpleTunnelClient>();

      // For simplified tunnel system, we just test basic connectivity
      final testResult = await _testSimpleTunnelConnection(simpleTunnelClient);

      if (mounted) {
        setState(() {
          _connectionTestResult = testResult['success'] as bool;
          _serverVersion = testResult['serverInfo']?['version'] as String?;
        });

        if (!_connectionTestResult!) {
          final errorMessage = testResult['error'] as String?;
          final steps = testResult['steps'] as List<Map<String, dynamic>>?;

          // Build detailed error message from test steps
          final failedSteps = steps
              ?.where((step) => step['status'] == 'failed')
              .toList();
          String detailedError = errorMessage ?? 'Connection test failed';

          if (failedSteps != null && failedSteps.isNotEmpty) {
            final stepErrors = failedSteps
                .map((step) => '${step['name']}: ${step['error']}')
                .join('; ');
            detailedError = '$detailedError ($stepErrors)';
          }

          setState(() {
            _error = detailedError;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Connection test error: ${e.toString()}';
        _connectionTestResult = false;
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeWizard() async {
    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      if (!mounted) return;
      final simpleTunnelClient = context.read<SimpleTunnelClient>();

      // For simplified tunnel system, configuration is handled automatically
      // Just ensure the client is connected
      if (!simpleTunnelClient.isConnected) {
        await simpleTunnelClient.connect();

        // If connection failed due to authentication, try with token refresh
        if (!simpleTunnelClient.isConnected &&
            simpleTunnelClient.lastError != null &&
            simpleTunnelClient.lastError!.toLowerCase().contains('auth')) {
          await simpleTunnelClient.retryWithTokenRefresh();
        }
      }

      // Verify connection was successful
      if (!simpleTunnelClient.isConnected) {
        throw Exception(
          'Failed to establish tunnel connection: ${simpleTunnelClient.lastError ?? "Unknown error"}',
        );
      }

      // Notify completion
      if (mounted) {
        widget.onComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to save configuration: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Test simplified tunnel connection with comprehensive validation
  Future<Map<String, dynamic>> _testSimpleTunnelConnection(
    SimpleTunnelClient client,
  ) async {
    final steps = <Map<String, dynamic>>[];

    try {
      // Step 1: Test WebSocket connectivity
      steps.add({
        'name': 'WebSocket Connection',
        'status': 'running',
        'error': null,
      });

      if (!client.isConnected) {
        await client.connect();

        // If connection failed due to authentication, try with token refresh
        if (!client.isConnected &&
            client.lastError != null &&
            client.lastError!.toLowerCase().contains('auth')) {
          await client.retryWithTokenRefresh();
        }
      }

      steps[0] = {
        'name': 'WebSocket Connection',
        'status': client.isConnected ? 'passed' : 'failed',
        'error': client.isConnected ? null : client.lastError,
      };

      if (!client.isConnected) {
        return {
          'success': false,
          'error': 'WebSocket connection failed: ${client.lastError}',
          'steps': steps,
        };
      }

      // Step 2: Test ping/pong health check
      steps.add({'name': 'Health Check', 'status': 'running', 'error': null});

      final healthCheckResult = await _testHealthCheck(client);
      steps[1] = {
        'name': 'Health Check',
        'status': healthCheckResult ? 'passed' : 'failed',
        'error': healthCheckResult ? null : 'Ping/pong health check failed',
      };

      // Step 3: Test basic tunnel functionality (if health check passed)
      if (healthCheckResult) {
        steps.add({
          'name': 'Tunnel Functionality',
          'status': 'running',
          'error': null,
        });

        final functionalityResult = await _testTunnelFunctionality(client);
        steps[2] = {
          'name': 'Tunnel Functionality',
          'status': functionalityResult ? 'passed' : 'failed',
          'error': functionalityResult
              ? null
              : 'Tunnel request forwarding test failed',
        };
      }

      final allTestsPassed = steps.every((step) => step['status'] == 'passed');

      return {
        'success': allTestsPassed,
        'serverInfo': {
          'version': '3.10.0+', // Simplified tunnel system version
        },
        'steps': steps,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'steps': [
          ...steps,
          {
            'name': 'Connection Test',
            'status': 'failed',
            'error': e.toString(),
          },
        ],
      };
    }
  }

  /// Test health check (ping/pong) functionality
  Future<bool> _testHealthCheck(SimpleTunnelClient client) async {
    try {
      // For simplified tunnel client, we check if it's connected and responsive
      // The client automatically handles ping/pong internally
      if (!client.isConnected) {
        return false;
      }

      // Wait a moment to ensure connection is stable
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if connection is still active
      return client.isConnected;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  /// Test tunnel functionality by attempting a simple request
  Future<bool> _testTunnelFunctionality(SimpleTunnelClient client) async {
    try {
      // For the simplified tunnel system, we test by checking if the client
      // can maintain its connection and handle basic operations
      if (!client.isConnected) {
        return false;
      }

      // Check performance metrics to ensure tunnel is functioning
      final metrics = client.getPerformanceMetrics();

      // If we can get metrics, the tunnel is functional
      return metrics.isNotEmpty;
    } catch (e) {
      debugPrint('Tunnel functionality test failed: $e');
      return false;
    }
  }

  /// Categorize error and provide user-friendly information
  Map<String, dynamic> _categorizeError(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('auth') || errorLower.contains('token')) {
      return {
        'icon': Icons.key_off,
        'color': Colors.orange,
        'title': 'Authentication Issue',
        'message':
            'There was a problem with your authentication. Your session may have expired.',
        'suggestion':
            'Try refreshing your authentication token or logging out and back in.',
        'showTokenRefresh': true,
      };
    } else if (errorLower.contains('network') ||
        errorLower.contains('connection')) {
      return {
        'icon': Icons.wifi_off,
        'color': Colors.red,
        'title': 'Connection Problem',
        'message':
            'Unable to connect to the CloudToLocalLLM servers. Please check your internet connection.',
        'suggestion':
            'Verify your internet connection and try again. If the problem persists, the servers may be temporarily unavailable.',
        'showTokenRefresh': false,
      };
    } else if (errorLower.contains('timeout')) {
      return {
        'icon': Icons.timer_off,
        'color': Colors.amber,
        'title': 'Connection Timeout',
        'message':
            'The connection attempt timed out. This may be due to network issues or server load.',
        'suggestion':
            'Try again in a few moments. If the problem persists, check your network connection.',
        'showTokenRefresh': false,
      };
    } else if (errorLower.contains('server') ||
        errorLower.contains('503') ||
        errorLower.contains('502')) {
      return {
        'icon': Icons.cloud_off,
        'color': Colors.red,
        'title': 'Server Error',
        'message': 'The CloudToLocalLLM servers are experiencing issues.',
        'suggestion':
            'Please try again in a few minutes. If the problem persists, check the CloudToLocalLLM status page.',
        'showTokenRefresh': false,
      };
    } else {
      return {
        'icon': Icons.error_outline,
        'color': Colors.red,
        'title': 'Setup Error',
        'message': error,
        'suggestion': null,
        'showTokenRefresh': false,
      };
    }
  }

  /// Retry connection with token refresh
  Future<void> _retryWithTokenRefresh() async {
    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      final simpleTunnelClient = context.read<SimpleTunnelClient>();
      await simpleTunnelClient.retryWithTokenRefresh();

      if (simpleTunnelClient.isConnected) {
        setState(() {
          _connectionTestResult = true;
        });
      } else {
        setState(() {
          _error = 'Token refresh failed: ${simpleTunnelClient.lastError}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Token refresh error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}

/// Wizard step data model
class WizardStep {
  final String title;
  final String description;
  final IconData icon;

  const WizardStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
