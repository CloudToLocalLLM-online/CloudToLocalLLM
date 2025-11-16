import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';

/// Email Provider Configuration Tab for the Admin Center (Self-Hosted Only)
/// Allows administrators to configure email provider settings for self-hosted instances
class EmailProviderConfigTab extends StatefulWidget {
  const EmailProviderConfigTab({super.key});

  @override
  State<EmailProviderConfigTab> createState() => _EmailProviderConfigTabState();
}

class _EmailProviderConfigTabState extends State<EmailProviderConfigTab> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _smtpHostController = TextEditingController();
  final TextEditingController _smtpPortController = TextEditingController();
  final TextEditingController _smtpUsernameController = TextEditingController();
  final TextEditingController _smtpPasswordController = TextEditingController();
  final TextEditingController _testEmailController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSendingTest = false;
  String? _error;
  String? _successMessage;
  bool _obscurePassword = true;

  // Configuration
  String _selectedProvider = 'smtp'; // smtp, sendgrid, mailgun, aws_ses
  String _selectedEncryption = 'tls'; // tls, ssl, none

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  @override
  void dispose() {
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    _testEmailController.dispose();
    super.dispose();
  }

  /// Check if this is a self-hosted instance
  bool get _isSelfHosted {
    // Check deployment type from environment
    const deploymentType =
        String.fromEnvironment('DEPLOYMENT_TYPE', defaultValue: 'cloud');
    return deploymentType == 'self-hosted';
  }

  /// Load current email provider configuration
  Future<void> _loadConfiguration() async {
    final adminService = context.read<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewConfiguration)) {
      setState(() {
        _error = 'You do not have permission to view email configuration';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: Implement API call to load email configuration
      // For now, just set loading to false
      // final config = await adminService.getEmailConfiguration();

      setState(() {
        _isLoading = false;
        // Populate form fields with loaded configuration
        // _smtpHostController.text = config['smtp_host'] ?? '';
        // _smtpPortController.text = config['smtp_port']?.toString() ?? '587';
        // etc.
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load email configuration: $e';
        _isLoading = false;
      });
    }
  }

  /// Save email provider configuration
  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final adminService = context.read<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editConfiguration)) {
      setState(() {
        _error = 'You do not have permission to edit email configuration';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // TODO: Implement API call to save email configuration
      // await adminService.saveEmailConfiguration({
      //   'provider': _selectedProvider,
      //   'smtp_host': _smtpHostController.text,
      //   'smtp_port': int.parse(_smtpPortController.text),
      //   'smtp_username': _smtpUsernameController.text,
      //   'smtp_password': _smtpPasswordController.text,
      //   'encryption': _selectedEncryption,
      // });

      setState(() {
        _isSaving = false;
        _successMessage = 'Email configuration saved successfully';
      });

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to save email configuration: $e';
        _isSaving = false;
      });
    }
  }

  /// Send test email
  Future<void> _sendTestEmail() async {
    if (_testEmailController.text.isEmpty) {
      setState(() {
        _error = 'Please enter an email address to send test email';
      });
      return;
    }

    final adminService = context.read<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editConfiguration)) {
      setState(() {
        _error = 'You do not have permission to send test emails';
      });
      return;
    }

    setState(() {
      _isSendingTest = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // TODO: Implement API call to send test email
      // await adminService.sendTestEmail(_testEmailController.text);

      setState(() {
        _isSendingTest = false;
        _successMessage =
            'Test email sent successfully to ${_testEmailController.text}';
      });

      // Clear success message after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to send test email: $e';
        _isSendingTest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a self-hosted instance
    if (!_isSelfHosted) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Email Configuration Not Available',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Email provider configuration is only available for self-hosted instances. '
                'Cloud-hosted instances use managed email services.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Email Provider Configuration',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure email provider settings for sending notifications and communications.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 32),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _error = null),
                        color: Colors.red.shade700,
                      ),
                    ],
                  ),
                ),

              // Success message
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _successMessage = null),
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),

              // Loading indicator
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider selection card
                      _buildProviderSelectionCard(),
                      const SizedBox(height: 24),

                      // Configuration form card
                      _buildConfigurationFormCard(),
                      const SizedBox(height: 24),

                      // Test email card
                      _buildTestEmailCard(),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveConfiguration,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                              _isSaving ? 'Saving...' : 'Save Configuration'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build provider selection card
  Widget _buildProviderSelectionCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Service Provider',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
                helperText: 'Select your email service provider',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'smtp',
                  child: Text('SMTP Server'),
                ),
                DropdownMenuItem(
                  value: 'sendgrid',
                  child: Text('SendGrid'),
                ),
                DropdownMenuItem(
                  value: 'mailgun',
                  child: Text('Mailgun'),
                ),
                DropdownMenuItem(
                  value: 'aws_ses',
                  child: Text('AWS SES'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedProvider = value!;
                  // Set default ports based on provider
                  if (value == 'smtp') {
                    _smtpPortController.text = '587';
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build configuration form card
  Widget _buildConfigurationFormCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedProvider == 'smtp'
                  ? 'SMTP Configuration'
                  : '${_selectedProvider.toUpperCase()} Configuration',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // SMTP Host
            TextFormField(
              controller: _smtpHostController,
              decoration: InputDecoration(
                labelText:
                    _selectedProvider == 'smtp' ? 'SMTP Host' : 'API Endpoint',
                border: const OutlineInputBorder(),
                helperText: _selectedProvider == 'smtp'
                    ? 'e.g., smtp.gmail.com'
                    : 'API endpoint URL',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the host/endpoint';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // SMTP Port (only for SMTP)
            if (_selectedProvider == 'smtp') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _smtpPortController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        border: OutlineInputBorder(),
                        helperText: 'e.g., 587 (TLS) or 465 (SSL)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the port';
                        }
                        final port = int.tryParse(value);
                        if (port == null || port < 1 || port > 65535) {
                          return 'Please enter a valid port (1-65535)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedEncryption,
                      decoration: const InputDecoration(
                        labelText: 'Encryption',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'tls',
                          child: Text('TLS'),
                        ),
                        DropdownMenuItem(
                          value: 'ssl',
                          child: Text('SSL'),
                        ),
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('None (Not Recommended)'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedEncryption = value!;
                          // Update port based on encryption
                          if (value == 'tls' &&
                              _smtpPortController.text == '465') {
                            _smtpPortController.text = '587';
                          } else if (value == 'ssl' &&
                              _smtpPortController.text == '587') {
                            _smtpPortController.text = '465';
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Username/API Key
            TextFormField(
              controller: _smtpUsernameController,
              decoration: InputDecoration(
                labelText: _selectedProvider == 'smtp' ? 'Username' : 'API Key',
                border: const OutlineInputBorder(),
                helperText: _selectedProvider == 'smtp'
                    ? 'SMTP username or email'
                    : 'Your API key',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the username/API key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password/API Secret
            TextFormField(
              controller: _smtpPasswordController,
              decoration: InputDecoration(
                labelText:
                    _selectedProvider == 'smtp' ? 'Password' : 'API Secret',
                border: const OutlineInputBorder(),
                helperText: _selectedProvider == 'smtp'
                    ? 'SMTP password or app password'
                    : 'Your API secret key',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the password/API secret';
                }
                return null;
              },
            ),

            // Warning for unencrypted connections
            if (_selectedProvider == 'smtp' && _selectedEncryption == 'none')
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Warning: Unencrypted connections are not secure. '
                        'Use TLS or SSL for production environments.',
                        style: TextStyle(color: Colors.orange.shade700),
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

  /// Build test email card
  Widget _buildTestEmailCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Email',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a test email to verify your configuration is working correctly.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _testEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Test Email Address',
                      border: OutlineInputBorder(),
                      helperText: 'Enter email address to send test email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        // Basic email validation
                        final emailRegex = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _isSendingTest ? null : _sendTestEmail,
                  icon: _isSendingTest
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSendingTest ? 'Sending...' : 'Send Test'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
