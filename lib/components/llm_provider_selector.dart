import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/llm_provider_manager.dart';
import '../services/llm_providers/base_llm_provider.dart';

/// LLM Provider Selector Widget
///
/// Allows users to select and switch between different LLM providers
/// like Ollama, LM Studio, OpenAI-compatible APIs, etc.
class LLMProviderSelector extends StatefulWidget {
  final Function(String providerId)? onProviderChanged;
  final bool showStatus;
  final bool showModels;

  const LLMProviderSelector({
    super.key,
    this.onProviderChanged,
    this.showStatus = true,
    this.showModels = false,
  });

  @override
  State<LLMProviderSelector> createState() => _LLMProviderSelectorState();
}

class _LLMProviderSelectorState extends State<LLMProviderSelector> {
  bool _isLoading = false;

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
                providerManager.activeProvider != null) ...[
              SizedBox(height: AppTheme.spacingM),
              _buildModelSelector(providerManager.activeProvider!),
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
          value: providerManager.activeProviderId,
          isExpanded: true,
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          items: providerManager.availableProviders.map((provider) {
            return DropdownMenuItem<String>(
              value: provider.providerId,
              child: Row(
                children: [
                  _getProviderIcon(provider.providerId),
                  SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.providerName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          provider.providerDescription,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textColorLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildProviderStatusIcon(provider),
                ],
              ),
            );
          }).toList(),
          onChanged: _isLoading
              ? null
              : (String? value) {
                  if (value != null &&
                      value != providerManager.activeProviderId) {
                    _switchProvider(providerManager, value);
                  }
                },
        ),
      ),
    );
  }

  Widget _buildProviderStatus(LLMProviderManager providerManager) {
    final activeProvider = providerManager.activeProvider;
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

    final isConnected = activeProvider.isAvailable;
    final isConnecting = activeProvider.isConnecting;
    final hasError = activeProvider.lastError != null;

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
      statusText = 'Error: ${activeProvider.lastError}';
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
              onPressed: () => _reconnectProvider(activeProvider),
              child: Text('Reconnect', style: TextStyle(color: statusColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildModelSelector(BaseLLMProvider provider) {
    if (provider.availableModels.isEmpty) {
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
              value: provider.selectedModel?.id,
              isExpanded: true,
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              items: provider.availableModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model.id,
                  child: Text(model.name),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  provider.selectModel(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderStatusIcon(BaseLLMProvider provider) {
    if (provider.isConnecting) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    } else if (provider.isAvailable) {
      return Icon(Icons.check_circle, size: 16, color: Colors.green);
    } else if (provider.lastError != null) {
      return Icon(Icons.error, size: 16, color: Colors.red);
    } else {
      return Icon(Icons.circle_outlined, size: 16, color: Colors.grey);
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
      await providerManager.switchProvider(providerId);
      widget.onProviderChanged?.call(providerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to ${providerManager.activeProvider?.providerName}',
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

  Future<void> _reconnectProvider(BaseLLMProvider provider) async {
    try {
      await provider.connect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reconnected to ${provider.providerName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reconnect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
