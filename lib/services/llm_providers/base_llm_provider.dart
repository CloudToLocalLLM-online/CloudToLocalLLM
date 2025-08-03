import 'package:flutter/material.dart';

/// Base interface for all LLM providers
///
/// This abstract class defines the common interface that all LLM providers
/// must implement, enabling seamless switching between different providers
/// like Ollama, LM Studio, OpenAI-compatible APIs, etc.
abstract class BaseLLMProvider extends ChangeNotifier {
  /// Unique identifier for this provider
  String get providerId;

  /// Human-readable name for this provider
  String get providerName;

  /// Description of this provider
  String get providerDescription;

  /// Icon identifier for this provider
  String get providerIcon;

  /// Whether this provider is currently available/connected
  bool get isAvailable;

  /// Whether this provider is currently connecting
  bool get isConnecting;

  /// Whether this provider is currently loading
  bool get isLoading;

  /// Last error message, if any
  String? get lastError;

  /// List of available models for this provider
  List<LLMModel> get availableModels;

  /// Currently selected model
  LLMModel? get selectedModel;

  /// Provider-specific configuration
  Map<String, dynamic> get configuration;

  /// Number of currently active requests
  int get activeRequestCount;

  /// Initialize the provider
  Future<void> initialize();

  /// Connect to the provider
  Future<void> connect();

  /// Disconnect from the provider
  Future<void> disconnect();

  /// Test the connection to the provider
  Future<bool> testConnection();

  /// Refresh the list of available models
  Future<void> refreshModels();

  /// Select a model for this provider
  Future<void> selectModel(String modelId);

  /// Send a chat message
  Future<String> sendMessage({
    required String message,
    String? modelId,
    List<Map<String, String>>? history,
    Map<String, dynamic>? options,
  });

  /// Send a streaming chat message
  Stream<String> sendStreamingMessage({
    required String message,
    String? modelId,
    List<Map<String, String>>? history,
    Map<String, dynamic>? options,
  });

  /// Pull/download a model
  Future<void> pullModel(String modelId, {Function(double)? onProgress});

  /// Delete a model
  Future<void> deleteModel(String modelId);

  /// Get model information
  Future<LLMModelInfo?> getModelInfo(String modelId);

  /// Update provider configuration
  Future<void> updateConfiguration(Map<String, dynamic> config);

  /// Validate provider configuration
  bool validateConfiguration(Map<String, dynamic> config);

  /// Get provider-specific settings UI
  Widget? getSettingsWidget();

  /// Dispose of resources
  @override
  void dispose();
}

/// Model information class
class LLMModel {
  final String id;
  final String name;
  final String? description;
  final String? version;
  final int? size;
  final DateTime? modifiedAt;
  final Map<String, dynamic>? metadata;

  const LLMModel({
    required this.id,
    required this.name,
    this.description,
    this.version,
    this.size,
    this.modifiedAt,
    this.metadata,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLMModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LLMModel(id: $id, name: $name)';
}

/// Detailed model information
class LLMModelInfo {
  final LLMModel model;
  final Map<String, dynamic> details;
  final List<String>? capabilities;
  final Map<String, dynamic>? parameters;

  const LLMModelInfo({
    required this.model,
    required this.details,
    this.capabilities,
    this.parameters,
  });
}

/// Provider configuration class
class LLMProviderConfig {
  final String providerId;
  final String baseUrl;
  final Map<String, String>? headers;
  final Duration timeout;
  final Map<String, dynamic> customSettings;

  const LLMProviderConfig({
    required this.providerId,
    required this.baseUrl,
    this.headers,
    this.timeout = const Duration(seconds: 30),
    this.customSettings = const {},
  });

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'baseUrl': baseUrl,
    'headers': headers,
    'timeout': timeout.inMilliseconds,
    'customSettings': customSettings,
  };

  factory LLMProviderConfig.fromJson(Map<String, dynamic> json) {
    return LLMProviderConfig(
      providerId: json['providerId'] as String,
      baseUrl: json['baseUrl'] as String,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
      timeout: Duration(milliseconds: json['timeout'] as int? ?? 30000),
      customSettings: json['customSettings'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Provider status enumeration
enum LLMProviderStatus {
  disconnected,
  connecting,
  connected,
  error,
  unavailable,
}

/// Provider capability flags
class LLMProviderCapabilities {
  final bool supportsStreaming;
  final bool supportsModelManagement;
  final bool supportsCustomModels;
  final bool supportsEmbeddings;
  final bool supportsImageGeneration;
  final bool supportsCodeGeneration;
  final List<String> supportedFormats;

  const LLMProviderCapabilities({
    this.supportsStreaming = false,
    this.supportsModelManagement = false,
    this.supportsCustomModels = false,
    this.supportsEmbeddings = false,
    this.supportsImageGeneration = false,
    this.supportsCodeGeneration = false,
    this.supportedFormats = const ['text'],
  });
}
