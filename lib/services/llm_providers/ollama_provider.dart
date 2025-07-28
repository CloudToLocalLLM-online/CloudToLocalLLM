import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'base_llm_provider.dart';
import '../connection_manager_service.dart';
import '../../utils/tunnel_logger.dart';

/// Ollama LLM provider implementation
///
/// Provides integration with Ollama instances through the tunnel system
/// or direct local connections, supporting model management, streaming,
/// and all standard Ollama API features.
class OllamaProvider extends BaseLLMProvider {
  final ConnectionManagerService _connectionManager;
  final TunnelLogger _logger = TunnelLogger('OllamaProvider');

  // State
  bool _isAvailable = false;
  bool _isConnecting = false;
  bool _isLoading = false;
  String? _lastError;
  List<LLMModel> _availableModels = [];
  LLMModel? _selectedModel;
  LLMProviderConfig _config;

  // HTTP client
  final http.Client _httpClient = http.Client();

  OllamaProvider({
    required ConnectionManagerService connectionManager,
    LLMProviderConfig? config,
  }) : _connectionManager = connectionManager,
       _config =
           config ??
           LLMProviderConfig(
             providerId: 'ollama',
             baseUrl: 'http://localhost:11434',
           );

  @override
  String get providerId => 'ollama';

  @override
  String get providerName => 'Ollama';

  @override
  String get providerDescription =>
      'Local Ollama instance for running open-source LLMs';

  @override
  String get providerIcon => 'ollama';

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isConnecting => _isConnecting;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get lastError => _lastError;

  @override
  List<LLMModel> get availableModels => List.unmodifiable(_availableModels);

  @override
  LLMModel? get selectedModel => _selectedModel;

  @override
  Map<String, dynamic> get configuration => _config.toJson();

  @override
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _clearError();

      _logger.info('Initializing Ollama provider');

      // Wait for connection manager to be ready
      if (!_connectionManager.hasAnyConnection) {
        await _connectionManager.initialize();
      }

      // Test connection
      await testConnection();

      // Load available models
      await refreshModels();

