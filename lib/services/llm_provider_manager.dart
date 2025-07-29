import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'llm_providers/base_llm_provider.dart';
import 'llm_providers/ollama_provider.dart';
import 'llm_providers/lm_studio_provider.dart';
import 'connection_manager_service.dart';
import '../utils/tunnel_logger.dart';

/// LLM Provider Manager Service
///
/// Manages multiple LLM providers and handles switching between them.
/// Provides a unified interface for the application to interact with
/// different LLM providers like Ollama, LM Studio, OpenAI-compatible APIs, etc.
class LLMProviderManager extends ChangeNotifier {
  final ConnectionManagerService _connectionManager;
  final TunnelLogger _logger = TunnelLogger('LLMProviderManager');

  // Providers
  final Map<String, BaseLLMProvider> _providers = {};
  BaseLLMProvider? _activeProvider;
  String? _activeProviderId;

  // State
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _lastError;

  // Preferences
  static const String _prefActiveProvider = 'active_llm_provider';
  static const String _prefProviderConfigs = 'llm_provider_configs';

  LLMProviderManager({required ConnectionManagerService connectionManager})
    : _connectionManager = connectionManager;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  BaseLLMProvider? get activeProvider => _activeProvider;
  String? get activeProviderId => _activeProviderId;
  List<BaseLLMProvider> get availableProviders => _providers.values.toList();
  List<String> get availableProviderIds => _providers.keys.toList();

  /// Initialize the provider manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      _clearError();

      _logger.info('Initializing LLM Provider Manager');

      // Register built-in providers
      await _registerBuiltInProviders();

      // Load saved preferences
      await _loadPreferences();

      // Initialize providers
      await _initializeProviders();

      // Set active provider
      await _setActiveProviderFromPreferences();

