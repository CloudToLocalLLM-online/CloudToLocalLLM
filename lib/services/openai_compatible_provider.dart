/// OpenAI Compatible Provider
///
/// Generic provider for OpenAI-compatible APIs. This can work with various
/// local and remote APIs that implement the OpenAI API specification.
///
/// Key Features:
/// - Generic OpenAI API compatibility
/// - Configurable authentication and headers
/// - Chat completion with streaming support
/// - Server information detection
/// - Flexible configuration options
///
/// Usage:
/// ```dart
/// final config = OpenAICompatibleConfig(
///   baseUrl: 'http://localhost:8080',
///   apiKey: 'your-api-key',
/// );
/// final provider = OpenAICompatibleProvider(config: config);
/// await provider.initialize();
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert' as convert;

import 'provider_discovery_service.dart';
import '../models/llm_communication_error.dart';

/// OpenAI-compatible model information
class OpenAICompatibleModel {
  final String id;
  final String object;
  final int created;
  final String ownedBy;
  final List<String>? permissions;
  final Map<String, dynamic>? metadata;

  const OpenAICompatibleModel({
    required this.id,
    required this.object,
    required this.created,
    required this.ownedBy,
    this.permissions,
    this.metadata,
  });

  factory OpenAICompatibleModel.fromJson(Map<String, dynamic> json) {
    return OpenAICompatibleModel(
      id: json['id'] as String,
      object: json['object'] as String? ?? 'model',
      created: json['created'] as int? ?? 0,
      ownedBy: json['owned_by'] as String? ?? 'unknown',
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created': created,
      'owned_by': ownedBy,
      if (permissions != null) 'permissions': permissions,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() => 'OpenAICompatibleModel(id: $id, ownedBy: $ownedBy)';
}

/// OpenAI-compatible chat message
class OpenAICompatibleMessage {
  final String role;
  final String content;
  final String? name;
  final Map<String, dynamic>? functionCall;
  final Map<String, dynamic>? metadata;

  const OpenAICompatibleMessage({
    required this.role,
    required this.content,
    this.name,
    this.functionCall,
    this.metadata,
  });

  factory OpenAICompatibleMessage.fromJson(Map<String, dynamic> json) {
    return OpenAICompatibleMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      name: json['name'] as String?,
      functionCall: json['function_call'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      if (name != null) 'name': name,
      if (functionCall != null) 'function_call': functionCall,
      if (metadata != null) ...metadata!,
    };
  }
}

/// OpenAI Compatible Provider Configuration
class OpenAICompatibleConfig {
  final String baseUrl;
  final String? apiKey;
  final Map<String, String>? headers;
  final Duration timeout;
  final Duration streamingTimeout;
  final bool requiresAuth;
  final String apiVersion;

  const OpenAICompatibleConfig({
    required this.baseUrl,
    this.apiKey,
    this.headers,
    this.timeout = const Duration(seconds: 30),
    this.streamingTimeout = const Duration(minutes: 5),
    this.requiresAuth = false,
    this.apiVersion = 'v1',
  });

  /// Create config from provider info
  factory OpenAICompatibleConfig.fromProviderInfo(ProviderInfo providerInfo) {
    return OpenAICompatibleConfig(
      baseUrl: providerInfo.baseUrl,
      requiresAuth: providerInfo.metadata?['requires_auth'] == true,
      apiKey: providerInfo.metadata?['api_key'] as String?,
      headers: providerInfo.metadata?['headers'] as Map<String, String>?,
    );
  }
}

/// OpenAI Compatible Provider Service
class OpenAICompatibleProvider extends ChangeNotifier {
  final OpenAICompatibleConfig config;
  late Dio _dio;

  bool _isConnected = false;
  List<OpenAICompatibleModel> _models = [];
  bool _isLoading = false;
  String? _error;
  String? _currentModel;
  Map<String, dynamic>? _serverInfo;

  OpenAICompatibleProvider({
    required this.config,
    Dio? dio,
  }) {
    _dio = dio ?? Dio();
    _setupDio();
    debugPrint(
        'OpenAICompatibleProvider initialized with baseUrl: ${config.baseUrl}');
  }

  void _setupDio() {
    _dio.options.baseUrl = config.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Getters
  bool get isConnected => _isConnected;
  List<OpenAICompatibleModel> get models => List.unmodifiable(_models);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentModel => _currentModel;
  Map<String, dynamic>? get serverInfo => _serverInfo;

  /// Initialize the provider
  Future<void> initialize() async {
    debugPrint('Initializing OpenAI-compatible provider...');

    try {
      _setLoading(true);
      _clearError();

      // Test connection and load models
      final connectionSuccess = await testConnection();
      if (connectionSuccess) {
        await getModels();

        // Set current model to first available if none set
        if (_currentModel == null && _models.isNotEmpty) {
          _currentModel = _models.first.id;
          debugPrint('Set current model to: $_currentModel');
        }

        // Try to get server info if available
        await _getServerInfo();
      }

      debugPrint('OpenAI-compatible provider initialization completed');
    } catch (error) {
      _setError('Initialization failed: $error');
      debugPrint('OpenAI-compatible provider initialization failed: $error');
    } finally {
      _setLoading(false);
    }
  }

  /// Test connection to the API
  Future<bool> testConnection() async {
    try {
      debugPrint('Testing OpenAI-compatible API connection...');

      final response = await _dio.get(
        '/${config.apiVersion}/models',
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200) {
        _isConnected = true;
        debugPrint('OpenAI-compatible API connection successful');
        return true;
      } else if (response.statusCode == 401) {
        _setError('Authentication failed - check API key');
        _isConnected = false;
        return false;
      } else {
        _setError('Connection failed: HTTP ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } catch (error) {
      _setError('Connection failed: $error');
      _isConnected = false;
      debugPrint('OpenAI-compatible API connection failed: $error');
      return false;
    }
  }

  /// Get available models
  Future<List<OpenAICompatibleModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('Getting OpenAI-compatible API models...');

      final response = await _dio.get(
        '/${config.apiVersion}/models',
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final modelsList = data['data'] as List<dynamic>? ?? [];

        _models = modelsList
            .map((model) =>
                OpenAICompatibleModel.fromJson(model as Map<String, dynamic>))
            .toList();

        debugPrint('Found ${_models.length} OpenAI-compatible models');
        return _models;
      } else {
        _setError('Failed to get models: HTTP ${response.statusCode}');
        debugPrint(
            'Get models failed: ${response.statusCode} - ${response.data}');
        return [];
      }
    } catch (error) {
      _setError('Failed to get models: $error');
      debugPrint('Error getting OpenAI-compatible models: $error');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Send chat completion request
  Future<String?> chatCompletion({
    required String model,
    required List<OpenAICompatibleMessage> messages,
    double? temperature,
    int? maxTokens,
    double? topP,
    int? n,
    List<String>? stop,
    bool stream = false,
    Map<String, dynamic>? additionalParams,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('Sending chat completion to OpenAI-compatible API...');

      final requestBody = {
        'model': model,
        'messages': messages.map((msg) => msg.toJson()).toList(),
        'stream': stream,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (topP != null) 'top_p': topP,
        if (n != null) 'n': n,
        if (stop != null) 'stop': stop,
        if (additionalParams != null) ...additionalParams,
      };

      final response = await _dio.post(
        '/${config.apiVersion}/chat/completions',
        data: requestBody,
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final choices = data['choices'] as List<dynamic>? ?? [];

        if (choices.isNotEmpty) {
          final message = choices.first['message'];
          final content = message['content'] as String?;

          debugPrint('Chat completion successful');
          return content;
        } else {
          _setError('No response choices received');
          return null;
        }
      } else {
        _setError('Chat completion failed: HTTP ${response.statusCode}');
        debugPrint(
            'Chat completion failed: ${response.statusCode} - ${response.data}');
        return null;
      }
    } catch (error) {
      _setError('Chat completion failed: $error');
      debugPrint('OpenAI-compatible chat completion error: $error');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Send streaming chat completion request
  Stream<String> chatCompletionStream({
    required String model,
    required List<OpenAICompatibleMessage> messages,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stop,
    Map<String, dynamic>? additionalParams,
  }) async* {
    try {
      debugPrint('Starting streaming chat completion...');

      final requestBody = {
        'model': model,
        'messages': messages.map((msg) => msg.toJson()).toList(),
        'stream': true,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (topP != null) 'top_p': topP,
        if (stop != null) 'stop': stop,
        if (additionalParams != null) ...additionalParams,
      };

      final response = await _dio.post(
        '/${config.apiVersion}/chat/completions',
        data: requestBody,
        options: Options(
          headers: _getHeaders(),
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode == 200) {
        await for (final chunk
            in response.data.stream.transform(convert.utf8.decoder)) {
          // Parse Server-Sent Events format
          final lines = chunk.split('\n');

          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();

              if (data == '[DONE]') {
                debugPrint('Streaming completion finished');
                return;
              }

              try {
                final json = jsonDecode(data);
                final choices = json['choices'] as List<dynamic>? ?? [];

                if (choices.isNotEmpty) {
                  final delta = choices.first['delta'];
                  final content = delta['content'] as String?;

                  if (content != null && content.isNotEmpty) {
                    yield content;
                  }
                }
              } catch (parseError) {
                // Skip malformed JSON chunks
                continue;
              }
            }
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
      debugPrint('Streaming chat completion error: $error');
      throw LLMCommunicationError.fromException(
        error is Exception ? error : Exception(error.toString()),
        type: LLMCommunicationErrorType.providerUnavailable,
      );
    }
  }

  /// Send simple text completion (convenience method)
  Future<String?> complete({
    required String prompt,
    String? model,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? additionalParams,
  }) async {
    final modelToUse = model ??
        _currentModel ??
        (_models.isNotEmpty ? _models.first.id : null);

    if (modelToUse == null) {
      _setError('No model available for completion');
      return null;
    }

    final messages = [
      OpenAICompatibleMessage(role: 'user', content: prompt),
    ];

    return chatCompletion(
      model: modelToUse,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      additionalParams: additionalParams,
    );
  }

  /// Send streaming text completion (convenience method)
  Stream<String> completeStream({
    required String prompt,
    String? model,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? additionalParams,
  }) async* {
    final modelToUse = model ??
        _currentModel ??
        (_models.isNotEmpty ? _models.first.id : null);

    if (modelToUse == null) {
      throw LLMCommunicationError.modelNotFound();
    }

    final messages = [
      OpenAICompatibleMessage(role: 'user', content: prompt),
    ];

    yield* chatCompletionStream(
      model: modelToUse,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      additionalParams: additionalParams,
    );
  }

  /// Set current model
  void setCurrentModel(String modelId) {
    if (_models.any((model) => model.id == modelId)) {
      _currentModel = modelId;
      debugPrint('Current model set to: $modelId');
      notifyListeners();
    } else {
      debugPrint('Model not found: $modelId');
    }
  }

  /// Get server information (if available)
  Future<void> _getServerInfo() async {
    try {
      // Try common endpoints for server info
      final endpoints = [
        '${config.baseUrl}/health',
        '${config.baseUrl}/info',
        '${config.baseUrl}/${config.apiVersion}/info',
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await _dio.get(
            endpoint,
            options: Options(headers: _getHeaders()),
          );

          if (response.statusCode == 200) {
            _serverInfo = response.data;
            debugPrint('Retrieved server info from: $endpoint');
            break;
          }
        } catch (e) {
          // Continue to next endpoint
          continue;
        }
      }
    } catch (error) {
      debugPrint('Could not retrieve server info: $error');
    }
  }

  /// Get HTTP headers for requests
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add API key if required
    if (config.requiresAuth && config.apiKey != null) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    // Add custom headers
    if (config.headers != null) {
      headers.addAll(config.headers!);
    }

    return headers;
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Create provider from discovered provider info
  static OpenAICompatibleProvider fromProviderInfo(ProviderInfo providerInfo) {
    if (providerInfo.type != ProviderType.openAICompatible) {
      throw ArgumentError('Provider info must be of type openAICompatible');
    }

    final config = OpenAICompatibleConfig.fromProviderInfo(providerInfo);
    return OpenAICompatibleProvider(config: config);
  }

  /// Get provider capabilities
  Map<String, bool> get capabilities => {
        'chat': true,
        'completion': true,
        'streaming': true,
        'openai_compatible': true,
        'embeddings': _serverInfo?['supports_embeddings'] == true,
        'function_calling': _serverInfo?['supports_functions'] == true,
        'model_management':
            false, // Most OpenAI-compatible APIs don't support model management
      };

  /// Get provider status
  Map<String, dynamic> get status => {
        'connected': _isConnected,
        'loading': _isLoading,
        'error': _error,
        'models_count': _models.length,
        'current_model': _currentModel,
        'base_url': config.baseUrl,
        'requires_auth': config.requiresAuth,
        'server_info': _serverInfo,
      };

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