      _logger.info('Ollama provider initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize Ollama provider: $e';
      _logger.logTunnelError('OLLAMA_INIT_FAILED', _lastError!, error: e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> connect() async {
    try {
      _setConnecting(true);
      _clearError();

      _logger.info('Connecting to Ollama');

      // Use connection manager to establish connection
      await _connectionManager.initialize();

      if (_connectionManager.hasAnyConnection) {
        _isAvailable = true;
        _logger.info('Connected to Ollama successfully');
      } else {
        throw Exception('No connection available');
      }
    } catch (e) {
      _lastError = 'Failed to connect to Ollama: $e';
      _logger.logTunnelError('OLLAMA_CONNECT_FAILED', _lastError!, error: e);
      _isAvailable = false;
      rethrow;
    } finally {
      _setConnecting(false);
    }
  }

  @override
  Future<void> disconnect() async {
    _isAvailable = false;
    _selectedModel = null;
    _availableModels.clear();
    _clearError();
    notifyListeners();
    _logger.info('Disconnected from Ollama');
  }

  @override
  Future<bool> testConnection() async {
    try {
      final baseUrl = _getBaseUrl();
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/api/version'), headers: _getHeaders())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _isAvailable = true;
        _clearError();
        notifyListeners();
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _lastError = 'Connection test failed: $e';
      _isAvailable = false;
      notifyListeners();
      return false;
    }
  }

  @override
  Future<void> refreshModels() async {
    try {
      _setLoading(true);

      final baseUrl = _getBaseUrl();
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/api/tags'), headers: _getHeaders())
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final models = data['models'] as List<dynamic>? ?? [];

        _availableModels = models.map((model) {
          final modelData = model as Map<String, dynamic>;
          return LLMModel(
            id: modelData['name'] as String,
            name: modelData['name'] as String,
            description: modelData['details']?['family'] as String?,
            size: modelData['size'] as int?,
            modifiedAt: modelData['modified_at'] != null
                ? DateTime.parse(modelData['modified_at'] as String)
                : null,
            metadata: modelData,
          );
        }).toList();

        _logger.info('Loaded ${_availableModels.length} models from Ollama');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _lastError = 'Failed to refresh models: $e';
      _logger.logTunnelError(
        'OLLAMA_REFRESH_MODELS_FAILED',
        _lastError!,
        error: e,
      );
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> selectModel(String modelId) async {
    final model = _availableModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => LLMModel(id: modelId, name: modelId),
    );

    _selectedModel = model;
    notifyListeners();

    _logger.info('Selected model: $modelId');
  }

  @override
  Future<String> sendMessage({
    required String message,
    String? modelId,
    List<Map<String, String>>? history,
    Map<String, dynamic>? options,
  }) async {
    if (!_isAvailable) {
      throw Exception('Ollama provider is not available');
    }

    final model = modelId ?? _selectedModel?.id;
    if (model == null) {
      throw Exception('No model selected');
    }

    try {
      _setLoading(true);

      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final baseUrl = _getBaseUrl();
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: _getHeaders(),
            body: json.encode({
              'model': model,
              'messages': messages,
              'stream': false,
              ...?options,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final responseMessage = data['message'] as Map<String, dynamic>?;
        return responseMessage?['content'] as String? ?? '';
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _lastError = 'Failed to send message: $e';
      _logger.logTunnelError(
        'OLLAMA_SEND_MESSAGE_FAILED',
        _lastError!,
        error: e,
      );
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  @override
  Stream<String> sendStreamingMessage({
    required String message,
    String? modelId,
    List<Map<String, String>>? history,
    Map<String, dynamic>? options,
  }) async* {
    if (!_isAvailable) {
      throw Exception('Ollama provider is not available');
    }

    final model = modelId ?? _selectedModel?.id;
    if (model == null) {
      throw Exception('No model selected');
    }

    try {
      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final baseUrl = _getBaseUrl();
      final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
      request.headers.addAll(_getHeaders());
      request.body = json.encode({
        'model': model,
        'messages': messages,
        'stream': true,
        ...?options,
      });

      final streamedResponse = await _httpClient.send(request);

      if (streamedResponse.statusCode == 200) {
        await for (final chunk in streamedResponse.stream.transform(
          utf8.decoder,
        )) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              try {
                final data = json.decode(line) as Map<String, dynamic>;
                final delta = data['message']?['content'] as String?;
                if (delta != null && delta.isNotEmpty) {
                  yield delta;
                }
              } catch (e) {
                // Skip malformed JSON lines
                continue;
              }
            }
          }
        }
      } else {
        throw Exception('HTTP ${streamedResponse.statusCode}');
      }
    } catch (e) {
      _lastError = 'Failed to send streaming message: $e';
      _logger.logTunnelError('OLLAMA_STREAMING_FAILED', _lastError!, error: e);
      rethrow;
    }
  }

  @override
  Future<void> pullModel(String modelId, {Function(double)? onProgress}) async {
    // Implementation for model pulling
    throw UnimplementedError('Model pulling not yet implemented');
  }

  @override
  Future<void> deleteModel(String modelId) async {
    // Implementation for model deletion
    throw UnimplementedError('Model deletion not yet implemented');
  }

  @override
  Future<LLMModelInfo?> getModelInfo(String modelId) async {
    // Implementation for getting model info
    throw UnimplementedError('Model info not yet implemented');
  }

  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    _config = LLMProviderConfig.fromJson(config);
    notifyListeners();
  }

  @override
  bool validateConfiguration(Map<String, dynamic> config) {
    try {
      LLMProviderConfig.fromJson(config);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget? getSettingsWidget() {
    // Return Ollama-specific settings widget
    return null; // TODO: Implement settings widget
  }

  // Helper methods
  String _getBaseUrl() {
    switch (_connectionManager.getBestConnectionType()) {
      case ConnectionType.local:
        return 'http://localhost:11434';
      case ConnectionType.cloud:
        return 'https://app.cloudtolocalllm.online/api/ollama';
      case ConnectionType.none:
        throw StateError('No connection available');
    }
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_config.headers != null) {
      headers.addAll(_config.headers!);
    }

    return headers;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setConnecting(bool connecting) {
    _isConnecting = connecting;
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}
