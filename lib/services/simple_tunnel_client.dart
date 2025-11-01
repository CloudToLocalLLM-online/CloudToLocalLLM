import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../models/tunnel_config.dart';

// Message Types (matching the server-side message-protocol.js)
class MessageTypes {
  static const String httpRequest = 'http_request';
  static const String httpResponse = 'http_response';
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String error = 'error';
}

class SimpleTunnelClient with ChangeNotifier {
  final TunnelConfig _config;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final Uuid _uuid = const Uuid();

  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  SimpleTunnelClient(this._config);

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;
    _reconnectAttempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_isConnected) return;

    final uri = Uri.parse('${_config.cloudProxyUrl}?token=${_config.authToken}');
    debugPrint('[SimpleTunnelClient] Connecting to $uri...');

    try {
      _channel = IOWebSocketChannel.connect(uri);

      // Wait for the channel to be ready
      await _channel!.ready;

      _isConnected = true;
      _reconnectAttempts = 0;
      notifyListeners();
      debugPrint('[SimpleTunnelClient] Connection established.');

      _channel!.stream.listen(
        _handleMessage,
        onDone: () {
          debugPrint('[SimpleTunnelClient] Connection closed.');
          _handleDisconnection();
        },
        onError: (error) {
          debugPrint('[SimpleTunnelClient] Connection error: $error');
          _handleDisconnection();
        },
      );
    } catch (e) {
      debugPrint('[SimpleTunnelClient] Connection failed: $e');
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    if (!_isConnected) return;
    _isConnected = false;
    _channel?.sink.close();
    notifyListeners();
    _reconnect();
  }

  void _reconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    final backoffTime = _getReconnectDelay();
    _reconnectAttempts++;
    debugPrint('[SimpleTunnelClient] Reconnecting in ${backoffTime.inSeconds} seconds...');
    _reconnectTimer = Timer(backoffTime, _doConnect);
  }

  Duration _getReconnectDelay() {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, then 30s
    if (_reconnectAttempts >= 5) return const Duration(seconds: 30);
    return Duration(seconds: 1 << _reconnectAttempts);
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
      final type = decoded['type'] as String?;

      switch (type) {
        case MessageTypes.httpResponse:
          _handleHttpResponse(decoded);
          break;
        case MessageTypes.ping:
          _handlePing(decoded);
          break;
        case MessageTypes.error:
          _handleError(decoded);
          break;
        default:
          debugPrint('[SimpleTunnelClient] Received unknown message type: $type');
      }
    } catch (e) {
      debugPrint('[SimpleTunnelClient] Failed to handle message: $e');
    }
  }

  void _handleHttpResponse(Map<String, dynamic> message) {
    final id = message['id'] as String?;
    if (id != null && _pendingRequests.containsKey(id)) {
      _pendingRequests.remove(id)!.complete(message);
    }
  }

  void _handlePing(Map<String, dynamic> message) {
    final id = message['id'] as String?;
    _sendMessage({
      'type': MessageTypes.pong,
      'id': id,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _handleError(Map<String, dynamic> message) {
    final id = message['id'] as String?;
    final error = message['error'] as String? ?? 'Unknown error';
    if (id != null && _pendingRequests.containsKey(id)) {
      _pendingRequests.remove(id)!.completeError(Exception('Server error: $error'));
    } else {
      debugPrint('[SimpleTunnelClient] Received a server error: $error');
    }
  }

  Future<Map<String, dynamic>> forwardRequest(Map<String, dynamic> httpRequest) {
    if (!_isConnected) {
      throw Exception('Not connected to the tunnel.');
    }

    final id = _uuid.v4();
    final message = {
      'type': MessageTypes.httpRequest,
      'id': id,
      ...httpRequest,
    };

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    _sendMessage(message);

    return completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
      _pendingRequests.remove(id);
      throw TimeoutException('Request timed out');
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      final encoded = jsonEncode(message);
      _channel!.sink.add(encoded);
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
