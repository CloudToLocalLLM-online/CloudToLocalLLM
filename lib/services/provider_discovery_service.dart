/// Provider Discovery Service
///
/// Scans for available LLM providers on the local system and validates their endpoints.
/// Supports auto-detection of Ollama, LM Studio, and OpenAI-compatible APIs.
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Supported LLM provider types
enum ProviderType { ollama, lmStudio, openAICompatible, custom }

/// Provider status enumeration
enum ProviderStatus { available, unavailable, error, unknown }

/// Provider information model
class ProviderInfo {
  final String id;
  final String name;
  final ProviderType type;
  final String baseUrl;
  final int port;
  final Map<String, dynamic> capabilities;
  final ProviderStatus status;
  final DateTime lastSeen;
  final List<String> availableModels;
  final String? version;
  final Map<String, dynamic>? metadata;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.port,
    required this.capabilities,
    required this.status,
    required this.lastSeen,
    required this.availableModels,
    this.version,
    this.metadata,
  });

  /// Create ProviderInfo from JSON
  factory ProviderInfo.fromJson(Map<String, dynamic> json) {
    return ProviderInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ProviderType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ProviderType.custom,
      ),
      baseUrl: json['baseUrl'] as String,
      port: json['port'] as int,
      capabilities: Map<String, dynamic>.from(json['capabilities'] ?? {}),
      status: ProviderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => ProviderStatus.unknown,
      ),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      availableModels: List<String>.from(json['availableModels'] ?? []),
      version: json['version'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  /// Convert ProviderInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'baseUrl': baseUrl,
      'port': port,
      'capabilities': capabilities,
      'status': status.toString().split('.').last,
      'lastSeen': lastSeen.toIso8601String(),
      'availableModels': availableModels,
      'version': version,
      'metadata': metadata,
    };
  }

  /// Create a copy with updated fields
  ProviderInfo copyWith({
    String? id,
    String? name,
    ProviderType? type,
    String? baseUrl,
    int? port,
    Map<String, dynamic>? capabilities,
    ProviderStatus? status,
    DateTime? lastSeen,
    List<String>? availableModels,
    String? version,
    Map<String, dynamic>? metadata,
  }) {
    return ProviderInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      port: port ?? this.port,
      capabilities: capabilities ?? this.capabilities,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      availableModels: availableModels ?? this.availableModels,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ProviderInfo(id: $id, name: $name, type: $type, status: $status, baseUrl: $baseUrl)';
  }
}

/// Provider Discovery Service
class ProviderDiscoveryService extends ChangeNotifier {
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const Duration _scanInterval = Duration(seconds: 30);

  final http.Client _httpClient;
  final List<ProviderInfo> _discoveredProviders = [];
  final Map<String, DateTime> _lastScanTimes = {};

  Timer? _periodicScanTimer;
  bool _isScanning = false;
  final bool _isWebPlatform = kIsWeb;

  ProviderDiscoveryService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client() {

    // Log platform detection for debugging
    if (_isWebPlatform) {
      debugPrint(' [ProviderDiscovery] Web platform detected - discovery service will be limited');
      debugPrint(' [ProviderDiscovery] Direct localhost scanning disabled to prevent CORS errors');
      debugPrint(' [ProviderDiscovery] Web platform should use tunnel/bridge system for provider access');
    } else {
      debugPrint(' [ProviderDiscovery] Desktop platform detected - full discovery service enabled');
    }
  }

  /// Get list of discovered providers
  List<ProviderInfo> get discoveredProviders =>
      List.unmodifiable(_discoveredProviders);

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Start periodic provider scanning
  void startPeriodicScanning() {
    _periodicScanTimer?.cancel();
    _periodicScanTimer = Timer.periodic(
      _scanInterval,
      (_) => scanForProviders(),
    );
  }

  /// Stop periodic provider scanning
  void stopPeriodicScanning() {
    _periodicScanTimer?.cancel();
    _periodicScanTimer = null;
  }

