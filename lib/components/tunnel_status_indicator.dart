import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tunnel_configuration_service.dart';
import '../services/desktop_client_detection_service.dart';
import 'tunnel_management_panel.dart';

/// Tunnel Status Indicator - Shows tunnel connection status in app header
///
/// Displays a color-coded icon indicating tunnel connection state:
/// - Green: Connected and working
/// - Orange: Connecting or partial connection
/// - Red: Disconnected or error
/// - Gray: Not applicable (desktop platform)
class TunnelStatusIndicator extends StatefulWidget {
  const TunnelStatusIndicator({super.key});

  @override
  State<TunnelStatusIndicator> createState() => _TunnelStatusIndicatorState();
}

class _TunnelStatusIndicatorState extends State<TunnelStatusIndicator> {
  bool _isPanelOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _closePanel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return Consumer2<TunnelConfigurationService, DesktopClientDetectionService>(
      builder: (context, tunnelService, clientDetection, child) {
        final tunnelStatus = _getTunnelStatus(
          tunnelService,
          clientDetection,
        );

        return Tooltip(
          message: tunnelStatus.tooltip,
          child: InkWell(
            onTap: _togglePanel,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              key: const Key('tunnel-status-indicator'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // Add subtle background for better visibility
                color:
                    tunnelStatus.isConnecting ||
                        !tunnelStatus.text.contains('Connected')
                    ? tunnelStatus.color.withValues(alpha: 0.1)
                    : null,
                border:
                    tunnelStatus.text.contains('No Client') ||
                        tunnelStatus.text.contains('Disconnected')
                    ? Border.all(
                        color: tunnelStatus.color.withValues(alpha: 0.5),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status icon with animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: Stack(
                      children: [
                        Icon(
                          tunnelStatus.icon,
                          color: tunnelStatus.color,
                          size: 24,
                        ),
                        // Connecting animation
                        if (tunnelStatus.isConnecting)
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                tunnelStatus.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Status text
                  Text(
                    tunnelStatus.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Dropdown arrow
                  Icon(
                    _isPanelOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TunnelStatusInfo _getTunnelStatus(
    TunnelConfigurationService tunnelService,
    DesktopClientDetectionService clientDetection,
  ) {
    final isConnected = tunnelService.tunnelClient?.isConnected ?? false;
    final hasError = tunnelService.lastError != null;
    final hasDesktopClients = clientDetection.hasConnectedClients;
    final clientCount = clientDetection.connectedClientCount;

    if (isConnected && hasDesktopClients) {
      return TunnelStatusInfo(
        icon: Icons.check_circle,
        color: Colors.green,
        text: 'Connected',
        tooltip:
            'Tunnel connected with $clientCount desktop client${clientCount == 1 ? '' : 's'}',
        isConnecting: false,
      );
    } else if (hasError) {
      return TunnelStatusInfo(
        icon: Icons.error,
        color: Colors.red,
        text: 'Error',
        tooltip: 'Tunnel connection error: ${tunnelService.lastError}',
        isConnecting: false,
      );
    } else if (!hasDesktopClients) {
      return TunnelStatusInfo(
        icon: Icons.desktop_access_disabled,
        color: Colors.orange,
        text: 'No Client',
        tooltip:
            'No desktop client connected. Download and run the desktop client.',
        isConnecting: false,
      );
    } else {
      return TunnelStatusInfo(
        icon: Icons.cloud_off,
        color: Colors.red,
        text: 'Disconnected',
        tooltip: 'Tunnel disconnected. Click to manage connection.',
        isConnecting: false,
      );
    }
  }

  void _togglePanel() {
    if (_isPanelOpen) {
      _closePanel();
    } else {
      _openPanel();
    }
  }

  void _openPanel() {
    if (_isPanelOpen) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => TunnelManagementPanel(onClose: _closePanel),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isPanelOpen = true;
    });
  }

  void _closePanel() {
    if (!_isPanelOpen) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isPanelOpen = false;
    });
  }
}

/// Data class for tunnel status information
class TunnelStatusInfo {
  final IconData icon;
  final Color color;
  final String text;
  final String tooltip;
  final bool isConnecting;

  const TunnelStatusInfo({
    required this.icon,
    required this.color,
    required this.text,
    required this.tooltip,
    required this.isConnecting,
  });
}