      _isInitialized = true;
      _logger.info('LLM Provider Manager initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize LLM Provider Manager: $e';
      _logger.logTunnelError(
        'PROVIDER_MANAGER_INIT_FAILED',
        _lastError!,
        error: e,
      );
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Register built-in providers
  Future<void> _registerBuiltInProviders() async {
    // Register Ollama provider
    final ollamaProvider = OllamaProvider(
      connectionManager: _connectionManager,
    );
    _providers[ollamaProvider.providerId] = ollamaProvider;

    // Register LM Studio provider
    final lmStudioProvider = LMStudioProvider();
    _providers[lmStudioProvider.providerId] = lmStudioProvider;

    _logger.info('Registered ${_providers.length} built-in providers');
  }

  /// Initialize all providers
  Future<void> _initializeProviders() async {
    final futures = <Future<void>>[];

    for (final provider in _providers.values) {
      futures.add(_initializeProvider(provider));
    }

    // Initialize all providers concurrently
    await Future.wait(futures);
  }

  /// Initialize a single provider
  Future<void> _initializeProvider(BaseLLMProvider provider) async {
    try {
      await provider.initialize();
      _logger.info('Initialized provider: ${provider.providerId}');
    } catch (e) {
      _logger.logTunnelError(
        'PROVIDER_INIT_FAILED',
        'Failed to initialize provider: ${provider.providerId}',
        error: e,
      );
      // Don't rethrow - allow other providers to initialize
    }
  }

  /// Switch to a different provider
  Future<void> switchProvider(String providerId) async {
    if (_activeProviderId == providerId) return;

    final provider = _providers[providerId];
    if (provider == null) {
      throw ArgumentError('Provider not found: $providerId');
    }

    try {
      _setLoading(true);
      _clearError();

      _logger.info('Switching to provider: $providerId');

      // Ensure the provider is connected
      if (!provider.isAvailable) {
        await provider.connect();
      }

      _activeProvider = provider;
      _activeProviderId = providerId;

      // Save preference
      await _saveActiveProviderPreference(providerId);

      _logger.info('Successfully switched to provider: $providerId');
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to switch to provider $providerId: $e';
      _logger.logTunnelError('PROVIDER_SWITCH_FAILED', _lastError!, error: e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get provider by ID
  BaseLLMProvider? getProvider(String providerId) {
    return _providers[providerId];
  }

  /// Register a custom provider
  Future<void> registerProvider(BaseLLMProvider provider) async {
    _providers[provider.providerId] = provider;

    if (_isInitialized) {
      await _initializeProvider(provider);
    }

    notifyListeners();
    _logger.info('Registered custom provider: ${provider.providerId}');
  }

  /// Update provider configuration and save to preferences
  Future<void> updateProviderConfiguration(
    String providerId,
    Map<String, dynamic> config,
  ) async {
    final provider = _providers[providerId];
    if (provider == null) {
      throw ArgumentError('Provider not found: $providerId');
    }

    // Validate the configuration
    if (!provider.validateConfiguration(config)) {
      throw ArgumentError('Invalid configuration for provider: $providerId');
    }

    // Update the provider configuration
    await provider.updateConfiguration(config);

    // Save all configurations to preferences
    await saveProviderConfigurations();

    _logger.info('Updated and saved configuration for provider: $providerId');
  }

  /// Unregister a provider
  void unregisterProvider(String providerId) {
    final provider = _providers.remove(providerId);
    if (provider != null) {
      provider.dispose();

      // If this was the active provider, switch to another one
      if (_activeProviderId == providerId) {
        _activeProvider = null;
        _activeProviderId = null;
        _autoSelectProvider();
      }

      notifyListeners();
      _logger.info('Unregistered provider: $providerId');
    }
  }

  /// Auto-select the best available provider
  Future<void> _autoSelectProvider() async {
    if (_activeProvider?.isAvailable == true) return;

    // Try to find an available provider
    for (final provider in _providers.values) {
      if (provider.isAvailable) {
        await switchProvider(provider.providerId);
        return;
      }
    }

    // If no provider is available, try to connect to the first one
    if (_providers.isNotEmpty) {
      final firstProvider = _providers.values.first;
      try {
        await switchProvider(firstProvider.providerId);
      } catch (e) {
        _logger.logTunnelError(
          'AUTO_SELECT_FAILED',
          'Failed to auto-select provider',
          error: e,
        );
      }
    }
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load active provider preference
      _activeProviderId = prefs.getString(_prefActiveProvider);

      // Load provider configurations
      final configsJson = prefs.getString(_prefProviderConfigs);
      if (configsJson != null) {
        await _loadAndApplyProviderConfigurations(configsJson);
      }
    } catch (e) {
      _logger.logTunnelError(
        'LOAD_PREFERENCES_FAILED',
        'Failed to load preferences',
        error: e,
      );
    }
  }

  /// Set active provider from preferences
  Future<void> _setActiveProviderFromPreferences() async {
    if (_activeProviderId != null &&
        _providers.containsKey(_activeProviderId)) {
      try {
        await switchProvider(_activeProviderId!);
      } catch (e) {
        _logger.logTunnelError(
          'SET_ACTIVE_PROVIDER_FAILED',
          'Failed to set active provider from preferences',
          error: e,
        );
        await _autoSelectProvider();
      }
    } else {
      await _autoSelectProvider();
    }
  }

  /// Save active provider preference
  Future<void> _saveActiveProviderPreference(String providerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefActiveProvider, providerId);
    } catch (e) {
      _logger.logTunnelError(
        'SAVE_PREFERENCE_FAILED',
        'Failed to save active provider preference',
        error: e,
      );
    }
  }

  /// Refresh all providers
  Future<void> refreshAllProviders() async {
    final futures = <Future<void>>[];

    for (final provider in _providers.values) {
      if (provider.isAvailable) {
        futures.add(provider.refreshModels());
      }
    }

    await Future.wait(futures);
    notifyListeners();
  }

  /// Test all provider connections
  Future<Map<String, bool>> testAllConnections() async {
    final results = <String, bool>{};

    for (final entry in _providers.entries) {
      try {
        results[entry.key] = await entry.value.testConnection();
      } catch (e) {
        results[entry.key] = false;
      }
    }

    return results;
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Load and apply provider configurations from JSON
  Future<void> _loadAndApplyProviderConfigurations(String configsJson) async {
    try {
      final configsData = json.decode(configsJson) as Map<String, dynamic>;

      for (final entry in configsData.entries) {
        final providerId = entry.key;
        final configData = entry.value as Map<String, dynamic>;

        // Find the provider
        final provider = _providers[providerId];
        if (provider == null) {
          _logger.logTunnelError(
            'PROVIDER_CONFIG_LOAD_FAILED',
            'Provider not found for configuration: $providerId',
          );
          continue;
        }

        // Validate the configuration
        if (!provider.validateConfiguration(configData)) {
          _logger.logTunnelError(
            'PROVIDER_CONFIG_INVALID',
            'Invalid configuration for provider: $providerId',
          );
          continue;
        }

        // Apply the configuration
        try {
          await provider.updateConfiguration(configData);
          _logger.info('Applied configuration for provider: $providerId');
        } catch (e) {
          _logger.logTunnelError(
            'PROVIDER_CONFIG_APPLY_FAILED',
            'Failed to apply configuration for provider: $providerId',
            error: e,
          );
        }
      }
    } catch (e) {
      _logger.logTunnelError(
        'PROVIDER_CONFIGS_PARSE_FAILED',
        'Failed to parse provider configurations JSON',
        error: e,
      );
    }
  }

  /// Save provider configurations to preferences
  Future<void> saveProviderConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsData = <String, dynamic>{};

      // Collect configurations from all providers
      for (final entry in _providers.entries) {
        final providerId = entry.key;
        final provider = entry.value;
        configsData[providerId] = provider.configuration;
      }

      // Save to preferences
      final configsJson = json.encode(configsData);
      await prefs.setString(_prefProviderConfigs, configsJson);

      _logger.info('Saved provider configurations');
    } catch (e) {
      _logger.logTunnelError(
        'SAVE_PROVIDER_CONFIGS_FAILED',
        'Failed to save provider configurations',
        error: e,
      );
    }
  }

  @override
  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    _providers.clear();
    super.dispose();
  }
}
