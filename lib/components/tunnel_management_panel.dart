import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/tunnel_service.dart';
import '../services/desktop_client_detection_service.dart';
import 'tunnel_connection_wizard.dart';

/// Tunnel Management Panel - Slide-out panel for centralized tunnel management
///
/// Provides quick access to tunnel status, configuration, and troubleshooting.
/// Accessible from the tunnel status indicator in the app header.
class TunnelManagementPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const TunnelManagementPanel({super.key, this.onClose});

  @override
  State<TunnelManagementPanel> createState() => _TunnelManagementPanelState();
}

class _TunnelManagementPanelState extends State<TunnelManagementPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background overlay
        GestureDetector(
          onTap: _closePanel,
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),
        // Slide-out panel
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              key: const Key('tunnel-management-panel'),
              width: 400,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildConnectionStatus(),
                          SizedBox(height: AppTheme.spacingM),
                          _buildQuickActions(),
                          SizedBox(height: AppTheme.spacingM),
                          _buildTroubleshootingSection(),
                          if (kIsWeb) ...[
                            SizedBox(height: AppTheme.spacingM),
                            _buildDesktopClientSection(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.settings_ethernet, color: Colors.white, size: 24),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              'Tunnel Management',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _closePanel,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer<TunnelService>(
      builder: (context, tunnelService, child) {
        final isConnected = tunnelService.isConnected;
        final error = tunnelService.error;

        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (isConnected) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusText = 'Connected';
        } else {
          statusColor = Colors.red;
          statusIcon = Icons.error;
          statusText = 'Disconnected';
        }

        return Card(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 24),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      'Tunnel Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingS),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (error != null) ...[
                  SizedBox(height: AppTheme.spacingS),
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusS,
                      ),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            error,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.red.shade700),
                          ),
                        ),
                      ],
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

  Widget _buildQuickActions() {
    return Consumer<TunnelService>(
      builder: (context, tunnelService, child) {
        final isConnected = tunnelService.isConnected;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spacingM),

                // Connect/Disconnect Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (isConnected) {
                        await tunnelService.disconnect();
                      } else {
                        await tunnelService.connect();
                      }
                    },
                    icon: Icon(isConnected ? Icons.stop : Icons.play_arrow),
                    label: Text(isConnected ? 'Disconnect' : 'Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected
                          ? Colors.red
                          : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: AppTheme.spacingS),

                // Configure Tunnel Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('configure-tunnel-button'),
                    onPressed: _showTunnelWizard,
                    icon: const Icon(Icons.settings),
                    label: const Text('Configure Tunnel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),

                SizedBox(height: AppTheme.spacingS),

                // View Status Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _closePanel();
                      context.go('/tunnel-status');
                    },
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Status Dashboard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),

                SizedBox(height: AppTheme.spacingS),

                // View Settings Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _closePanel();
                      context.go('/settings/tunnel');
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('Advanced Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textColor,
                      side: BorderSide(color: AppTheme.textColorLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTroubleshootingSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Troubleshooting',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppTheme.spacingM),

            _buildTroubleshootingItem(
              'Connection Issues',
              'Check network connectivity and firewall settings',
              Icons.network_check,
              () => _showTroubleshootingDialog('connection'),
            ),

            Divider(height: AppTheme.spacingM),

            _buildTroubleshootingItem(
              'Authentication Problems',
              'Verify login credentials and token validity',
              Icons.security,
              () => _showTroubleshootingDialog('auth'),
            ),

            Divider(height: AppTheme.spacingM),

            _buildTroubleshootingItem(
              'Performance Issues',
              'Monitor connection speed and latency',
              Icons.speed,
              () => _showTroubleshootingDialog('performance'),
            ),

            SizedBox(height: AppTheme.spacingM),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchDocumentation(),
                icon: const Icon(Icons.help_outline),
                label: const Text('View Documentation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                ),
              ),
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

  Widget _buildDesktopClientSection() {
    return Consumer<DesktopClientDetectionService>(
      builder: (context, clientDetection, child) {
        final hasConnectedClients = clientDetection.hasConnectedClients;
        final clientCount = clientDetection.connectedClientCount;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desktop Client',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spacingM),

                Row(
                  children: [
                    Icon(
                      hasConnectedClients
                          ? Icons.desktop_windows
                          : Icons.desktop_access_disabled,
                      color: hasConnectedClients ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasConnectedClients
                                ? '$clientCount Client${clientCount == 1 ? '' : 's'} Connected'
                                : 'No Desktop Client Connected',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            hasConnectedClients
                                ? 'Desktop client is running and connected'
                                : 'Download and run the desktop client to connect',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textColorLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (!hasConnectedClients) ...[
                  SizedBox(height: AppTheme.spacingM),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchGitHubReleases(),
                      icon: const Icon(Icons.download),
                      label: const Text('Download Desktop Client'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
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

  void _closePanel() async {
    await _animationController.reverse();
    widget.onClose?.call();
  }

  void _showTunnelWizard() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TunnelConnectionWizard(
        mode: TunnelWizardMode.reconfigure,
        title: 'Tunnel Management',
        onComplete: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tunnel connection configured successfully!'),
              backgroundColor: Colors.green,
            ),
          );
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
      case 'connection':
        title = 'Connection Troubleshooting';
        content = '''
• Check your internet connection
• Verify firewall settings allow WebSocket connections
• Ensure port 443 is accessible
• Try restarting the tunnel connection
• Check if your network blocks WebSocket traffic
        ''';
        break;
      case 'auth':
        title = 'Authentication Troubleshooting';
        content = '''
• Verify you are logged in with a valid account
• Check if your session has expired
• Try logging out and logging back in
• Ensure your account has tunnel access permissions
• Contact support if authentication continues to fail
        ''';
        break;
      case 'performance':
        title = 'Performance Troubleshooting';
        content = '''
• Check your internet connection speed
• Monitor network latency to the tunnel server
• Verify local Ollama is responding quickly
• Check system resources (CPU, memory)
• Consider restarting the desktop client
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
              _launchDocumentation();
            },
            child: const Text('View Docs'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchGitHubReleases() async {
    try {
      final uri = Uri.parse(AppConfig.githubReleasesUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to launch GitHub releases: $e');
    }
  }

  Future<void> _launchDocumentation() async {
    try {
      final uri = Uri.parse('${AppConfig.appUrl}/docs');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to launch documentation: $e');
    }
  }
}
