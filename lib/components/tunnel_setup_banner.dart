import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/simple_tunnel_client.dart';
import '../services/desktop_client_detection_service.dart';
import '../services/auth_service.dart';
import 'tunnel_connection_wizard.dart';

/// Prominent banner shown when tunnel setup is needed
/// 
/// This banner appears when:
/// - User is authenticated on web platform
/// - No desktop client is connected
/// - No tunnel connection is established
/// 
/// Provides clear call-to-action for tunnel setup
class TunnelSetupBanner extends StatelessWidget {
  final VoidCallback? onDismiss;
  final bool showDismiss;

  const TunnelSetupBanner({
    super.key,
    this.onDismiss,
    this.showDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return Consumer3<AuthService, SimpleTunnelClient, DesktopClientDetectionService>(
      builder: (context, authService, tunnelClient, clientDetection, child) {
        // Only show if authenticated but not connected
        if (!authService.isAuthenticated.value || 
            tunnelClient.isConnected || 
            clientDetection.hasActiveDesktopClients) {
          return const SizedBox.shrink();
        }

        return Container(
          key: const Key('tunnel-setup-banner'),
          margin: EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.1),
                AppTheme.secondaryColor.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with dismiss button
                Row(
                  children: [
                    Icon(
                      Icons.settings_ethernet,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'Connect to Your Local LLM',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    if (showDismiss && onDismiss != null)
                      IconButton(
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close),
                        color: AppTheme.textColorLight,
                        tooltip: 'Dismiss',
                      ),
                  ],
                ),
                
                SizedBox(height: AppTheme.spacingS),
                
                // Description
                Text(
                  'To use CloudToLocalLLM with your local AI models, you need to establish a secure tunnel connection. This allows the web interface to communicate with your local Ollama instance.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textColorSecondary,
                  ),
                ),
                
                SizedBox(height: AppTheme.spacingM),
                
                // Action buttons
                Wrap(
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  children: [
                    // Primary action: Setup tunnel
                    ElevatedButton.icon(
                      key: const Key('setup-tunnel-button'),
                      onPressed: () => _showTunnelWizard(context),
                      icon: const Icon(Icons.rocket_launch),
                      label: const Text('Setup Tunnel Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                    ),
                    
                    // Secondary action: Download desktop client
                    OutlinedButton.icon(
                      key: const Key('download-client-button'),
                      onPressed: () => _downloadDesktopClient(),
                      icon: const Icon(Icons.download),
                      label: const Text('Download Desktop Client'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                    ),
                    
                    // Tertiary action: Learn more
                    TextButton.icon(
                      onPressed: () => _learnMore(),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Learn More'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textColorSecondary,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: AppTheme.spacingS),
                
                // Status indicator
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'No tunnel connection detected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
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

  void _showTunnelWizard(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TunnelConnectionWizard(
        mode: TunnelWizardMode.firstTime,
        title: 'Setup Tunnel Connection',
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

  void _downloadDesktopClient() async {
    final url = Uri.parse('${AppConfig.websiteUrl}/download');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _learnMore() async {
    final url = Uri.parse('${AppConfig.websiteUrl}/docs/tunnel-setup');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
