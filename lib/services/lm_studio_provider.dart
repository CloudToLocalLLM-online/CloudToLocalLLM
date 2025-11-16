/// LM Studio Provider
///
/// Provides LM Studio integration through OpenAI-compatible API interface.
/// LM Studio exposes a local OpenAI-compatible API that can be used with
/// standard OpenAI client libraries and patterns.
///
/// Key Features:
/// - OpenAI-compatible API integration
/// - Chat completion with streaming support
/// - Model management and selection
/// - Automatic model detection
/// - Error handling with retry logic
///
/// Usage:
/// ```dart
/// final provider = LMStudioProvider(baseUrl: 'http://localhost:1234');
/// await provider.initialize();
/// final response = await provider.complete(prompt: 'Hello, world!');
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert' as convert;

import 'provider_discovery_service.dart';
import '../models/llm_communication_error.dart';

/// LM Studio model information
class LMStudioModel {
  final String id;
  final String object;
  final int created;
  final String ownedBy;
  final Map<String, dynamic>? metadata;

  const LMStudioModel({
    required this.id,
    required this.object,
    required this.created,
    required this.ownedBy,
    this.metadata,
  });

  factory LMStudioModel.fromJson(Map<String, dynamic> json) {
    return LMStudioModel(
      id: json['id'] as String,
      object: json['object'] as String? ?? 'model',
      created: json['created'] as int? ?? 0,
      ownedBy: json['owned_by'] as String? ?? 'lm-studio',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created': created,
      'owned_by': ownedBy,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() => 'LMStudioModel(id: $id, ownedBy: $ownedBy)';
}

/// LM Studio chat message
class LMStudioMessage {
  final String role;
  final String content;
  final Map<String, dynamic>? metadata;

  const LMStudioMessage({
    required this.role,
    required this.content,
    this.metadata,
  });

  factory LMStudioMessage.fromJson(Map<String, dynamic> json) {
    return LMStudioMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      if (metadata != null) ...metadata!,
    };
  }
}

/// LM Studio Provider Service
class LMStudioProvider extends ChangeNotifier {
  final String baseUrl;
  final Duration timeout;
  late Dio _dio;

  bool _isConnected = false;
  List<LMStudioModel> _models = [];
  bool _isLoading = false;
  String? _error;
  String? _currentModel;

  static const Duration _defaultTimeout = Duration(seconds: 30);

  LMStudioProvider({
    required this.baseUrl,
    Duration? timeout,
    Dio? dio,
  }) : timeout = timeout ?? _defaultTimeout {
    _dio = dio ?? Dio();
    _setupDio();
    debugPrint('LMStudioProvider initialized with baseUrl: $baseUrl');
  }

  void _setupDio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = timeout;
    _dio.options.receiveTimeout = timeout;
  }

  /// Getters
  bool get isConnected => _isConnected;
  List<LMStudioModel> get models => List.unmodifiable(_models);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentModel => _currentModel;

  /// Initialize the provider
  Future<void> initialize() async {
    debugPrint('Initializing LM Studio provider...');

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
      }

      debugPrint('LM Studio provider initialization completed');
    } catch (error) {
      _setError('Initialization failed: $error');
      debugPrint('LM Studio provider initialization failed: $error');
    } finally {
      _setLoading(false);
    }
  }

  /// Test connection to LM Studio
  Future<bool> testConnection() async {
    try {
      debugPrint('Testing LM Studio connection...');

      final response = await _dio.get('/v1/models',
          options: Options(headers: _getHeaders()));

      if (response.statusCode == 200) {
        _isConnected = true;
        debugPrint('LM Studio connection successful');
        return true;
      } else {
        _setError('Connection failed: HTTP ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } catch (error) {
      _setError('Connection failed: $error');
      _isConnected = false;
      debugPrint('LM Studio connection failed: $error');
      return false;
    }
  }

  /// Get available models
  Future<List<LMStudioModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('Getting LM Studio models...');

      final response = await _dio.get('/v1/models',
          options: Options(headers: _getHeaders()));

      if (response.statusCode == 200) {
        final data = response.data;
        final modelsList = data['data'] as List<dynamic>? ?? [];

        _models = modelsList
            .map((model) =>
                LMStudioModel.fromJson(model as Map<String, dynamic>))
            .toList();

        debugPrint('Found ${_models.length} LM Studio models');
        return _models;
      } else {
        _setError('Failed to get models: HTTP ${response.statusCode}');
        debugPrint(
            'Get models failed: ${response.statusCode} - ${response.data}');
        return [];
      }
    } catch (error) {
      _setError('Failed to get models: $error');
      debugPrint('Error getting LM Studio models: $error');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Send chat completion request
  Future<String?> chatCompletion({
    required String model,
    required List<LMStudioMessage> messages,
    double? temperature,
    int? maxTokens,
    bool stream = false,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('Sending chat completion to LM Studio...');

      final requestBody = {
        'model': model,
        'messages': messages.map((msg) => msg.toJson()).toList(),
        'stream': stream,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
      };

      final response = await _dio.post(
        '/v1/chat/completions',
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
      debugPrint('LM Studio chat completion error: $error');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Send streaming chat completion request
  Stream<String> chatCompletionStream({
    required String model,
    required List<LMStudioMessage> messages,
    double? temperature,
    int? maxTokens,
  }) async* {
    try {
      debugPrint('Starting streaming chat completion...');

      final requestBody = {
        'model': model,
        'messages': messages.map((msg) => msg.toJson()).toList(),
        'stream': true,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
      };

      final response = await _dio.post(
        '/v1/chat/completions',
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
  }) async {
    final modelToUse = model ??
        _currentModel ??
        (_models.isNotEmpty ? _models.first.id : null);

    if (modelToUse == null) {
      _setError('No model available for completion');
      return null;
    }

    final messages = [
      LMStudioMessage(role: 'user', content: prompt),
    ];

    return chatCompletion(
      model: modelToUse,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// Send streaming text completion (convenience method)
  Stream<String> completeStream({
    required String prompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async* {
    final modelToUse = model ??
        _currentModel ??
        (_models.isNotEmpty ? _models.first.id : null);

    if (modelToUse == null) {
      throw LLMCommunicationError.modelNotFound();
    }

    final messages = [
      LMStudioMessage(role: 'user', content: prompt),
    ];

    yield* chatCompletionStream(
      model: modelToUse,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
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

  /// Get HTTP headers for requests
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
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
  static LMStudioProvider fromProviderInfo(ProviderInfo providerInfo) {
    if (providerInfo.type != ProviderType.lmStudio) {
      throw ArgumentError('Provider info must be of type lmStudio');
    }

    return LMStudioProvider(
      baseUrl: providerInfo.baseUrl,
      timeout: const Duration(seconds: 30),
    );
  }

  /// Get provider capabilities
  Map<String, bool> get capabilities => {
        'chat': true,
        'completion': true,
        'streaming': true,
        'openai_compatible': true,
        'model_management':
            false, // LM Studio doesn't support model pulling/deletion via API
      };

  /// Get provider status
  Map<String, dynamic> get status => {
        'connected': _isConnected,
        'loading': _isLoading,
        'error': _error,
        'models_count': _models.length,
        'current_model': _currentModel,
        'base_url': baseUrl,
      };

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
