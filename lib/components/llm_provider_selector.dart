import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/theme.dart';
import '../services/llm_provider_manager.dart';

/// LLM Provider Selector Widget
///
/// Allows users to select and switch between different LLM providers
/// like Ollama, LM Studio, OpenAI-compatible APIs, etc.
class LLMProviderSelector extends StatefulWidget {
  final Function(String providerId)? onProviderChanged;
  final Function(String providerId, String modelName)? onModelSelected;
  final bool showStatus;
  final bool showModels;

  const LLMProviderSelector({
    super.key,
    this.onProviderChanged,
    this.onModelSelected,
    this.showStatus = true,
    this.showModels = false,
  });

  @override
  State<LLMProviderSelector> createState() => _LLMProviderSelectorState();
}

class _LLMProviderSelectorState extends State<LLMProviderSelector> {
  bool _isLoading = false;
  final Map<String, String> _selectedModels = {}; // providerId -> modelName

  @override
  void initState() {
    super.initState();
    _loadSelectedModels();
  }

  /// Load selected models from shared preferences
  Future<void> _loadSelectedModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('selected_model_'));

      for (final key in keys) {
        final providerId = key.replaceFirst('selected_model_', '');
        final modelName = prefs.getString(key);
        if (modelName != null) {
          _selectedModels[providerId] = modelName;
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading selected models: $e');
    }
  }

  /// Save selected model for a provider
  Future<void> _saveSelectedModel(String providerId, String modelName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model_$providerId', modelName);
      _selectedModels[providerId] = modelName;
    } catch (e) {
      debugPrint('Error saving selected model: $e');
    }
  }

  /// Handle model selection
  Future<void> _onModelSelected(String providerId, String modelName) async {
    setState(() {
      _selectedModels[providerId] = modelName;
    });

    // Save to persistent storage
    await _saveSelectedModel(providerId, modelName);

    // Notify parent widget if callback is provided
    widget.onModelSelected?.call(providerId, modelName);

    debugPrint('Selected model "$modelName" for provider: $providerId');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LLMProviderManager>(
      builder: (context, providerManager, child) {
        if (!providerManager.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider selection dropdown
            _buildProviderDropdown(providerManager),

            if (widget.showStatus) ...[
              SizedBox(height: AppTheme.spacingS),
              _buildProviderStatus(providerManager),
            ],

            if (widget.showModels &&
                providerManager.getPreferredProvider() != null) ...[
              SizedBox(height: AppTheme.spacingM),
              _buildModelSelectorFromProvider(
                  providerManager.getPreferredProvider()!),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProviderDropdown(LLMProviderManager providerManager) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('llm-provider-dropdown'),
          value: providerManager.preferredProviderId,
          isExpanded: true,
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          items: providerManager.availableProviders.map((provider) {
            return DropdownMenuItem<String>(
              value: provider.info.id,
              child: Row(
                children: [
                  _getProviderIcon(provider.info.id),
                  SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.info.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          provider.info.baseUrl,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textColorLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildRegisteredProviderStatusIcon(provider),
                ],
              ),
            );
          }).toList(),
          onChanged: _isLoading
              ? null
              : (String? value) {
                  if (value != null &&
                      value != providerManager.preferredProviderId) {
                    _switchProvider(providerManager, value);
                  }
                },
        ),
      ),
    );
  }

  Widget _buildProviderStatus(LLMProviderManager providerManager) {
    final activeProvider = providerManager.getPreferredProvider();
    if (activeProvider == null) {
      return Container(
        padding: EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 16, color: Colors.orange),
            SizedBox(width: AppTheme.spacingXS),
            Text(
              'No provider selected',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.warningColor),
            ),
          ],
        ),
      );
    }

    final isConnected = activeProvider.isEnabled;
    final isConnecting =
        activeProvider.healthStatus == ProviderHealthStatus.unknown;
    final hasError =
        activeProvider.healthStatus == ProviderHealthStatus.unhealthy;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isConnecting) {
      statusColor = Colors.blue;
      statusIcon = Icons.sync;
      statusText = 'Connecting...';
    } else if (hasError) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Error: Provider unhealthy';
    } else if (isConnected) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Connected';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.circle_outlined;
      statusText = 'Disconnected';
    }

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          SizedBox(width: AppTheme.spacingXS),
          Expanded(
            child: Text(
              statusText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: statusColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isConnected && !isConnecting)
            TextButton(
              onPressed: () => _reconnectProviderById(activeProvider.info.id),
              child: Text('Reconnect', style: TextStyle(color: statusColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildModelSelectorFromProvider(
      RegisteredProvider registeredProvider) {
    if (registeredProvider.info.availableModels.isEmpty) {
      return Container(
        padding: EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppTheme.textColorLight),
            SizedBox(width: AppTheme.spacingXS),
            Text(
              'No models available',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Models',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: AppTheme.spacingXS),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedModels[registeredProvider.info.id],
              isExpanded: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              items: registeredProvider.info.availableModels.map((modelName) {
                return DropdownMenuItem<String>(
                  value: modelName,
                  child: Text(modelName),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  _onModelSelected(registeredProvider.info.id, value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredProviderStatusIcon(RegisteredProvider provider) {
    switch (provider.healthStatus) {
      case ProviderHealthStatus.healthy:
        return Icon(Icons.check_circle, size: 16, color: Colors.green);
      case ProviderHealthStatus.degraded:
        return Icon(Icons.warning, size: 16, color: Colors.orange);
      case ProviderHealthStatus.unhealthy:
        return Icon(Icons.error, size: 16, color: Colors.red);
      case ProviderHealthStatus.unknown:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        );
    }
  }

  Widget _getProviderIcon(String providerId) {
    switch (providerId) {
      case 'ollama':
        return Icon(Icons.memory, color: AppTheme.primaryColor);
      case 'lmstudio':
        return Icon(Icons.desktop_windows, color: AppTheme.secondaryColor);
      default:
        return Icon(Icons.smart_toy, color: AppTheme.textColorLight);
    }
  }

  Future<void> _switchProvider(
    LLMProviderManager providerManager,
    String providerId,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      providerManager.setPreferredProvider(providerId);
      widget.onProviderChanged?.call(providerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to ${providerManager.getPreferredProvider()?.info.name}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch provider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reconnectProviderById(String providerId) async {
    if (!mounted) return;

    // Show loading state
    setState(() {
      _isLoading = true;
    });

    try {
      final providerManager =
          Provider.of<LLMProviderManager>(context, listen: false);

      // Show initial feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reconnecting provider...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      // Attempt reconnection
      final success = await providerManager.reconnectProvider(providerId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Provider reconnected successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reconnect provider'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reconnection error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
