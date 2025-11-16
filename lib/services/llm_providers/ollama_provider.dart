import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert' as convert;

import '../../config/app_config.dart';
import '../../models/llm_model.dart';
import '../connection_manager_service.dart';
import 'llm_provider.dart';

/// Ollama LLM provider implementation
///
/// Provides integration with Ollama instances through the tunnel system
/// or direct local connections, supporting model management, streaming,
/// and all standard Ollama API features.
class OllamaProvider extends LLMProvider {
  OllamaProvider({
    required super.config,
    required super.authService,
    required ConnectionManagerService connectionManager,
  }) : _connectionManager = connectionManager;

  final ConnectionManagerService _connectionManager;
  // Removed TunnelLogger - use debugPrint for logging

  // State
  bool _isAvailable = false;
  bool _isConnecting = false;
  bool _isLoading = false;
  String? _lastError;
  List<LLMModel> _availableModels = [];
  LLMModel? _selectedModel;

  LLMProviderConfig get _config => providerConfig;
  set _config(LLMProviderConfig value) => providerConfig = value;

  // HTTP client
  final Dio _dio = Dio();

  // Active request tracking
  int _activeRequestCount = 0;
  final Set<String> _activeRequestIds = <String>{};

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
  int get activeRequestCount => _activeRequestCount;

  @override
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('[OllamaProvider] Initializing Ollama provider');

      // Wait for connection manager to be ready
      if (!_connectionManager.hasAnyConnection) {
        await _connectionManager.initialize();
      }

      // Test connection
      await testConnection();

      // Load available models
      await refreshModels();

      debugPrint('[OllamaProvider] Ollama provider initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize Ollama provider: $e';
      debugPrint('[OllamaProvider] Initialization failed: $e');
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

      debugPrint('[OllamaProvider] Connecting to Ollama');

      // Use connection manager to establish connection
      await _connectionManager.initialize();

      if (_connectionManager.hasAnyConnection) {
        _isAvailable = true;
        debugPrint('[OllamaProvider] Connected to Ollama successfully');
      } else {
        throw Exception('No connection available');
      }
    } catch (e) {
      _lastError = 'Failed to connect to Ollama: $e';
      debugPrint('[OllamaProvider] Connection failed: $e');
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
    debugPrint('[OllamaProvider] Disconnected from Ollama');
  }

  @override
  Future<bool> testConnection() async {
    try {
      final baseUrl = _getBaseUrl();
      _dio.options.baseUrl = baseUrl;
      final response = await _dio.get('/api/version',
          options: Options(headers: _getHeaders()));

      if (response.statusCode == 200) {
        _isAvailable = true;
        _clearError();
        notifyListeners();
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.data}');
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
      _dio.options.baseUrl = baseUrl;
      final response =
          await _dio.get('/api/tags', options: Options(headers: _getHeaders()));

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
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

        debugPrint(
            '[OllamaProvider] Loaded ${_availableModels.length} models from Ollama');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      _lastError = 'Failed to refresh models: $e';
      debugPrint('[OllamaProvider] Refresh models failed: $e');
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

    debugPrint('[OllamaProvider] Selected model: $modelId');
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

    final requestId = _startRequest();
    try {
      _setLoading(true);

      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final baseUrl = _getBaseUrl();
      _dio.options.baseUrl = baseUrl;
      final response = await _dio.post(
        '/api/chat',
        data: {
          'model': model,
          'messages': messages,
          'stream': false,
          ...?options,
        },
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final responseMessage = data['message'] as Map<String, dynamic>?;
        return responseMessage?['content'] as String? ?? '';
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      _lastError = 'Failed to send message: $e';
      debugPrint('[OllamaProvider] Send message failed: $e');
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
      throw Exception('Ollama provider is not available');
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

      final baseUrl = _getBaseUrl();
      _dio.options.baseUrl = baseUrl;
      final response = await _dio.post(
        '/api/chat',
        data: {
          'model': model,
          'messages': messages,
          'stream': true,
          ...?options,
        },
        options: Options(
          headers: _getHeaders(),
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode == 200) {
        await for (final chunk in response.data.stream.transform(
          convert.utf8.decoder,
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
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _lastError = 'Failed to send streaming message: $e';
      debugPrint('[OllamaProvider] Streaming failed: $e');
      rethrow;
    } finally {
      _endRequest(requestId);
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
    return OllamaSettingsWidget(provider: this);
  }

  // Helper methods
  String _getBaseUrl() {
    switch (_connectionManager.getBestConnectionType()) {
      case ConnectionType.local:
        return 'http://localhost:11434';
      case ConnectionType.cloud:
        return AppConfig.cloudOllamaUrl;
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
    _dio.close();
    super.dispose();
  }
}

/// Ollama Settings Widget
///
/// Provides configuration UI for Ollama provider settings
class OllamaSettingsWidget extends StatefulWidget {
  final OllamaProvider provider;

  const OllamaSettingsWidget({super.key, required this.provider});

  @override
  State<OllamaSettingsWidget> createState() => _OllamaSettingsWidgetState();
}

class _OllamaSettingsWidgetState extends State<OllamaSettingsWidget> {
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
          'Ollama Configuration',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Connection type info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Connection Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.provider._connectionManager.getBestConnectionType() ==
                        ConnectionType.local
                    ? 'Local Connection: Direct connection to Ollama on this device'
                    : 'Cloud Connection: Using CloudToLocalLLM proxy service',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Base URL field (only for local connections)
        if (widget.provider._connectionManager.getBestConnectionType() ==
            ConnectionType.local) ...[
          TextFormField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Ollama API URL',
              hintText: 'http://localhost:11434',
              border: OutlineInputBorder(),
              helperText:
                  'URL where Ollama is running (usually localhost:11434)',
            ),
            onChanged: _onConfigurationChanged,
          ),
          const SizedBox(height: 16),
        ],

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
                    'Ollama Setup',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Download and install Ollama from ollama.ai\n'
                '2. Run "ollama serve" to start the server\n'
                '3. Pull models with "ollama pull <model-name>"\n'
                '4. Use the default URL: http://localhost:11434',
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
          _connectionTestResult = 'Success: Connected to Ollama';
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
