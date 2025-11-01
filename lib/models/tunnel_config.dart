import '../config/app_config.dart';

/// Configuration model for the WebSocket tunnel connection.
class TunnelConfig {
  final String userId;
  final String cloudProxyUrl;
  final String localBackendUrl;
  final String authToken;
  final bool enableCloudProxy;

  const TunnelConfig({
    required this.userId,
    required this.cloudProxyUrl,
    required this.localBackendUrl,
    required this.authToken,
    this.enableCloudProxy = true,
  });
}