  /// Scan for all available LLM providers
  ///
  /// Note: On web platforms, this method returns an empty list to prevent CORS errors
  /// from direct localhost connections. Web platforms should use the tunnel/bridge system.
  Future<List<ProviderInfo>> scanForProviders() async {
    // Skip scanning on web platforms to prevent CORS errors
    if (_isWebPlatform) {
      debugPrint(' [ProviderDiscovery] Skipping provider scan on web platform');
      debugPrint(' [ProviderDiscovery] Web platform should use tunnel/bridge for provider access');
      return [];
    }

    if (_isScanning) {
      debugPrint('Provider scan already in progress, skipping...');
      return _discoveredProviders;
    }

    _isScanning = true;
    notifyListeners();

    try {
      debugPrint('Starting provider discovery scan...');

      // Update last scan time
      _lastScanTimes['all'] = DateTime.now();

      final List<ProviderInfo> foundProviders = [];

      // Scan for different provider types concurrently
      final results = await Future.wait([
        detectOllama(),
        detectLMStudio(),
        detectOpenAICompatible(),
      ]);

      // Collect all non-null results
      for (final result in results) {
        if (result != null) {
          if (result is List<ProviderInfo>) {
            foundProviders.addAll(result);
          } else if (result is ProviderInfo) {
            foundProviders.add(result);
          }
        }
      }

      // Update discovered providers list
      _discoveredProviders.clear();
      _discoveredProviders.addAll(foundProviders);

      debugPrint(
        'Provider discovery completed. Found ${foundProviders.length} providers',
      );

      notifyListeners();
      return foundProviders;
    } catch (error) {
      debugPrint('Error during provider discovery: $error');
      return _discoveredProviders;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Detect Ollama provider (default port 11434)
  Future<ProviderInfo?> detectOllama({int port = 11434}) async {
    // Skip detection on web platforms to prevent CORS errors
    if (_isWebPlatform) {
      debugPrint(' [ProviderDiscovery] Skipping Ollama detection on web platform (port $port)');
      return null;
    }

    final baseUrl = 'http://localhost:$port';

    try {
      debugPrint('Detecting Ollama on port $port...');

      // Check if Ollama is running by hitting the version endpoint
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/version'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final versionData = jsonDecode(response.body);

        // Get available models
        final models = await _getOllamaModels(baseUrl);

        final provider = ProviderInfo(
          id: 'ollama_$port',
          name: 'Ollama',
          type: ProviderType.ollama,
          baseUrl: baseUrl,
          port: port,
          capabilities: {
            'chat': true,
            'completion': true,
            'embeddings': true,
            'streaming': true,
            'model_management': true,
          },
          status: ProviderStatus.available,
          lastSeen: DateTime.now(),
          availableModels: models,
          version: versionData['version'] as String?,
          metadata: {
            'api_version': versionData,
            'detected_at': DateTime.now().toIso8601String(),
          },
        );

        debugPrint('Ollama detected successfully: ${provider.version}');
        return provider;
      }
    } catch (error) {
      debugPrint('Ollama detection failed on port $port: $error');
    }

    return null;
  }

  /// Detect LM Studio provider (default port 1234)
  Future<ProviderInfo?> detectLMStudio({int port = 1234}) async {
    // Skip detection on web platforms to prevent CORS errors
    if (_isWebPlatform) {
      debugPrint(' [ProviderDiscovery] Skipping LM Studio detection on web platform (port $port)');
      return null;
    }

    final baseUrl = 'http://localhost:$port';

    try {
      debugPrint('Detecting LM Studio on port $port...');

      // LM Studio uses OpenAI-compatible API, check models endpoint
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/v1/models'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final modelsData = jsonDecode(response.body);
        final models = <String>[];

        if (modelsData['data'] is List) {
          for (final model in modelsData['data']) {
            if (model['id'] is String) {
              models.add(model['id'] as String);
            }
          }
        }

        // Try to detect if this is specifically LM Studio
        final isLMStudio = await _isLMStudioEndpoint(baseUrl);

        if (isLMStudio) {
          final provider = ProviderInfo(
            id: 'lmstudio_$port',
            name: 'LM Studio',
            type: ProviderType.lmStudio,
            baseUrl: baseUrl,
            port: port,
            capabilities: {
              'chat': true,
              'completion': true,
              'streaming': true,
              'openai_compatible': true,
            },
            status: ProviderStatus.available,
            lastSeen: DateTime.now(),
            availableModels: models,
            metadata: {
              'api_type': 'openai_compatible',
              'detected_at': DateTime.now().toIso8601String(),
            },
          );

          debugPrint(
            'LM Studio detected successfully with ${models.length} models',
          );
          return provider;
        }
      }
    } catch (error) {
      debugPrint('LM Studio detection failed on port $port: $error');
    }

    return null;
  }

