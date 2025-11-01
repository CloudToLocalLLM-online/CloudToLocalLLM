import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tunnel_service.dart';
import '../config/theme.dart';
import 'tunnel_status_dialog.dart';

class TunnelStatusButton extends StatelessWidget {
  const TunnelStatusButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TunnelService>(
      builder: (context, tunnelService, child) {
        final state = tunnelService.state;
        IconData icon;
        Color color;
        String tooltip;

        if (state.isConnected) {
          icon = Icons.gpp_good;
          color = Colors.green;
          tooltip = 'Tunnel Connected';
        } else if (state.isConnecting) {
          icon = Icons.hourglass_empty;
          color = Colors.orange;
          tooltip = 'Tunnel Connecting';
        } else {
          icon = Icons.gpp_bad;
          color = AppTheme.dangerColor;
          tooltip = 'Tunnel Disconnected';
        }

        return Positioned(
          bottom: 16,
          right: 16,
          child: Tooltip(
            message: tooltip,
            child: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const TunnelStatusDialog(),
                );
              },
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
