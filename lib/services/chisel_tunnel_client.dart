import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  String? _tunnelId; // Chisel tunnel identifier

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
      await Future.delayed(const Duration(seconds: 3));

      // Check if process is still running
      if (_chiselProcess != null) {
        // Try to check if process is still alive (exitCode throws if process is running)
        try {
          await _chiselProcess!.exitCode.timeout(const Duration(seconds: 1));
          // If we get here, process already exited
          throw Exception('Chisel process exited immediately');
        } catch (e) {
          // Timeout or error means process is still running (good)
          if (e is TimeoutException || e.toString().contains('TimeoutException')) {
            _isConnected = true;
            _reconnectAttempts = 0;
            
            // Register with server
            await _registerWithServer();
            
            notifyListeners();
            debugPrint('[Chisel] Connection established');
          } else {
            throw e;
          }
        }
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

    // Extract tunnel ID if present
    final tunnelIdMatch = RegExp(r'tunnel[:\s]+([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(line);
    if (tunnelIdMatch != null && _tunnelId == null) {
      _tunnelId = tunnelIdMatch.group(1);
      debugPrint('[Chisel] Tunnel ID: $_tunnelId');
    }

    // Check for connection success messages
    if (line.toLowerCase().contains('connected') || 
        line.toLowerCase().contains('tunnel')) {
      // Connection will be set in _doConnect after registration
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

  /// Register tunnel with server
  Future<void> _registerWithServer() async {
    try {
      final serverUrl = _config.cloudProxyUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://');
      final baseUrl = serverUrl.substring(0, serverUrl.lastIndexOf(':'));
      
      final registerUrl = Uri.parse('$baseUrl/api/tunnel/register');
      
      // Generate tunnel ID if not set
      _tunnelId ??= 'tunnel_${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        registerUrl,
        headers: {
          'Authorization': 'Bearer ${_config.authToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'tunnelId': _tunnelId,
          'localPort': _extractLocalPort(_config.localBackendUrl),
          'serverPort': _tunnelPort,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _tunnelPort = data['serverPort'] as int? ?? _tunnelPort;
        debugPrint('[Chisel] Registered with server: port $_tunnelPort');
      } else {
        debugPrint('[Chisel] Registration failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[Chisel] Error registering with server: $e');
      // Don't throw - connection may still work
    }
  }

  /// Get Chisel binary path
  /// Checks bundled assets first, then system PATH
  Future<String> _getChiselPath() async {
    // Determine architecture
    final arch = _getArchitecture();
    
    if (Platform.isWindows) {
      // Try bundled binary first
      final bundledPaths = [
        'assets/chisel/chisel-windows${arch == 'arm64' ? 'arm64' : ''}.exe',
        'assets/chisel/chisel-windows.exe',
      ];
      
      for (final path in bundledPaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            // Copy to temp directory for execution
            final tempDir = await Directory.systemTemp.createTemp('chisel');
            final tempPath = '${tempDir.path}/chisel.exe';
            await file.copy(tempPath);
            debugPrint('[Chisel] Using bundled binary: $path');
            return tempPath;
          }
        } catch (e) {
          debugPrint('[Chisel] Error checking $path: $e');
        }
      }
      
      // Fallback to PATH
      return 'chisel.exe';
    } else if (Platform.isMacOS) {
      final bundledPaths = [
        'assets/chisel/chisel-darwin${arch == 'arm64' ? 'arm64' : ''}',
        'assets/chisel/chisel-darwin',
      ];
      
      for (final path in bundledPaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            // Copy to temp directory for execution
            final tempDir = await Directory.systemTemp.createTemp('chisel');
            final tempPath = '${tempDir.path}/chisel';
            await file.copy(tempPath);
            // Make executable
            await Process.run('chmod', ['+x', tempPath]);
            debugPrint('[Chisel] Using bundled binary: $path');
            return tempPath;
          }
        } catch (e) {
          debugPrint('[Chisel] Error checking $path: $e');
        }
      }
      
      // Fallback to PATH
      return 'chisel';
    } else {
      // Linux
      final bundledPaths = [
        'assets/chisel/chisel-linux${arch == 'arm64' ? 'arm64' : ''}',
        'assets/chisel/chisel-linux',
      ];
      
      for (final path in bundledPaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            // Copy to temp directory for execution
            final tempDir = await Directory.systemTemp.createTemp('chisel');
            final tempPath = '${tempDir.path}/chisel';
            await file.copy(tempPath);
            // Make executable
            await Process.run('chmod', ['+x', tempPath]);
            debugPrint('[Chisel] Using bundled binary: $path');
            return tempPath;
          }
        } catch (e) {
          debugPrint('[Chisel] Error checking $path: $e');
        }
      }
      
      // Fallback to PATH
      return 'chisel';
    }
  }

  /// Get system architecture
  String _getArchitecture() {
    // For now, default to amd64
    // In production, you'd detect actual architecture
    // This is a simplified version
    return 'amd64'; // TODO: Detect actual architecture
  }

  /// Handle disconnection
  void _handleDisconnection() {
    if (!_isConnected) return;
    
    _isConnected = false;
    _tunnelPort = null;
    _tunnelId = null;
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _chiselProcess?.kill();
    _chiselProcess = null;
    
    // Unregister asynchronously (don't wait)
    _unregisterFromServer();
    
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

  /// Unregister from server
  Future<void> _unregisterFromServer() async {
    if (_tunnelId == null) return;

    try {
      final serverUrl = _config.cloudProxyUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://');
      final baseUrl = serverUrl.substring(0, serverUrl.lastIndexOf(':'));

      await http.post(
        Uri.parse('$baseUrl/api/tunnel/unregister'),
        headers: {
          'Authorization': 'Bearer ${_config.authToken}',
          'Content-Type': 'application/json',
        },
      );
      debugPrint('[Chisel] Unregistered from server');
    } catch (e) {
      debugPrint('[Chisel] Error unregistering from server: $e');
    }
  }

  /// Disconnect from Chisel server
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _unregisterFromServer();
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _chiselProcess?.kill();
    _chiselProcess = null;
    _isConnected = false;
    _tunnelPort = null;
    _tunnelId = null;
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

