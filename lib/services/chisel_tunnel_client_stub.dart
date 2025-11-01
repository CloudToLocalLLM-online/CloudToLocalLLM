// Web stub for ChiselTunnelClient - not available on web
import 'package:flutter/foundation.dart';
import '../models/tunnel_config.dart';

/// Stub class for Chisel tunnel client on web platform
/// Chisel runs on desktop only, web uses API directly
class ChiselTunnelClient with ChangeNotifier {
  // ignore: unused_field
  final TunnelConfig _config;
  bool _isConnected = false;
  int? _tunnelPort;

  ChiselTunnelClient(this._config);

  bool get isConnected => _isConnected;
  int? get tunnelPort => _tunnelPort;

  Future<void> connect() async {
    debugPrint('[Chisel] Chisel tunnel not available on web platform');
  }

  Future<void> disconnect() async {}
  
  @override
  void dispose() {
    super.dispose();
    _isConnected = false;
    _tunnelPort = null;
  }
}

