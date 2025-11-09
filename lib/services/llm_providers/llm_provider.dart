import 'package:meta/meta.dart';

import '../auth_service.dart';
import 'base_llm_provider.dart';

/// Shared base class for concrete LLM providers.
///
/// Stores the Auth0-aware auth service reference and provider configuration,
/// exposing protected helpers for subclasses while keeping the public API
/// defined by [BaseLLMProvider].
abstract class LLMProvider extends BaseLLMProvider {
  LLMProvider({
    required LLMProviderConfig config,
    required this.authService,
  }) : _config = config;

  /// Auth service used for acquiring credentials when required by providers.
  final AuthService authService;

  LLMProviderConfig _config;

  /// Current provider configuration available to subclasses.
  @protected
  LLMProviderConfig get providerConfig => _config;

  @protected
  set providerConfig(LLMProviderConfig value) => _config = value;

  @override
  Map<String, dynamic> get configuration => _config.toJson();

  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    _config = LLMProviderConfig.fromJson(config);
  }

  @override
  bool validateConfiguration(Map<String, dynamic> config) {
    try {
      LLMProviderConfig.fromJson(config);
      return true;
    } catch (_) {
      return false;
    }
  }
}
