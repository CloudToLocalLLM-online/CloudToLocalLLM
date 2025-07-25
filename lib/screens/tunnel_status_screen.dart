import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../components/app_header.dart';
import '../components/modern_card.dart';
import '../components/tunnel_connection_wizard.dart';
import '../config/theme.dart';
import '../services/simple_tunnel_client.dart';
import '../services/desktop_client_detection_service.dart';

/// Comprehensive Tunnel Status Screen
///
/// Provides detailed monitoring and management of tunnel connections,
/// including real-time status, performance metrics, and troubleshooting tools.
class TunnelStatusScreen extends StatefulWidget {
  const TunnelStatusScreen({super.key});

  @override
  State<TunnelStatusScreen> createState() => _TunnelStatusScreenState();
}

class _TunnelStatusScreenState extends State<TunnelStatusScreen> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Tunnel Status',
            showBackButton: true,
            onBackPressed: () => context.go('/settings'),
            actions: [
              IconButton(
                onPressed: _refreshStatus,
                icon: _isRefreshing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Refresh Status',
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverallStatusCard(),
                  SizedBox(height: AppTheme.spacingM),
                  _buildConnectionDetailsCard(),
                  SizedBox(height: AppTheme.spacingM),
                  if (kIsWeb) ...[
                    _buildDesktopClientStatusCard(),
                    SizedBox(height: AppTheme.spacingM),
                  ],
                  _buildPerformanceMetricsCard(),
                  SizedBox(height: AppTheme.spacingM),
                  _buildQuickActionsCard(),
                  SizedBox(height: AppTheme.spacingM),
                  _buildTroubleshootingCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatusCard() {
    return Consumer<SimpleTunnelClient>(
      builder: (context, tunnelClient, child) {
        final isConnected = tunnelClient.isConnected;
        final isConnecting = tunnelClient.isConnecting;
        final error = tunnelClient.lastError;

        Color statusColor;
        IconData statusIcon;
        String statusText;
        String statusDescription;

        if (isConnected) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusText = 'Connected';
          statusDescription = 'Tunnel is active and functioning normally';
        } else if (isConnecting) {
          statusColor = Colors.orange;
          statusIcon = Icons.sync;
          statusText = 'Connecting';
          statusDescription = 'Establishing tunnel connection...';
        } else if (error != null) {
          statusColor = Colors.red;
          statusIcon = Icons.error;
          statusText = 'Error';
          statusDescription = 'Connection failed: $error';
        } else {
          statusColor = Colors.red;
          statusIcon = Icons.cloud_off;
          statusText = 'Disconnected';
          statusDescription = 'Tunnel is not connected';
        }

        return ModernCard(
          child: Container(
            padding: EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withValues(alpha: 0.1),
                  statusColor.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tunnel Status: $statusText',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                      ),
                      SizedBox(height: AppTheme.spacingS),
                      Text(
                        statusDescription,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textColorLight,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Last updated: ${DateTime.now().toString().substring(0, 19)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textColorLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionDetailsCard() {
    return Consumer<SimpleTunnelClient>(
      builder: (context, tunnelClient, child) {
        final config = tunnelClient.config;
        final connectionStatus = tunnelClient.connectionStatus;

        return ModernCard(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: AppTheme.spacingM),

                _buildDetailRow('Cloud Proxy URL', config.cloudProxyUrl),
                _buildDetailRow('Local Ollama URL', config.localOllamaUrl),
                _buildDetailRow(
                  'Connection Timeout',
                  '${config.connectionTimeout}s',
                ),
                _buildDetailRow(
                  'Health Check Interval',
                  '${config.healthCheckInterval}s',
                ),
                _buildDetailRow(
                  'Cloud Proxy Enabled',
                  config.enableCloudProxy ? 'Yes' : 'No',
                ),

                if (connectionStatus.isNotEmpty) ...[
                  Divider(height: AppTheme.spacingM),
                  Text(
                    'Runtime Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  ...connectionStatus.entries.map(
                    (entry) =>
                        _buildDetailRow(entry.key, entry.value.toString()),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopClientStatusCard() {
    return Consumer<DesktopClientDetectionService>(
      builder: (context, clientDetection, child) {
        final hasClients = clientDetection.hasConnectedClients;
        final clientCount = clientDetection.connectedClientCount;
        final clients = clientDetection.connectedClients;

        return ModernCard(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasClients
                          ? Icons.desktop_windows
                          : Icons.desktop_access_disabled,
                      color: hasClients ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      'Desktop Clients',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingM),

                if (hasClients) ...[
                  Text(
                    '$clientCount client${clientCount == 1 ? '' : 's'} connected',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  ...clients.map(
                    (client) => Container(
                      margin: EdgeInsets.only(bottom: AppTheme.spacingS),
                      padding: EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusS,
                        ),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.displayName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Connected: ${client.connectedAt.toString().substring(0, 19)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textColorLight),
                          ),
                          Text(
                            'Last ping: ${client.lastPing.toString().substring(0, 19)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textColorLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'No desktop clients connected',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Download and run the CloudToLocalLLM desktop client to establish a connection.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textColorLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceMetricsCard() {
    return ModernCard(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: AppTheme.primaryColor, size: 24),
                SizedBox(width: AppTheme.spacingS),
                Text(
                  'Performance Metrics',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingM),

            // Placeholder for performance metrics
            Container(
              padding: EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.analytics, color: AppTheme.primaryColor, size: 32),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Performance Monitoring',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Detailed performance metrics will be available in a future update.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textColorLight,
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

  Widget _buildQuickActionsCard() {
    return Consumer<SimpleTunnelClient>(
      builder: (context, tunnelClient, child) {
        final isConnected = tunnelClient.isConnected;
        final isConnecting = tunnelClient.isConnecting;

        return ModernCard(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: AppTheme.spacingM),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isConnecting
                            ? null
                            : () async {
                                if (isConnected) {
                                  await tunnelClient.disconnect();
                                } else {
                                  await tunnelClient.connect();
                                }
                              },
                        icon: isConnecting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(isConnected ? Icons.stop : Icons.play_arrow),
                        label: Text(
                          isConnecting
                              ? 'Connecting...'
                              : isConnected
                              ? 'Disconnect'
                              : 'Connect',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected
                              ? Colors.red
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showTunnelWizard(TunnelWizardMode.reconfigure),
                        icon: const Icon(Icons.settings),
                        label: const Text('Configure'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTroubleshootingCard() {
    return ModernCard(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: AppTheme.spacingS),
                Text(
                  'Common Issues',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingM),

            _buildTroubleshootingItem(
              'Connection Timeout',
              'Check network connectivity and firewall settings',
              Icons.network_check,
              () => _showTroubleshootingDialog('timeout'),
            ),

            _buildTroubleshootingItem(
              'Authentication Failed',
              'Verify login credentials and token validity',
              Icons.security,
              () => _showTroubleshootingDialog('auth'),
            ),

            _buildTroubleshootingItem(
              'Desktop Client Not Found',
              'Ensure desktop client is running and connected',
              Icons.desktop_windows,
              () => _showTroubleshootingDialog('client'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingItem(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textColorLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textColorLight, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Refresh tunnel client status
      final tunnelClient = context.read<SimpleTunnelClient>();
      if (!tunnelClient.isConnected && !tunnelClient.isConnecting) {
        // Only attempt reconnection if not already connected/connecting
        await tunnelClient.connect();
      }

      // Refresh desktop client detection if on web
      if (kIsWeb && mounted) {
        final clientDetection = context.read<DesktopClientDetectionService>();
        await clientDetection.checkConnectedClients();
      }

      // Small delay to show refresh animation
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error refreshing tunnel status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showTunnelWizard(TunnelWizardMode mode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TunnelConnectionWizard(
        mode: mode,
        onComplete: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tunnel operation completed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshStatus();
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showTroubleshootingDialog(String type) {
    String title;
    String content;

    switch (type) {
      case 'timeout':
        title = 'Connection Timeout';
        content = '''
• Check your internet connection
• Verify firewall allows WebSocket connections on port 443
• Try connecting to a different network
• Restart your router/modem
• Contact your network administrator if on corporate network
        ''';
        break;
      case 'auth':
        title = 'Authentication Issues';
        content = '''
• Verify you are logged in with a valid account
• Check if your session has expired - try logging out and back in
• Ensure your account has tunnel access permissions
• Clear browser cache and cookies
• Contact support if authentication continues to fail
        ''';
        break;
      case 'client':
        title = 'Desktop Client Issues';
        content = '''
• Download and install the latest desktop client
• Ensure the desktop client is running
• Check that Ollama is installed and running locally
• Verify the desktop client shows "Connected" status
• Try restarting the desktop client
        ''';
        break;
      default:
        title = 'Troubleshooting';
        content = 'General troubleshooting information.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showTunnelWizard(TunnelWizardMode.troubleshoot);
            },
            child: const Text('Run Troubleshooter'),
          ),
        ],
      ),
    );
  }
}
