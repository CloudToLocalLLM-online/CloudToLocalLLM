import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/http_polling_tunnel_client.dart';

/// Simplified Tunnel Settings Screen for HTTP Polling
///
/// Provides basic tunnel status and connection management for HTTP polling.
/// Much simpler than the original WebSocket tunnel configuration.
class TunnelSettingsScreen extends StatefulWidget {
  const TunnelSettingsScreen({super.key});

  @override
  State<TunnelSettingsScreen> createState() => _TunnelSettingsScreenState();
}

class _TunnelSettingsScreenState extends State<TunnelSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunnel Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatusCard(),
            const SizedBox(height: 24),
            _buildHttpPollingInfo(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Consumer<HttpPollingTunnelClient>(
      builder: (context, tunnelClient, child) {
        final isConnected = tunnelClient.isConnected;
        final error = tunnelClient.lastError;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            'HTTP Polling Connection',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isConnected
                                ? 'Connected and active'
                                : 'Disconnected',
                            style: TextStyle(
                              color: isConnected
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Error: $error',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildHttpPollingInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HTTP Polling Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Connection Type', 'HTTP Long Polling'),
            _buildInfoRow('Protocol', 'HTTPS'),
            _buildInfoRow('Authentication', 'JWT Token'),
            _buildInfoRow('Configuration', 'Automatic'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'HTTP polling requires no manual configuration. '
                      'Simply authenticate and the connection will be established automatically.',
                      style: TextStyle(color: Colors.blue[700]),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Consumer<HttpPollingTunnelClient>(
      builder: (context, tunnelClient, child) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _testConnection(tunnelClient),
                icon: const Icon(Icons.network_check),
                label: const Text('Test Connection'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _reconnect(tunnelClient),
                icon: const Icon(Icons.refresh),
                label: const Text('Reconnect'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _testConnection(HttpPollingTunnelClient tunnelClient) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing HTTP polling connection...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await tunnelClient.connect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tunnelClient.isConnected
                  ? 'Connection test successful'
                  : 'Connection test failed',
            ),
            backgroundColor: tunnelClient.isConnected
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reconnect(HttpPollingTunnelClient tunnelClient) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reconnecting...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await tunnelClient.disconnect();
      await tunnelClient.connect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tunnelClient.isConnected
                  ? 'Reconnection successful'
                  : 'Reconnection failed',
            ),
            backgroundColor: tunnelClient.isConnected
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reconnection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
