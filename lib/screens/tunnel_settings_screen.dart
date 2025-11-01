import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/tunnel_service.dart';

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
        child: Consumer<TunnelService>(
          builder: (context, tunnelService, child) {
            final isConnected = tunnelService.isConnected;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConnectionStatusCard(context, isConnected, tunnelService.error),
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
                    'Tunnel Connection',
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
            _buildInfoRow('Type', 'HTTP (Secure tunnel)'),
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

  Widget _buildActionButtons(BuildContext context, TunnelService tunnelService) {
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

  Future<void> _testConnection(BuildContext context, TunnelService tunnelService) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...'), duration: Duration(seconds: 2)),
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

  Future<void> _reconnect(BuildContext context, TunnelService tunnelService) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reconnecting...'), duration: Duration(seconds: 2)),
    );
    await tunnelService.disconnect();
    await tunnelService.connect();
  }
}
