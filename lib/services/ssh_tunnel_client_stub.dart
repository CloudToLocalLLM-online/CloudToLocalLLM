// Web stub for SSH tunnel client - not available on web
import 'package:flutter/foundation.dart';
import '../models/tunnel_config.dart';

/// Stub class for SSH tunnel client on web platform
/// SSH tunnel runs on desktop only, web uses cloud proxy directly
class SSHTunnelClient with ChangeNotifier {
  // ignore: unused_field
  final TunnelConfig _config;
  bool _isConnected = false;
  int? _tunnelPort;

  SSHTunnelClient(this._config);

  bool get isConnected => _isConnected;
  int? get tunnelPort => _tunnelPort;

  Future<void> connect() async {
    debugPrint('[SSH] SSH tunnel not available on web platform');
  }

  Future<void> disconnect() async {}

  @override
  void dispose() {
    super.dispose();
    _isConnected = false;
    _tunnelPort = null;
  }
}