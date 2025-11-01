import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../components/app_header.dart';
import '../components/modern_card.dart';
import '../config/theme.dart';
import '../services/tunnel_configuration_service.dart';
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
              child: Consumer<TunnelConfigurationService>(
                builder: (context, tunnelService, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverallStatusCard(tunnelService),
                      SizedBox(height: AppTheme.spacingM),
                      _buildConnectionDetailsCard(tunnelService),
                      if (kIsWeb) ...[
                        SizedBox(height: AppTheme.spacingM),
                        _buildDesktopClientStatusCard(),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatusCard(TunnelConfigurationService tunnelService) {
    final isConnected = tunnelService.tunnelClient?.isConnected ?? false;
    final error = tunnelService.lastError;

    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    if (isConnected) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Connected';
      statusDescription = 'WebSocket tunnel is active and functioning normally.';
    } else if (error != null) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Error';
      statusDescription = 'Connection failed: $error';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cloud_off;
      statusText = 'Disconnected';
      statusDescription = 'Tunnel is not connected.';
    }

    return ModernCard(
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tunnel Status: $statusText', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: statusColor)),
                  SizedBox(height: AppTheme.spacingS),
                  Text(statusDescription, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionDetailsCard(TunnelConfigurationService tunnelService) {
    final isConnected = tunnelService.tunnelClient?.isConnected ?? false;
    return ModernCard(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connection Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: AppTheme.spacingM),
            _buildDetailRow('Connection Type', 'WebSocket Tunnel'),
            _buildDetailRow('Status', isConnected ? 'Connected' : 'Disconnected'),
            _buildDetailRow('Protocol', 'WSS (Secure WebSocket)'),
            _buildDetailRow('Authentication', 'JWT Token'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildDesktopClientStatusCard() {
    return Consumer<DesktopClientDetectionService>(
      builder: (context, clientDetection, child) {
        final hasClients = clientDetection.hasConnectedClients;
        return ModernCard(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Desktop Client', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: AppTheme.spacingM),
                Text(hasClients ? 'Desktop client is connected.' : 'No desktop client detected.'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    try {
      final tunnelService = context.read<TunnelConfigurationService>();
      await tunnelService.tunnelClient?.connect(); // Reconnect attempt
      if (kIsWeb && mounted) {
        await context.read<DesktopClientDetectionService>().checkConnectedClients();
      }
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
}
