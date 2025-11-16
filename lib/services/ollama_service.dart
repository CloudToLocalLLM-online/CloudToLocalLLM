import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'provider_discovery_service.dart';
import '../models/llm_communication_error.dart';

/// Service for communicating with Ollama API
/// - Web: Uses cloud relay through API backend with authentication
/// - Desktop: Direct connection to localhost Ollama
class OllamaService extends ChangeNotifier {
  final String _baseUrl;
  final Duration _timeout;
  final AuthService? _authService;
  final bool _isWeb;
  final Dio _dio = Dio();

  bool _isConnected = false;
  String? _version;
  List<OllamaModel> _models = [];
  bool _isLoading = false;
  String? _error;

  OllamaService({String? baseUrl, Duration? timeout, AuthService? authService})
      : _isWeb = kIsWeb,
        _baseUrl = baseUrl ??
            (kIsWeb ? AppConfig.cloudOllamaUrl : AppConfig.defaultOllamaUrl),
        _timeout = timeout ?? AppConfig.ollamaTimeout,
        _authService = authService {
    _setupDio();
    // Debug logging for service initialization
    if (kDebugMode) {
      debugPrint('[DEBUG] OllamaService initialized:');
      debugPrint('[DEBUG] - Platform: ${_isWeb ? 'Web' : 'Desktop'}');
      debugPrint('[DEBUG] - Base URL: $_baseUrl');
      if (_isWeb) {
        debugPrint(
          '[DEBUG] - Connection Type: Cloud Proxy Tunnel (prevents CORS errors)',
        );
        debugPrint('[DEBUG] - Tunnel Endpoint: $_baseUrl');
      } else {
        debugPrint('[DEBUG] - Connection Type: Direct Local Connection');
      }
      debugPrint('[DEBUG] - Timeout: $_timeout');
      debugPrint(
        '[DEBUG] - Auth Service: ${_authService != null ? 'provided' : 'null'}',
      );
      AppConfig.logConfiguration();
    }
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = _timeout;
    _dio.options.receiveTimeout = _timeout;
  }

