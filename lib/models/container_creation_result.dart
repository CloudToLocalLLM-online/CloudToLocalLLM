/// Container creation result model for tracking container provisioning status
///
/// This model encapsulates the result of container creation operations,
/// including success/failure status, container metadata, and error information.
/// Used by the UserContainerService to communicate container creation outcomes.
class ContainerCreationResult {
  final bool success;
  final String? containerId;
  final String? proxyId;
  final String? errorMessage;
  final String? errorCode;
  final Map<String, dynamic> containerInfo;
  final DateTime createdAt;

  const ContainerCreationResult({
    required this.success,
    this.containerId,
    this.proxyId,
    this.errorMessage,
    this.errorCode,
    this.containerInfo = const {},
    required this.createdAt,
  });

  /// Create a successful container creation result
  factory ContainerCreationResult.success({
    required String containerId,
    required String proxyId,
    Map<String, dynamic> containerInfo = const {},
  }) {
    return ContainerCreationResult(
      success: true,
      containerId: containerId,
      proxyId: proxyId,
      containerInfo: containerInfo,
      createdAt: DateTime.now(),
    );
  }

  /// Create a failed container creation result
  factory ContainerCreationResult.failure({
    required String errorMessage,
    String? errorCode,
    Map<String, dynamic> containerInfo = const {},
  }) {
    return ContainerCreationResult(
      success: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
      containerInfo: containerInfo,
      createdAt: DateTime.now(),
    );
  }

  /// Create ContainerCreationResult from JSON
  factory ContainerCreationResult.fromJson(Map<String, dynamic> json) {
    return ContainerCreationResult(
      success: json['success'] as bool,
      containerId: json['containerId'] as String?,
      proxyId: json['proxyId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      errorCode: json['errorCode'] as String?,
      containerInfo: Map<String, dynamic>.from(json['containerInfo'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert ContainerCreationResult to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (containerId != null) 'containerId': containerId,
      if (proxyId != null) 'proxyId': proxyId,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (errorCode != null) 'errorCode': errorCode,
      'containerInfo': containerInfo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Check if the container creation was successful
  bool get isSuccess => success;

  /// Check if the container creation failed
  bool get isFailure => !success;

  /// Get a user-friendly status message
  String get statusMessage {
    if (success) {
      return 'Container created successfully';
    } else {
      return errorMessage ?? 'Container creation failed';
    }
  }

  /// Get container health status from container info
  String? get healthStatus {
    return containerInfo['health'] as String?;
  }

  /// Get container status from container info
  String? get containerStatus {
    return containerInfo['status'] as String?;
  }

  /// Copy with method for immutable updates
  ContainerCreationResult copyWith({
    bool? success,
    String? containerId,
    String? proxyId,
    String? errorMessage,
    String? errorCode,
    Map<String, dynamic>? containerInfo,
    DateTime? createdAt,
  }) {
    return ContainerCreationResult(
      success: success ?? this.success,
      containerId: containerId ?? this.containerId,
      proxyId: proxyId ?? this.proxyId,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
      containerInfo: containerInfo ?? this.containerInfo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContainerCreationResult &&
        other.success == success &&
        other.containerId == containerId &&
        other.proxyId == proxyId &&
        other.errorMessage == errorMessage &&
        other.errorCode == errorCode;
  }

  @override
  int get hashCode {
    return Object.hash(success, containerId, proxyId, errorMessage, errorCode);
  }

  @override
  String toString() {
    return 'ContainerCreationResult('
        'success: $success, '
        'containerId: $containerId, '
        'proxyId: $proxyId, '
        'errorMessage: $errorMessage, '
        'errorCode: $errorCode'
        ')';
  }
}
