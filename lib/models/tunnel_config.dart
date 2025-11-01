/// Configuration model for the Chisel tunnel connection.
class TunnelConfig {
  final String userId;
  final String cloudProxyUrl;
  final String localBackendUrl;
  final String authToken;
  final bool enableCloudProxy;
  final int? chiselPort; // Chisel server port (if different from cloudProxyUrl port)

  const TunnelConfig({
    required this.userId,
    required this.cloudProxyUrl,
    required this.localBackendUrl,
    required this.authToken,
    this.enableCloudProxy = true,
    this.chiselPort,
  });
}