  /// Initialize the service and test connection
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('[DEBUG] OllamaService initializing...');
    }

    // For web platform, wait a moment for authentication to be ready
    if (_isWeb && _authService != null) {
      // Wait for auth service to be ready
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Test connection automatically
    await testConnection();

    if (kDebugMode) {
      debugPrint('[DEBUG] OllamaService initialization complete');
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get version => _version;
  List<OllamaModel> get models => _models;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isWeb => _isWeb;

  /// Build HTTP headers, enforcing authentication on web.
  Future<Map<String, String>?> _buildRequestHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (!_isWeb || _authService == null) {
      return headers;
    }

    final accessToken = await _authService.getValidatedAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (kDebugMode) {
        debugPrint('[DEBUG] No access token available for Ollama web request');
      }
      return null;
    }

    headers['Authorization'] = 'Bearer $accessToken';
    return headers;
  }

  /// Test connection to Ollama server (platform-aware)
  Future<bool> testConnection() async {
    try {
      _setLoading(true);
      _clearError();

      final url = _isWeb ? AppConfig.bridgeStatusUrl : '$_baseUrl/api/version';
      if (kDebugMode) {
        debugPrint(
          '[DEBUG] Making ${_isWeb ? 'authenticated' : 'direct'} request to: $url',
        );
      }

      final headers = await _buildRequestHeaders();
      if (_isWeb && headers == null) {
        debugPrint(
            '[DEBUG] Skipping Ollama bridge status check until user authenticates');
        _isConnected = false;
        _clearError();
        return false;
      }

      final response = await _dio.get(url, options: Options(headers: headers));

      if (response.statusCode == 200) {
        final data = response.data;
        if (_isWeb) {
          // For web, check bridge status response
          _isConnected = data['status'] == 'healthy' || data['bridges'] != null;
          _version = 'Bridge Connected';
          debugPrint(
            'Connected to Ollama bridge: ${data['bridges'] ?? 0} bridges',
          );
        } else {
          // For desktop, check direct Ollama response
          _version = data['version'] as String?;
          _isConnected = true;
          debugPrint('Connected to Ollama v$_version directly');
        }

        // Load models when connection is successful
        if (_isConnected) {
          await getModels();
        }
        return _isConnected;
      } else {
        _setError('Failed to connect: HTTP ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      _setError('Connection failed: $e');
      _isConnected = false;
      debugPrint('Ollama connection error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get list of available models (platform-aware)
  Future<List<OllamaModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      final url = _isWeb ? '$_baseUrl/api/tags' : '$_baseUrl/api/tags';
      debugPrint('[DEBUG] Getting models from: $url');

      final headers = await _buildRequestHeaders();
      if (_isWeb && headers == null) {
        debugPrint('[DEBUG] Skipping model discovery until user authenticates');
        return [];
      }

      final response = await _dio.get(url, options: Options(headers: headers));

      if (response.statusCode == 200) {
        final data = response.data;
        final modelsList = data['models'] as List<dynamic>? ?? [];

        _models =
            modelsList.map((model) => OllamaModel.fromJson(model)).toList();
        debugPrint(
          'Found ${_models.length} Ollama models via ${_isWeb ? 'bridge' : 'direct connection'}',
        );
        return _models;
      } else {
        _setError('Failed to get models: HTTP ${response.statusCode}');
        debugPrint(
          '[DEBUG] Models request failed with status: ${response.statusCode}',
        );
        debugPrint('[DEBUG] Response body: ${response.data}');
        return [];
      }
    } catch (e) {
      _setError('Failed to get models: $e');
      debugPrint('Error getting Ollama models: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Send a chat message to Ollama (platform-aware)
  Future<String?> chat({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final url = _isWeb ? '$_baseUrl/api/chat' : '$_baseUrl/api/chat';
      debugPrint('[DEBUG] Sending chat message to: $url');

      final headers = await _buildRequestHeaders();
      if (_isWeb && headers == null) {
        debugPrint('[DEBUG] Skipping chat request until user authenticates');
        return null;
      }

      final response = await _dio.post(
        url,
        data: {
          'model': model,
          'messages': messages,
          'stream': false,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final responseMessage = data['message']?['content'] as String?;
        debugPrint(
          'Chat response received via ${_isWeb ? 'bridge' : 'direct connection'}',
        );
        return responseMessage;
      } else {
        _setError('Chat failed: HTTP ${response.statusCode}');
        debugPrint(
          '[DEBUG] Chat request failed with status: ${response.statusCode}',
        );
        debugPrint('[DEBUG] Response body: ${response.data}');
        return null;
      }
    } catch (e) {
      _setError('Chat failed: $e');
      debugPrint('Ollama chat error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Pull a model from Ollama registry (platform-aware)
  Future<bool> pullModel(String modelName) async {
    try {
      _setLoading(true);
      _clearError();

      final url = _isWeb ? '$_baseUrl/api/pull' : '$_baseUrl/api/pull';
      debugPrint('[DEBUG] Pulling model from: $url');

      final headers = await _buildRequestHeaders();
      if (_isWeb && headers == null) {
        debugPrint('[DEBUG] Skipping model pull until user authenticates');
        return false;
      }

      final response = await _dio.post(
        url,
        data: {'name': modelName},
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      final success = response.statusCode == 200;
      debugPrint(
        '[DEBUG] Model pull ${success ? 'successful' : 'failed'} via ${_isWeb ? 'bridge' : 'direct connection'}',
      );
      if (!success) {
        debugPrint('[DEBUG] Pull response: ${response.data}');
      }

      // Refresh models list if successful
      if (success) {
        await getModels();
      }

      return success;
    } catch (e) {
      _setError('Failed to pull model: $e');
      debugPrint('Error pulling model: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a model from Ollama (platform-aware)
  Future<bool> deleteModel(String modelName) async {
    try {
      _setLoading(true);
      _clearError();

      final url = _isWeb ? '$_baseUrl/api/delete' : '$_baseUrl/api/delete';
      debugPrint('[OllamaService] Deleting model from: $url');

      final headers = await _buildRequestHeaders();
      if (_isWeb && headers == null) {
        debugPrint(
            '[OllamaService] Skipping model delete until user authenticates');
        return false;
      }

      final response = await _dio.post(
        url,
        data: {'name': modelName},
        options: Options(headers: headers),
      );

      final success = response.statusCode == 200;
      debugPrint(
        '[OllamaService] Model deletion ${success ? 'successful' : 'failed'} via ${_isWeb ? 'bridge' : 'direct connection'}',
      );

      if (!success) {
        debugPrint('[OllamaService] Delete response: ${response.data}');
        _setError('Failed to delete model: HTTP ${response.statusCode}');
      } else {
        // Refresh models list after successful deletion
        await getModels();
      }

      return success;
    } catch (e) {
      _setError('Failed to delete model: $e');
      debugPrint('[OllamaService] Error deleting model: $e');
      return false;
    } finally {
      _setLoading(false);
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

  /// Create provider from discovered provider info
  static OllamaService fromProviderInfo(ProviderInfo providerInfo,
      {AuthService? authService}) {
    if (providerInfo.type != ProviderType.ollama) {
      throw ArgumentError('Provider info must be of type ollama');
    }

    return OllamaService(
      baseUrl: providerInfo.baseUrl,
      authService: authService,
    );
  }

  /// Get provider capabilities
  Map<String, bool> get capabilities => {
        'chat': true,
        'completion': true,
        'streaming': true,
        'embeddings': true,
        'model_management': true,
      };

  /// Get provider status
  Map<String, dynamic> get status => {
        'connected': _isConnected,
        'loading': _isLoading,
        'error': _error,
        'models_count': _models.length,
        'version': _version,
        'base_url': _baseUrl,
        'is_web': _isWeb,
      };

  /// Send streaming chat message to Ollama
  Stream<String> chatStream({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async* {
    try {
      debugPrint('Starting streaming chat with Ollama...');

      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final url = _isWeb ? '$_baseUrl/api/chat' : '$_baseUrl/api/chat';

      final headers = await _buildRequestHeaders();
      if (_isWeb && headers == null) {
        debugPrint('[DEBUG] Skipping streaming chat until user authenticates');
        return;
      }

      final response = await _dio.post(
        url,
        data: {
          'model': model,
          'messages': messages,
          'stream': true,
        },
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode == 200) {
        await for (final chunk
            in response.data.stream.transform(utf8.decoder)) {
          try {
            final data = json.decode(chunk);
            final content = data['message']?['content'] as String?;

            if (content != null && content.isNotEmpty) {
              yield content;
            }

            // Check if done
            if (data['done'] == true) {
              debugPrint('Streaming chat completed');
              return;
            }
          } catch (parseError) {
            // Skip malformed JSON chunks
            continue;
          }
        }
      } else {
        throw LLMCommunicationError.fromException(
          Exception('Streaming failed: HTTP ${response.statusCode}'),
          type: LLMCommunicationErrorType.providerUnavailable,
          httpStatusCode: response.statusCode,
        );
      }
    } catch (error) {
      debugPrint('Streaming chat error: $error');
      throw LLMCommunicationError.fromException(
        error is Exception ? error : Exception(error.toString()),
        type: LLMCommunicationErrorType.providerUnavailable,
      );
    }
  }

  /// Simple text completion (convenience method)
  Future<String?> complete({
    required String prompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    // Use first available model if none specified
    final modelToUse =
        model ?? (_models.isNotEmpty ? _models.first.name : null);

    if (modelToUse == null) {
      _setError('No model available for completion');
      return null;
    }

    return chat(model: modelToUse, message: prompt);
  }

  /// Streaming text completion (convenience method)
  Stream<String> completeStream({
    required String prompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async* {
    final modelToUse =
        model ?? (_models.isNotEmpty ? _models.first.name : null);

    if (modelToUse == null) {
      throw LLMCommunicationError.modelNotFound();
    }

    yield* chatStream(model: modelToUse, message: prompt);
  }
}

/// Model representing an Ollama model
class OllamaModel {
  final String name;
  final String? tag;
  final int? size;
  final DateTime? modifiedAt;

  const OllamaModel({required this.name, this.tag, this.size, this.modifiedAt});

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String,
      tag: json['tag'] as String?,
      size: json['size'] as int?,
      modifiedAt: json['modified_at'] != null
          ? DateTime.tryParse(json['modified_at'] as String)
          : null,
    );
  }

  String get displayName => tag != null ? '$name:$tag' : name;

  String get sizeFormatted {
    if (size == null) return 'Unknown size';
    final sizeInGB = size! / (1024 * 1024 * 1024);
    return '${sizeInGB.toStringAsFixed(1)} GB';
  }
}
