import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/tunnel_configuration_service.dart';

class TunnelSettingsScreen extends StatelessWidget {
  const TunnelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunnel Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<TunnelConfigurationService>(
          builder: (context, tunnelService, child) {
            final tunnelClient = tunnelService.tunnelClient;
            final isConnected = tunnelClient?.isConnected ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConnectionStatusCard(context, isConnected, tunnelService.lastError),
                const SizedBox(height: 24),
                _buildTunnelInfo(context),
                const SizedBox(height: 24),
                _buildActionButtons(context, tunnelService),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(BuildContext context, bool isConnected, String? error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              color: isConnected ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WebSocket Tunnel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(color: isConnected ? Colors.green[700] : Colors.red[700]),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text('Error: $error', style: TextStyle(color: Colors.red[600], fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTunnelInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Type', 'WebSocket (WSS)'),
            _buildInfoRow('Authentication', 'JWT Token'),
            _buildInfoRow('Configuration', 'Automatic'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, TunnelConfigurationService tunnelService) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _testConnection(context, tunnelService),
            icon: const Icon(Icons.network_check),
            label: const Text('Test Connection'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _reconnect(context, tunnelService),
            icon: const Icon(Icons.refresh),
            label: const Text('Reconnect'),
          ),
        ),
      ],
    );
  }

  Future<void> _testConnection(BuildContext context, TunnelConfigurationService tunnelService) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...'), duration: Duration(seconds: 2)),
    );
    final result = await tunnelService.testTunnelConnection();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _reconnect(BuildContext context, TunnelConfigurationService tunnelService) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reconnecting...'), duration: Duration(seconds: 2)),
    );
    await tunnelService.tunnelClient?.connect();
  }
}
