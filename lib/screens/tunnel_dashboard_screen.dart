import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../components/tunnel/tunnel_status_card.dart';
import '../components/tunnel/tunnel_setup_dialog.dart';
import '../components/app_header.dart';
import '../components/modern_card.dart';
import '../config/theme.dart';
import '../services/tunnel_service.dart';
import '../services/auth_service.dart';
import '../models/tunnel_state.dart';

/// Modern tunnel dashboard screen
/// 
/// Provides comprehensive tunnel management and monitoring
class TunnelDashboardScreen extends StatefulWidget {
  const TunnelDashboardScreen({super.key});

  @override
  State<TunnelDashboardScreen> createState() => _TunnelDashboardScreenState();
}

class _TunnelDashboardScreenState extends State<TunnelDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Tunnel',
            showBackButton: true,
            onBackPressed: () => context.go('/settings'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacingM),
              child: Consumer<TunnelService>(
                builder: (context, tunnelService, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TunnelStatusCard(
                        state: tunnelService.state,
                        onConnect: () => tunnelService.connect(),
                        onDisconnect: () => tunnelService.disconnect(),
                        onTest: () => _testConnection(context, tunnelService),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      _buildStatsSection(context, tunnelService.state),
                      const SizedBox(height: AppTheme.spacingM),
                      _buildQuickActions(context, tunnelService),
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

  Widget _buildStatsSection(BuildContext context, TunnelState state) {
    if (!state.isConnected || state.stats == null) {
      return const SizedBox.shrink();
    }

    final stats = state.stats!;

    return ModernCard(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Success Rate',
                    '${(stats.successRate * 100).toStringAsFixed(1)}%',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Total Requests',
                    stats.totalRequests.toString(),
                    Icons.send,
                    AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Avg Latency',
                    '${stats.averageLatencyMs}ms',
                    Icons.speed,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textColorLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, TunnelService tunnelService) {
    return ModernCard(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingS,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showSetupDialog(context),
                  icon: const Icon(Icons.settings),
                  label: const Text('Setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => tunnelService.connect(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showHelp(context),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSetupDialog(BuildContext context) {
    final authService = context.read<AuthService>();
    showDialog(
      context: context,
      builder: (context) => TunnelSetupDialog(
        authService: authService,
        onComplete: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tunnel setup completed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Future<void> _testConnection(BuildContext context, TunnelService tunnelService) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing connection...'),
        duration: Duration(seconds: 2),
      ),
    );

    final success = await tunnelService.testConnection();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Connection test successful' : 'Connection test failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tunnel Help'),
        content: const Text(
          'The tunnel provides a secure connection between your local LLM and the cloud service.\n\n'
          'To get started:\n'
          '1. Ensure you are logged in\n'
          '2. Click "Connect" to establish the tunnel\n'
          '3. Use "Test" to verify the connection\n\n'
          'If you encounter issues, try reconnecting or check your network settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

