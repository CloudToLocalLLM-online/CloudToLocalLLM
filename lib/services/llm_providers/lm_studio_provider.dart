import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../models/llm_model.dart';
import '../auth_service.dart';
import '../settings_service.dart';
import 'llm_provider.dart';
import '../../utils/color_extensions.dart';

/// LM Studio LLM provider implementation
///
/// Provides integration with LM Studio instances through OpenAI-compatible API
/// endpoints, supporting model management, streaming, and chat completions.
class LMStudioProvider extends LLMProvider {
  

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

  // Active request tracking
  int _activeRequestCount = 0;
  final Set<String> _activeRequestIds = <String>{};

  LMStudioProvider({
    required super.config,
    required super.authService,
  }) : _config = super.config;

  @override
  String get providerId => 'lmstudio';

  @override
  String get providerName => 'LM Studio';

  @override
  String get providerDescription =>
      'Local LM Studio instance with OpenAI-compatible API';

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
  int get activeRequestCount => _activeRequestCount;

  @override
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('[lm_studio_provider] Initializing LM Studio provider');

      // Test connection
      await testConnection();

      // Load available models
      await refreshModels();

      debugPrint('[lm_studio_provider] LM Studio provider initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize LM Studio provider: $e';
      debugPrint('[lm_studio_provider] LMSTUDIO_INIT_FAILED: e');
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

      debugPrint('[lm_studio_provider] Connecting to LM Studio');

      final success = await testConnection();
      if (success) {
        _isAvailable = true;
        debugPrint('[lm_studio_provider] Connected to LM Studio successfully');
      } else {
        throw Exception('Connection test failed');
      }
    } catch (e) {
      _lastError = 'Failed to connect to LM Studio: $e';
      debugPrint('[lm_studio_provider] LMSTUDIO_CONNECT_FAILED: e');
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
    debugPrint('[lm_studio_provider] Disconnected from LM Studio');
  }

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('${_config.baseUrl}/v1/models'),
            headers: _getHeaders(),
          )
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

      final response = await _httpClient
          .get(
            Uri.parse('${_config.baseUrl}/v1/models'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 30));

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

        debugPrint('[lm_studio_provider] Loaded ${_availableModels.length} models from LM Studio');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _lastError = 'Failed to refresh models: $e';
      debugPrint('[LMStudio] Refresh models failed: $_lastError - $e');
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

    debugPrint('[lm_studio_provider] Selected model: $modelId');
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

    final requestId = _startRequest();
    try {
      _setLoading(true);

      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final response = await _httpClient
          .post(
            Uri.parse('${_config.baseUrl}/v1/chat/completions'),
            headers: _getHeaders(),
            body: json.encode({
              'model': model,
              'messages': messages,
              'stream': false,
              'temperature': 0.7,
              ...?options,
            }),
          )
          .timeout(const Duration(seconds: 120));

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
      debugPrint('[LMStudio] Send message failed: $_lastError - $e');
      rethrow;
    } finally {
      _setLoading(false);
      _endRequest(requestId);
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

    final requestId = _startRequest();
    try {
      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final request = http.Request(
        'POST',
        Uri.parse('${_config.baseUrl}/v1/chat/completions'),
      );
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
        await for (final chunk in streamedResponse.stream.transform(
          utf8.decoder,
        )) {
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
      debugPrint('[LMStudio] Streaming failed: $_lastError - $e');
      rethrow;
    } finally {
      _endRequest(requestId);
    }
  }

  @override
  Future<void> pullModel(String modelId, {Function(double)? onProgress}) async {
    throw UnimplementedError(
      'LM Studio does not support model pulling through API',
    );
  }

  @override
  Future<void> deleteModel(String modelId) async {
    throw UnimplementedError(
      'LM Studio does not support model deletion through API',
    );
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
    return LMStudioSettingsWidget(provider: this);
  }

  // Helper methods
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

  /// Start tracking an active request
  String _startRequest() {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeRequestIds.add(requestId);
    _activeRequestCount = _activeRequestIds.length;
    return requestId;
  }

  /// Stop tracking an active request
  void _endRequest(String requestId) {
    _activeRequestIds.remove(requestId);
    _activeRequestCount = _activeRequestIds.length;
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}

/// LM Studio Settings Widget
///
/// Provides configuration UI for LM Studio provider settings
class LMStudioSettingsWidget extends StatefulWidget {
  final LMStudioProvider provider;

  const LMStudioSettingsWidget({super.key, required this.provider});

  @override
  State<LMStudioSettingsWidget> createState() => _LMStudioSettingsWidgetState();
}

class _LMStudioSettingsWidgetState extends State<LMStudioSettingsWidget> {
  late TextEditingController _baseUrlController;
  late TextEditingController _timeoutController;
  bool _isTestingConnection = false;
  String? _connectionTestResult;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.provider._config.baseUrl,
    );
    _timeoutController = TextEditingController(
      text: widget.provider._config.timeout.inSeconds.toString(),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LM Studio Configuration',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Base URL field
        TextFormField(
          controller: _baseUrlController,
          decoration: const InputDecoration(
            labelText: 'LM Studio API URL',
            hintText: 'http://localhost:1234',
            border: OutlineInputBorder(),
            helperText:
                'URL where LM Studio is running (usually localhost:1234)',
          ),
          onChanged: _onConfigurationChanged,
        ),

        const SizedBox(height: 16),

        // Timeout field
        TextFormField(
          controller: _timeoutController,
          decoration: const InputDecoration(
            labelText: 'Request Timeout (seconds)',
            hintText: '30',
            border: OutlineInputBorder(),
            helperText: 'Maximum time to wait for responses',
          ),
          keyboardType: TextInputType.number,
          onChanged: _onConfigurationChanged,
        ),

        const SizedBox(height: 16),

        // Connection test button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isTestingConnection ? null : _testConnection,
            icon: _isTestingConnection
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: Text(
              _isTestingConnection ? 'Testing...' : 'Test Connection',
            ),
          ),
        ),

        // Connection test result
        if (_connectionTestResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _connectionTestResult!.startsWith('Success')
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              border: Border.all(
                color: _connectionTestResult!.startsWith('Success')
                    ? Colors.green
                    : Colors.red,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _connectionTestResult!.startsWith('Success')
                      ? Icons.check_circle
                      : Icons.error,
                  color: _connectionTestResult!.startsWith('Success')
                      ? Colors.green
                      : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectionTestResult!,
                    style: TextStyle(
                      color: _connectionTestResult!.startsWith('Success')
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Help text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'LM Studio Setup',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Download and install LM Studio from lmstudio.ai\n'
                '2. Load a model in LM Studio\n'
                '3. Start the local server (usually on port 1234)\n'
                '4. Use the default URL: http://localhost:1234',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onConfigurationChanged(String value) {
    // Update configuration when fields change
    final newConfig = LLMProviderConfig(
      providerId: widget.provider.providerId,
      baseUrl: _baseUrlController.text.trim(),
      timeout: Duration(seconds: int.tryParse(_timeoutController.text) ?? 30),
    );

    widget.provider.updateConfiguration(newConfig.toJson());
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
    });

    try {
      // Update configuration before testing
      _onConfigurationChanged('');

      // Test the connection
      await widget.provider.initialize();

      if (widget.provider.isAvailable) {
        setState(() {
          _connectionTestResult = 'Success: Connected to LM Studio';
        });
      } else {
        setState(() {
          _connectionTestResult =
              'Failed: ${widget.provider.lastError ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        _connectionTestResult = 'Failed: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }
}

