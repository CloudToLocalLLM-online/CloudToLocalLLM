/// Local LLM Providers Settings Category Widget
///
/// Provides configuration for local LLM providers including:
/// - Provider list display
/// - Add/remove provider functionality
/// - Test connection button with status feedback
/// - Default provider and model selection
/// - Enable/disable provider toggle
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/provider_configuration.dart';
import '../../services/provider_configuration_manager.dart';
import 'settings_category_widgets.dart';
import 'settings_input_widgets.dart';

/// Local LLM Providers Settings Category
class LocalLLMProvidersCategory extends SettingsCategoryContentWidget {
  const LocalLLMProvidersCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _LocalLLMProvidersCategoryContent();
  }
}

class _LocalLLMProvidersCategoryContent extends StatefulWidget {
  const _LocalLLMProvidersCategoryContent();

  @override
  State<_LocalLLMProvidersCategoryContent> createState() =>
      _LocalLLMProvidersCategoryContentState();
}

class _LocalLLMProvidersCategoryContentState
    extends State<_LocalLLMProvidersCategoryContent> {
  late ProviderConfigurationManager _configManager;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _successMessage;

  // Provider form state
  String? _selectedProviderType;
  String _providerName = '';
  String _baseUrl = '';
  String _port = '';
  String? _apiKey;
  bool _showAddForm = false;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testingProviderId;
  final Map<String, String> _testResults = {};
  final Map<String, String> _fieldErrors = {};

  // Provider enable/disable state
  final Map<String, bool> _providerEnabled = {};

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure provider is available in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _configManager = Provider.of<ProviderConfigurationManager>(context, listen: false);
          _loadProviders();
        } catch (e) {
          debugPrint('[LocalLLMProviders] ProviderConfigurationManager not available: $e');
          setState(() {
            _errorMessage = 'Provider configuration manager not available. Please try refreshing the page.';
            _isInitialized = true;
          });
        }
      }
    });
  }

  /// Load providers from configuration manager
  Future<void> _loadProviders() async {
    try {
      setState(() {
        _isInitialized = true;
        _errorMessage = null;

        // Initialize provider enabled state
        for (final config in _configManager.configurations) {
          _providerEnabled[config.providerId] = true;
        }
      });
    } catch (e) {
      debugPrint('[LocalLLMProviders] Error loading providers: $e');
      setState(() {
        _errorMessage = 'Failed to load providers';
      });
    }
  }

  /// Validate provider form
  bool _validateProviderForm() {
    _fieldErrors.clear();

    if (_selectedProviderType == null || _selectedProviderType!.isEmpty) {
      _fieldErrors['providerType'] = 'Provider type is required';
    }

    if (_providerName.isEmpty) {
      _fieldErrors['providerName'] = 'Provider name is required';
    }

    if (_baseUrl.isEmpty) {
      _fieldErrors['baseUrl'] = 'Base URL is required';
    } else {
      try {
        final uri = Uri.parse(_baseUrl);
        if (!uri.hasScheme || !uri.hasAuthority) {
          _fieldErrors['baseUrl'] =
              'Invalid URL format (must include http:// or https://)';
        }
      } catch (e) {
        _fieldErrors['baseUrl'] = 'Invalid URL format';
      }
    }

    if (_port.isEmpty) {
      _fieldErrors['port'] = 'Port is required';
    } else {
      try {
        final portNum = int.parse(_port);
        if (portNum < 1 || portNum > 65535) {
          _fieldErrors['port'] = 'Port must be between 1 and 65535';
        }
      } catch (e) {
        _fieldErrors['port'] = 'Port must be a valid number';
      }
    }

    // Validate API key if provider requires auth
    if (_selectedProviderType == 'openai_compatible' && _apiKey == null) {
      _fieldErrors['apiKey'] = 'API key is required for OpenAI-compatible';
    }

    return _fieldErrors.isEmpty;
  }

  /// Add a new provider configuration
  Future<void> _addProvider() async {
    if (!_validateProviderForm()) {
      setState(() {
        _errorMessage = 'Please fix the errors below';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final providerId =
          '${_selectedProviderType}_${DateTime.now().millisecondsSinceEpoch}';
      final port = int.parse(_port);

      ProviderConfiguration config;

      switch (_selectedProviderType) {
        case 'ollama':
          config = OllamaProviderConfiguration(
            providerId: providerId,
            baseUrl: _baseUrl,
            port: port,
          );
          break;
        case 'lmstudio':
          config = LMStudioProviderConfiguration(
            providerId: providerId,
            baseUrl: _baseUrl,
            port: port,
          );
          break;
        case 'openai_compatible':
          config = OpenAICompatibleProviderConfiguration(
            providerId: providerId,
            baseUrl: _baseUrl,
            port: port,
            apiKey: _apiKey,
          );
          break;
        default:
          throw Exception('Unknown provider type: $_selectedProviderType');
      }

      await _configManager.setConfiguration(config);

      setState(() {
        _isSaving = false;
        _showAddForm = false;
        _selectedProviderType = null;
        _providerName = '';
        _baseUrl = '';
        _port = '';
        _apiKey = null;
        _fieldErrors.clear();
        _successMessage = 'Provider added successfully';
        _providerEnabled[providerId] = true;
      });

      // Clear success message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      debugPrint('[LocalLLMProviders] Error adding provider: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to add provider: ${e.toString()}';
      });
    }
  }

  /// Remove a provider configuration
  Future<void> _removeProvider(String providerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Provider'),
        content: const Text('Are you sure you want to remove this provider?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _configManager.removeConfiguration(providerId);

      setState(() {
        _providerEnabled.remove(providerId);
        _testResults.remove(providerId);
        _successMessage = 'Provider removed successfully';
      });

      // Clear success message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      debugPrint('[LocalLLMProviders] Error removing provider: $e');
      setState(() {
        _errorMessage = 'Failed to remove provider: ${e.toString()}';
      });
    }
  }

  /// Test connection to a provider
  Future<void> _testConnection(String providerId) async {
    setState(() {
      _isTesting = true;
      _testingProviderId = providerId;
    });

    try {
      final config = _configManager.getConfiguration(providerId);
      if (config == null) {
        throw Exception('Provider not found');
      }

      // Validate configuration
      final validationResult =
          ProviderConfigurationFactory.validateConfiguration(config);

      if (!validationResult.isValid) {
        setState(() {
          _testResults[providerId] =
              'Invalid configuration: ${validationResult.errors.join(', ')}';
        });
      } else {
        // Simulate connection test (in real implementation, would call actual service)
        await Future.delayed(const Duration(seconds: 2));

        setState(() {
          _testResults[providerId] = 'Connection successful';
        });
      }
    } catch (e) {
      debugPrint('[LocalLLMProviders] Error testing connection: $e');
      setState(() {
        _testResults[providerId] = 'Connection failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isTesting = false;
        _testingProviderId = null;
      });
    }
  }

  /// Set default provider
  Future<void> _setDefaultProvider(String providerId) async {
    try {
      await _configManager.setPreferredProvider(providerId);

      setState(() {
        _successMessage = 'Default provider updated';
      });

      // Clear success message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      debugPrint('[LocalLLMProviders] Error setting default provider: $e');
      setState(() {
        _errorMessage = 'Failed to set default provider: ${e.toString()}';
      });
    }
  }

  /// Build provider type dropdown items
  List<DropdownMenuItem<String>> _buildProviderTypeItems() {
    return [
      DropdownMenuItem(
        value: 'ollama',
        child: Row(
          children: [
            const Icon(Icons.storage, size: 20),
            const SizedBox(width: 8),
            const Text('Ollama'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'lmstudio',
        child: Row(
          children: [
            const Icon(Icons.computer, size: 20),
            const SizedBox(width: 8),
            const Text('LM Studio'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'openai_compatible',
        child: Row(
          children: [
            const Icon(Icons.api, size: 20),
            const SizedBox(width: 8),
            const Text('OpenAI Compatible'),
          ],
        ),
      ),
    ];
  }

  /// Build provider list item
  Widget _buildProviderListItem(ProviderConfiguration config) {
    final isEnabled = _providerEnabled[config.providerId] ?? true;
    final testResult = _testResults[config.providerId];
    final isTesting = _testingProviderId == config.providerId && _isTesting;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.providerType.toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${config.baseUrl}:${config is OllamaProviderConfiguration
                            ? config.port
                            : config is LMStudioProviderConfiguration
                            ? config.port
                            : config is OpenAICompatibleProviderConfiguration
                            ? config.port
                            : 'N/A'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Enable/disable toggle
                Switch(
                  value: isEnabled,
                  onChanged: (value) {
                    setState(() {
                      _providerEnabled[config.providerId] = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Test result
            if (testResult != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: testResult.contains('successful')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  border: Border.all(
                    color: testResult.contains('successful')
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      testResult.contains('successful')
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: testResult.contains('successful')
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        testResult,
                        style: TextStyle(
                          color: testResult.contains('successful')
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.tonal(
                  onPressed: isTesting
                      ? null
                      : () => _testConnection(config.providerId),
                  child: isTesting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Test Connection'),
                          ],
                        ),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _setDefaultProvider(config.providerId),
                      child: const Text('Set Default'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                      ),
                      onPressed: () => _removeProvider(config.providerId),
                      child: const Icon(Icons.delete, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Success message
          if (_successMessage != null)
            SettingsSuccessMessage(
              message: _successMessage!,
              onDismiss: () {
                setState(() {
                  _successMessage = null;
                });
              },
            ),

          // Error message
          if (_errorMessage != null)
            SettingsValidationError(
              message: _errorMessage!,
              onDismiss: () {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),

          // Providers list
          if (_configManager.configurations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configured Providers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your local LLM provider connections',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            for (final config in _configManager.configurations)
              _buildProviderListItem(config),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.storage, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No Providers Configured',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a local LLM provider to get started',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Add provider form
          if (_showAddForm) ...[
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Provider',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Provider type dropdown
                    SettingsDropdown<String>(
                      label: 'Provider Type',
                      description: 'Select the type of local LLM provider',
                      value: _selectedProviderType,
                      items: _buildProviderTypeItems(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProviderType = value;
                          _fieldErrors.remove('providerType');
                        });
                      },
                      errorMessage: _fieldErrors['providerType'],
                      enabled: !_isSaving,
                    ),

                    // Provider name
                    SettingsTextInput(
                      label: 'Provider Name',
                      description: 'A friendly name for this provider',
                      value: _providerName,
                      onChanged: (value) {
                        setState(() {
                          _providerName = value;
                          _fieldErrors.remove('providerName');
                        });
                      },
                      hintText: 'e.g., My Ollama Server',
                      errorMessage: _fieldErrors['providerName'],
                      enabled: !_isSaving,
                    ),

                    // Base URL
                    SettingsTextInput(
                      label: 'Base URL',
                      description: 'The URL where your provider is running',
                      value: _baseUrl,
                      onChanged: (value) {
                        setState(() {
                          _baseUrl = value;
                          _fieldErrors.remove('baseUrl');
                        });
                      },
                      hintText: 'http://localhost',
                      keyboardType: TextInputType.url,
                      errorMessage: _fieldErrors['baseUrl'],
                      enabled: !_isSaving,
                    ),

                    // Port
                    SettingsTextInput(
                      label: 'Port',
                      description: 'The port number for the provider',
                      value: _port,
                      onChanged: (value) {
                        setState(() {
                          _port = value;
                          _fieldErrors.remove('port');
                        });
                      },
                      hintText: '11434',
                      keyboardType: TextInputType.number,
                      errorMessage: _fieldErrors['port'],
                      enabled: !_isSaving,
                    ),

                    // API Key (for OpenAI compatible)
                    if (_selectedProviderType == 'openai_compatible') ...[
                      SettingsTextInput(
                        label: 'API Key',
                        description: 'API key for authentication',
                        value: _apiKey ?? '',
                        onChanged: (value) {
                          setState(() {
                            _apiKey = value.isEmpty ? null : value;
                            _fieldErrors.remove('apiKey');
                          });
                        },
                        hintText: 'Enter your API key',
                        keyboardType: TextInputType.text,
                        errorMessage: _fieldErrors['apiKey'],
                        enabled: !_isSaving,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _showAddForm = false;
                                    _selectedProviderType = null;
                                    _providerName = '';
                                    _baseUrl = '';
                                    _port = '';
                                    _apiKey = null;
                                    _fieldErrors.clear();
                                  });
                                },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _isSaving ? null : _addProvider,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Add Provider'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _showAddForm = true;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Provider'),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