  /// Detect OpenAI-compatible APIs on common ports
  Future<List<ProviderInfo>> detectOpenAICompatible() async {
    // Skip detection on web platforms to prevent CORS errors
    if (_isWebPlatform) {
      debugPrint(' [ProviderDiscovery] Skipping OpenAI-compatible API detection on web platform');
      return [];
    }

    final commonPorts = [8080, 5000, 3000, 8000, 7860, 5001];
    final providers = <ProviderInfo>[];

    debugPrint('Scanning for OpenAI-compatible APIs on common ports...');

    for (final port in commonPorts) {
      final baseUrl = 'http://localhost:$port';

      try {
        // Check for OpenAI-compatible API
        final response = await _httpClient
            .get(
              Uri.parse('$baseUrl/v1/models'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(_defaultTimeout);

        if (response.statusCode == 200) {
          final modelsData = jsonDecode(response.body);
          final models = <String>[];

          if (modelsData['data'] is List) {
            for (final model in modelsData['data']) {
              if (model['id'] is String) {
                models.add(model['id'] as String);
              }
            }
          }

          // Skip if this is LM Studio (handled separately)
          if (await _isLMStudioEndpoint(baseUrl)) {
            continue;
          }

          final provider = ProviderInfo(
            id: 'openai_compatible_$port',
            name: 'OpenAI Compatible API (Port $port)',
            type: ProviderType.openAICompatible,
            baseUrl: baseUrl,
            port: port,
            capabilities: {
              'chat': true,
              'completion': true,
              'streaming': true,
              'openai_compatible': true,
            },
            status: ProviderStatus.available,
            lastSeen: DateTime.now(),
            availableModels: models,
            metadata: {
              'api_type': 'openai_compatible',
              'detected_at': DateTime.now().toIso8601String(),
            },
          );

          providers.add(provider);
          debugPrint(
            'OpenAI-compatible API detected on port $port with ${models.length} models',
          );
        }
      } catch (error) {
        // Silently continue - most ports won't have APIs running
        continue;
      }
    }

    return providers;
  }

  /// Validate provider endpoint and capabilities
  Future<bool> validateProviderEndpoint(ProviderInfo provider) async {
    try {
      debugPrint('Validating provider endpoint: ${provider.name}');

      switch (provider.type) {
        case ProviderType.ollama:
          return await _validateOllamaEndpoint(provider);
        case ProviderType.lmStudio:
        case ProviderType.openAICompatible:
          return await _validateOpenAICompatibleEndpoint(provider);
        case ProviderType.custom:
          return await _validateCustomEndpoint(provider);
      }
    } catch (error) {
      debugPrint('Provider validation failed for ${provider.name}: $error');
      return false;
    }
  }

  /// Get available models from Ollama
  Future<List<String>> _getOllamaModels(String baseUrl) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/tags'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = <String>[];

        if (data['models'] is List) {
          for (final model in data['models']) {
            if (model['name'] is String) {
              models.add(model['name'] as String);
            }
          }
        }

        return models;
      }
    } catch (error) {
      debugPrint('Failed to get Ollama models: $error');
    }

    return [];
  }

  /// Check if endpoint is specifically LM Studio
  Future<bool> _isLMStudioEndpoint(String baseUrl) async {
    try {
      // LM Studio often has specific headers or responses that identify it
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/v1/models'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_defaultTimeout);

      // Check for LM Studio-specific indicators in headers or response
      final serverHeader = response.headers['server']?.toLowerCase();
      if (serverHeader != null && serverHeader.contains('lm studio')) {
        return true;
      }

      // Check response body for LM Studio indicators
      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        if (body.contains('lm studio') || body.contains('lmstudio')) {
          return true;
        }
      }

      return false;
    } catch (error) {
      return false;
    }
  }

  /// Validate Ollama endpoint
  Future<bool> _validateOllamaEndpoint(ProviderInfo provider) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('${provider.baseUrl}/api/version'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_defaultTimeout);

      return response.statusCode == 200;
    } catch (error) {
      return false;
    }
  }

  /// Validate OpenAI-compatible endpoint
  Future<bool> _validateOpenAICompatibleEndpoint(ProviderInfo provider) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('${provider.baseUrl}/v1/models'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_defaultTimeout);

      return response.statusCode == 200;
    } catch (error) {
      return false;
    }
  }

  /// Validate custom endpoint
  Future<bool> _validateCustomEndpoint(ProviderInfo provider) async {
    try {
      // For custom endpoints, try a basic health check
      final response = await _httpClient
          .get(
            Uri.parse(provider.baseUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_defaultTimeout);

      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (error) {
      return false;
    }
  }

  /// Get provider by ID
  ProviderInfo? getProviderById(String id) {
    try {
      return _discoveredProviders.firstWhere((provider) => provider.id == id);
    } catch (error) {
      return null;
    }
  }

  /// Get providers by type
  List<ProviderInfo> getProvidersByType(ProviderType type) {
    return _discoveredProviders
        .where((provider) => provider.type == type)
        .toList();
  }

  /// Get available providers (status = available)
  List<ProviderInfo> getAvailableProviders() {
    return _discoveredProviders
        .where((provider) => provider.status == ProviderStatus.available)
        .toList();
  }

  /// Dispose resources
  @override
  void dispose() {
    stopPeriodicScanning();
    _httpClient.close();
    super.dispose();
  }
}
