import 'dart:async';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket implementation of SSHSocket for tunneling SSH over WebSocket
///
/// This adapter allows SSH connections to be transported over WebSocket instead of
/// raw TCP, which helps bypass restrictive firewalls that block TCP but allow HTTP/HTTPS.
class WebSocketSSHSocket implements SSHSocket {
  final WebSocketChannel _channel;
  final Completer<void> _done = Completer<void>();
  final Completer<void> _ready = Completer<void>();

  bool _isClosed = false;

  WebSocketSSHSocket._(this._channel) {
    // Mark as ready when WebSocket is connected
    _ready.complete();
  }

  /// Connect to a WebSocket URL and return a WebSocketSSHSocket
  static Future<WebSocketSSHSocket> connect(Uri wsUri,
      {Map<String, String>? headers}) async {
    try {
      final channel = WebSocketChannel.connect(wsUri);
      final socket = WebSocketSSHSocket._(channel);

      // Wait for WebSocket to be ready
      await socket._ready.future;

      return socket;
    } catch (e) {
      throw Exception('Failed to connect WebSocket: $e');
    }
  }

  @override
  Stream<Uint8List> get stream {
    return _channel.stream.map<Uint8List>((data) {
      if (data is Uint8List) {
        return data;
      } else if (data is List<int>) {
        return Uint8List.fromList(data);
      } else if (data is String) {
        return Uint8List.fromList(data.codeUnits);
      } else {
        throw Exception('Unexpected data type: ${data.runtimeType}');
      }
    });
  }

  @override
  StreamSink<List<int>> get sink {
    if (_isClosed) {
      throw Exception('WebSocket SSH socket is closed');
    }
    return _WebSocketSinkAdapter(_channel.sink);
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;

    _isClosed = true;
    try {
      await _channel.sink.close();
    } catch (e) {
      // Ignore close errors
    }

    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  void destroy() {
    if (_isClosed) return;

    _isClosed = true;
    try {
      _channel.sink.close();
    } catch (e) {
      // Ignore destroy errors
    }

    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  String toString() => 'WebSocketSSHSocket(${_channel.hashCode})';
}

/// Adapter to convert WebSocketSink to StreamSink&lt;List&lt;int&gt;&gt;
class _WebSocketSinkAdapter implements StreamSink<List<int>> {
  final WebSocketSink _sink;
  bool _isClosed = false;

  _WebSocketSinkAdapter(this._sink);

  @override
  void add(List<int> data) {
    _sink.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _sink.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return _sink.addStream(stream);
  }

  @override
  Future<void> close() {
    _isClosed = true;
    return _sink.close();
  }

  @override
  Future<void> get done => _sink.done;

  bool get isClosed => _isClosed;
}
