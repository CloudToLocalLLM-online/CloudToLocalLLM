/// Configuration model for the SSH tunnel connection.
class TunnelConfig {
  final String userId;
  final String cloudProxyUrl;
  final String localBackendUrl;
  final String authToken;
  final bool enableCloudProxy;
  final int? tunnelPort; // SSH server port (if different from cloudProxyUrl port)

  const TunnelConfig({
    required this.userId,
    required this.cloudProxyUrl,
    required this.localBackendUrl,
    required this.authToken,
    this.enableCloudProxy = true,
    this.tunnelPort,
  });
}
