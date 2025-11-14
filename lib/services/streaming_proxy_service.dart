import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Service for managing streaming proxy connections
/// Handles proxy lifecycle, status monitoring, and connection management
class StreamingProxyService extends ChangeNotifier {
  final String _baseUrl;
  final Duration _timeout;
  final AuthService? _authService;
  final Dio _dio = Dio();

  bool _isProxyRunning = false;
  String? _proxyId;
  DateTime? _proxyCreatedAt;
  String? _error;
  bool _isLoading = false;

  StreamingProxyService({
    String? baseUrl,
    Duration? timeout,
    AuthService? authService,
  }) : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _timeout = timeout ?? AppConfig.apiTimeout,
       _authService = authService {
    _setupDio();
    if (kDebugMode) {
      debugPrint('[StreamingProxy] Service initialized');
      debugPrint('[StreamingProxy] Base URL: $_baseUrl');
    }
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = _timeout;
    _dio.options.receiveTimeout = _timeout;
  }

  // Getters
  bool get isProxyRunning => _isProxyRunning;
  String? get proxyId => _proxyId;
  DateTime? get proxyCreatedAt => _proxyCreatedAt;
  String? get error => _error;
  bool get isLoading => _isLoading;

  /// Get HTTP headers with authentication
  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_authService != null) {
      final accessToken = await _authService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    return headers;
  }

  /// Start streaming proxy for current user
  Future<bool> startProxy() async {
    try {
      _setLoading(true);
      _clearError();

      if (kDebugMode) {
        debugPrint('[StreamingProxy] Starting proxy...');
      }

      final headers = await _getHeaders();
      final response = await _dio.post(
        '/api/proxy/start',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          _proxyId = data['proxy']['proxyId'];
          _proxyCreatedAt = DateTime.parse(data['proxy']['createdAt']);
          _isProxyRunning = true;

          if (kDebugMode) {
            debugPrint('[StreamingProxy] Proxy started: $_proxyId');
          }

          notifyListeners();
          return true;
        } else {
          _setError('Failed to start proxy: ${data['message']}');
          return false;
        }
      } else {
        final errorData = response.data;
        _setError('Failed to start proxy: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to start proxy: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Start error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Stop streaming proxy for current user
  Future<bool> stopProxy() async {
    try {
      _setLoading(true);
      _clearError();

      if (kDebugMode) {
        debugPrint('[StreamingProxy] Stopping proxy...');
      }

      final headers = await _getHeaders();
      final response = await _dio.post(
        '/api/proxy/stop',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          _proxyId = null;
          _proxyCreatedAt = null;
          _isProxyRunning = false;

          if (kDebugMode) {
            debugPrint('[StreamingProxy] Proxy stopped successfully');
          }

          notifyListeners();
          return true;
        } else {
          _setError('Failed to stop proxy: ${data['message']}');
          return false;
        }
      } else {
        final errorData = response.data;
        _setError('Failed to stop proxy: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to stop proxy: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Stop error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get streaming proxy status
  Future<bool> checkProxyStatus() async {
    try {
      _setLoading(true);
      _clearError();

      final headers = await _getHeaders();
      final response = await _dio.get(
        '/api/proxy/status',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        _isProxyRunning = data['status'] == 'running';

        if (_isProxyRunning) {
          _proxyId = data['proxyId'];
          if (data['createdAt'] != null) {
            _proxyCreatedAt = DateTime.parse(data['createdAt']);
          }
        } else {
          _proxyId = null;
          _proxyCreatedAt = null;
        }

        if (kDebugMode) {
          debugPrint('[StreamingProxy] Status: ${data['status']}');
        }

        notifyListeners();
        return _isProxyRunning;
      } else {
        final errorData = response.data;
        _setError('Failed to check proxy status: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to check proxy status: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Status check error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Ensure proxy is running (start if not running)
  Future<bool> ensureProxyRunning() async {
    // First check current status
    await checkProxyStatus();

    // Start proxy if not running
    if (!_isProxyRunning) {
      return await startProxy();
    }

    return true;
  }

  /// Get proxy uptime
  Duration? get proxyUptime {
    if (_proxyCreatedAt == null) return null;
    return DateTime.now().difference(_proxyCreatedAt!);
  }

  /// Get formatted proxy uptime
  String get formattedUptime {
    final uptime = proxyUptime;
    if (uptime == null) return 'N/A';

    final hours = uptime.inHours;
    final minutes = uptime.inMinutes % 60;
    final seconds = uptime.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up any resources
    super.dispose();
  }
}
