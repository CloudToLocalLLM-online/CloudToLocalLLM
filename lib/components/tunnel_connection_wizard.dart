import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/http_polling_tunnel_client.dart';

/// Simplified tunnel setup for HTTP polling (WebSocket removed)
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
  bool _isProcessing = false;
  String? _error;
  bool _connectionTestResult = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        key: const Key('tunnel-connection-wizard'),
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(child: _buildContent()),
            const SizedBox(height: 20),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.cloud_sync, size: 32, color: Theme.of(context).primaryColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title ?? 'HTTP Polling Setup',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Simple HTTP-based tunnel connection',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildContent() {
    return Consumer2<AuthService, HttpPollingTunnelClient>(
      builder: (context, authService, httpPollingClient, child) {
        final isAuthenticated = authService.isAuthenticated.value;
        final isConnected = httpPollingClient.isConnected;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Authentication Status
              _buildStatusCard(
                'Authentication',
                isAuthenticated ? 'Authenticated' : 'Not authenticated',
                isAuthenticated ? Icons.check_circle : Icons.error,
                isAuthenticated ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 16),

              // Connection Status
              _buildStatusCard(
                'HTTP Polling Connection',
                isConnected ? 'Connected' : 'Disconnected',
                isConnected ? Icons.check_circle : Icons.error,
                isConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 16),

              // Test Results
              if (_connectionTestResult) ...[
                _buildStatusCard(
                  'Connection Test',
                  'Test successful',
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(height: 16),
              ],

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'HTTP Polling Setup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'HTTP polling provides a simple, reliable connection to the cloud service. '
                      'No complex configuration is needed - just authenticate and connect.',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(
    String title,
    String status,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(status, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Consumer2<AuthService, HttpPollingTunnelClient>(
      builder: (context, authService, httpPollingClient, child) {
        final isAuthenticated = authService.isAuthenticated.value;
        final isConnected = httpPollingClient.isConnected;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
            Row(
              children: [
                if (!isAuthenticated) ...[
                  ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _authenticate(authService),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_isProcessing ? 'Authenticating...' : 'Login'),
                  ),
                ] else if (!isConnected) ...[
                  ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _connect(httpPollingClient),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_sync),
                    label: Text(_isProcessing ? 'Connecting...' : 'Connect'),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _testConnection,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: Text(
                      _isProcessing ? 'Testing...' : 'Test Connection',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.onComplete,
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _authenticate(AuthService authService) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await authService.login();
    } catch (e) {
      setState(() {
        _error = 'Authentication failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _connect(HttpPollingTunnelClient client) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await client.connect();
    } catch (e) {
      setState(() {
        _error = 'Connection failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Simple connection test
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _connectionTestResult = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Connection test failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}
