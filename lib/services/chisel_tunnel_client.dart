import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/tunnel_config.dart';

/// Chisel tunnel client for establishing reverse proxy connections
/// 
/// Chisel is a fast TCP/UDP tunnel over HTTP. This client runs the Chisel
/// binary to establish a reverse tunnel from the server to localhost:11434.
class ChiselTunnelClient with ChangeNotifier {
  final TunnelConfig _config;
  Process? _chiselProcess;
  bool _isConnected = false;
  int? _tunnelPort;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  StreamSubscription? _stdoutSubscription;
  StreamSubscription? _stderrSubscription;

  ChiselTunnelClient(this._config);

  bool get isConnected => _isConnected;
  int? get tunnelPort => _tunnelPort;

  /// Connect to Chisel server
  Future<void> connect() async {
    if (_isConnected) {
      debugPrint('[Chisel] Already connected');
      return;
    }

    _reconnectAttempts = 0;
    await _doConnect();
  }

  /// Internal connect method
  Future<void> _doConnect() async {
    if (_isConnected) return;

    try {
      debugPrint('[Chisel] Connecting to Chisel server...');

      // Get Chisel binary path
      final chiselPath = await _getChiselPath();
      
      // Extract server URL and port from cloudProxyUrl
      final serverUri = Uri.parse(_config.cloudProxyUrl.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://'));
      final serverHost = serverUri.host;
      final serverPort = serverUri.port != 0 ? serverUri.port : 8080;

      // Chisel reverse tunnel: R:serverPort:localhost:localPort
      // This creates a reverse tunnel where the server listens on serverPort
      // and forwards to localhost:11434 on the client
      final args = [
        'client',
        '$serverHost:$serverPort',
        'R:0:localhost:${_extractLocalPort(_config.localBackendUrl)}',
        '--auth', _config.authToken,
        '--keepalive', '30s',
      ];

      debugPrint('[Chisel] Starting process: $chiselPath');
      debugPrint('[Chisel] Args: ${args.join(' ')}');

      _chiselProcess = await Process.start(
        chiselPath,
        args,
        mode: ProcessStartMode.normal,
      );

      // Monitor stdout for connection status
      _stdoutSubscription = _chiselProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleOutput);

      // Monitor stderr for errors
      _stderrSubscription = _chiselProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleError);

      // Monitor process exit
      _chiselProcess!.exitCode.then((code) {
        debugPrint('[Chisel] Process exited with code $code');
        _handleDisconnection();
      });

      // Wait a moment for connection to establish
      await Future.delayed(const Duration(seconds: 2));

      // Check if process is still running
      if (_chiselProcess != null && await _chiselProcess!.exitCode.then((_) => false, onError: (_) => true)) {
        _isConnected = true;
        _reconnectAttempts = 0;
        notifyListeners();
        debugPrint('[Chisel] Connection established');
      } else {
        throw Exception('Chisel process failed to start');
      }

    } catch (e) {
      debugPrint('[Chisel] Connection failed: $e');
      _handleDisconnection();
      rethrow;
    }
  }

  /// Handle stdout output
  void _handleOutput(String line) {
    debugPrint('[Chisel stdout] $line');
    
    // Parse port from output if Chisel reports it
    // Format may vary: "Connected (server may assign port)"
    final portMatch = RegExp(r'(?:port|assigned)\s*:?\s*(\d+)', caseSensitive: false).firstMatch(line);
    if (portMatch != null) {
      final port = int.tryParse(portMatch.group(1)!);
      if (port != null) {
        _tunnelPort = port;
        notifyListeners();
      }
    }

    // Check for connection success messages
    if (line.toLowerCase().contains('connected') || 
        line.toLowerCase().contains('tunnel')) {
      if (!_isConnected) {
        _isConnected = true;
        _reconnectAttempts = 0;
        notifyListeners();
      }
    }
  }

  /// Handle stderr output
  void _handleError(String line) {
    debugPrint('[Chisel stderr] $line');
    
    // Check for error conditions
    if (line.toLowerCase().contains('error') ||
        line.toLowerCase().contains('failed') ||
        line.toLowerCase().contains('refused')) {
      _handleDisconnection();
    }
  }

  /// Extract local port from URL
  int _extractLocalPort(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.port != 0 ? uri.port : 11434; // Default Ollama port
    } catch (e) {
      return 11434;
    }
  }

  /// Get Chisel binary path
  Future<String> _getChiselPath() async {
    // TODO: Bundle Chisel binaries with the app
    // For now, assume Chisel is in PATH or use platform-specific defaults
    
    if (Platform.isWindows) {
      // Try common locations
      final paths = [
        'chisel.exe',
        'assets/chisel/chisel-windows.exe',
        r'C:\Program Files\chisel\chisel.exe',
      ];
      
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          return path;
        }
      }
      
      // Fallback to PATH
      return 'chisel.exe';
    } else if (Platform.isMacOS) {
      final paths = [
        'chisel',
        'assets/chisel/chisel-darwin',
        '/usr/local/bin/chisel',
      ];
      
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          return path;
        }
      }
      
      return 'chisel';
    } else {
      // Linux
      final paths = [
        'chisel',
        'assets/chisel/chisel-linux',
        '/usr/local/bin/chisel',
        '/usr/bin/chisel',
      ];
      
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          return path;
        }
      }
      
      return 'chisel';
    }
  }

  /// Handle disconnection
  void _handleDisconnection() {
    if (!_isConnected) return;
    
    _isConnected = false;
    _tunnelPort = null;
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _chiselProcess?.kill();
    _chiselProcess = null;
    
    notifyListeners();
    debugPrint('[Chisel] Disconnected, attempting reconnect...');
    
    _reconnect();
  }

  /// Reconnect with exponential backoff
  void _reconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    final backoffTime = _getReconnectDelay();
    _reconnectAttempts++;
    
    debugPrint('[Chisel] Reconnecting in ${backoffTime.inSeconds} seconds (attempt $_reconnectAttempts)...');
    
    _reconnectTimer = Timer(backoffTime, () {
      _doConnect();
    });
  }

  /// Get reconnection delay with exponential backoff
  Duration _getReconnectDelay() {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, then 30s max
    if (_reconnectAttempts >= 5) {
      return const Duration(seconds: 30);
    }
    return Duration(seconds: 1 << _reconnectAttempts);
  }

  /// Disconnect from Chisel server
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _chiselProcess?.kill();
    _chiselProcess = null;
    _isConnected = false;
    _tunnelPort = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _chiselProcess?.kill();
    super.dispose();
  }
}

