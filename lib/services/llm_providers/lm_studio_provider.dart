import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'base_llm_provider.dart';
import '../../utils/tunnel_logger.dart';

/// LM Studio LLM provider implementation
/// 
/// Provides integration with LM Studio instances through OpenAI-compatible API
/// endpoints, supporting model management, streaming, and chat completions.
class LMStudioProvider extends BaseLLMProvider {
  final TunnelLogger _logger = TunnelLogger('LMStudioProvider');
  
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
  
  LMStudioProvider({
    LLMProviderConfig? config,
  }) : _config = config ?? LLMProviderConfig(
         providerId: 'lmstudio',
         baseUrl: 'http://localhost:1234',
       );
  
  @override
  String get providerId => 'lmstudio';
  
  @override
  String get providerName => 'LM Studio';
  
  @override
  String get providerDescription => 'Local LM Studio instance with OpenAI-compatible API';
  
  @override
  String get providerIcon => 'lmstudio';
  
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
      
      _logger.info('Initializing LM Studio provider');
      
      // Test connection
      await testConnection();
      
      // Load available models
      await refreshModels();
      
      _logger.info('LM Studio provider initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize LM Studio provider: $e';
      _logger.logTunnelError('LMSTUDIO_INIT_FAILED', _lastError!, error: e);
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
      
      _logger.info('Connecting to LM Studio');
      
      final success = await testConnection();
      if (success) {
        _isAvailable = true;
        _logger.info('Connected to LM Studio successfully');
      } else {
        throw Exception('Connection test failed');
      }
    } catch (e) {
      _lastError = 'Failed to connect to LM Studio: $e';
      _logger.logTunnelError('LMSTUDIO_CONNECT_FAILED', _lastError!, error: e);
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
    _logger.info('Disconnected from LM Studio');
  }
  
  @override
  Future<bool> testConnection() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${_config.baseUrl}/v1/models'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
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
      
      final response = await _httpClient.get(
        Uri.parse('${_config.baseUrl}/v1/models'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final models = data['data'] as List<dynamic>? ?? [];
        
        _availableModels = models.map((model) {
          final modelData = model as Map<String, dynamic>;
          return LLMModel(
            id: modelData['id'] as String,
            name: modelData['id'] as String,
            description: 'LM Studio model',
            metadata: modelData,
          );
        }).toList();
        
        _logger.info('Loaded ${_availableModels.length} models from LM Studio');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _lastError = 'Failed to refresh models: $e';
      _logger.logTunnelError('LMSTUDIO_REFRESH_MODELS_FAILED', _lastError!, error: e);
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
      throw Exception('LM Studio provider is not available');
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
      
      final response = await _httpClient.post(
        Uri.parse('${_config.baseUrl}/v1/chat/completions'),
        headers: _getHeaders(),
        body: json.encode({
          'model': model,
          'messages': messages,
          'stream': false,
          'temperature': 0.7,
          ...?options,
        }),
      ).timeout(const Duration(seconds: 120));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>? ?? [];
        if (choices.isNotEmpty) {
          final choice = choices.first as Map<String, dynamic>;
          final message = choice['message'] as Map<String, dynamic>?;
          return message?['content'] as String? ?? '';
        }
        return '';
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _lastError = 'Failed to send message: $e';
      _logger.logTunnelError('LMSTUDIO_SEND_MESSAGE_FAILED', _lastError!, error: e);
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
      throw Exception('LM Studio provider is not available');
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
      
      final request = http.Request('POST', Uri.parse('${_config.baseUrl}/v1/chat/completions'));
      request.headers.addAll(_getHeaders());
      request.body = json.encode({
        'model': model,
        'messages': messages,
        'stream': true,
        'temperature': 0.7,
        ...?options,
      });
      
      final streamedResponse = await _httpClient.send(request);
      
      if (streamedResponse.statusCode == 200) {
        await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.trim().startsWith('data: ')) {
              final jsonStr = line.trim().substring(6);
              if (jsonStr == '[DONE]') break;
              
              try {
                final data = json.decode(jsonStr) as Map<String, dynamic>;
                final choices = data['choices'] as List<dynamic>? ?? [];
                if (choices.isNotEmpty) {
                  final choice = choices.first as Map<String, dynamic>;
                  final delta = choice['delta'] as Map<String, dynamic>?;
                  final content = delta?['content'] as String?;
                  if (content != null && content.isNotEmpty) {
                    yield content;
                  }
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
      _logger.logTunnelError('LMSTUDIO_STREAMING_FAILED', _lastError!, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> pullModel(String modelId, {Function(double)? onProgress}) async {
    throw UnimplementedError('LM Studio does not support model pulling through API');
  }
  
  @override
  Future<void> deleteModel(String modelId) async {
    throw UnimplementedError('LM Studio does not support model deletion through API');
  }
  
  @override
  Future<LLMModelInfo?> getModelInfo(String modelId) async {
    throw UnimplementedError('LM Studio model info not yet implemented');
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
    return null; // TODO: Implement LM Studio settings widget
  }
  
  // Helper methods
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
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
