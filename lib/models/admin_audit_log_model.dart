/// Admin audit log model for Admin Center
/// Represents an audit log entry for administrative actions
class AdminAuditLogModel {
  final String id;
  final String adminUserId;
  final String adminRole;
  final String action;
  final String resourceType;
  final String resourceId;
  final String? affectedUserId;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  const AdminAuditLogModel({
    required this.id,
    required this.adminUserId,
    required this.adminRole,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    this.affectedUserId,
    this.details,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  /// Create AdminAuditLogModel from JSON
  factory AdminAuditLogModel.fromJson(Map<String, dynamic> json) {
    return AdminAuditLogModel(
      id: json['id'] ?? '',
      adminUserId: json['admin_user_id'] ?? json['adminUserId'] ?? '',
      adminRole: json['admin_role'] ?? json['adminRole'] ?? '',
      action: json['action'] ?? '',
      resourceType: json['resource_type'] ?? json['resourceType'] ?? '',
      resourceId: json['resource_id'] ?? json['resourceId'] ?? '',
      affectedUserId: json['affected_user_id'] ?? json['affectedUserId'],
      details: json['details'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] ?? json['ipAddress'],
      userAgent: json['user_agent'] ?? json['userAgent'],
      createdAt:
          DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ??
              DateTime.now(),
    );
  }

  /// Convert AdminAuditLogModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_user_id': adminUserId,
      'admin_role': adminRole,
      'action': action,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'affected_user_id': affectedUserId,
      'details': details,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get action category
  String get actionCategory {
    if (action.contains('user')) return 'User Management';
    if (action.contains('payment') || action.contains('refund')) {
      return 'Payment Management';
    }
    if (action.contains('subscription')) return 'Subscription Management';
    if (action.contains('admin')) return 'Admin Management';
    if (action.contains('report')) return 'Reporting';
    if (action.contains('configuration')) return 'Configuration';
    return 'Other';
  }

  /// Get action severity
  AuditLogSeverity get severity {
    // High severity actions
    if (action.contains('delete') ||
        action.contains('suspend') ||
        action.contains('revoke') ||
        action.contains('refund')) {
      return AuditLogSeverity.high;
    }

    // Medium severity actions
    if (action.contains('update') ||
        action.contains('edit') ||
        action.contains('create') ||
        action.contains('assign')) {
      return AuditLogSeverity.medium;
    }

    // Low severity actions (view, export, etc.)
    return AuditLogSeverity.low;
  }

  /// Get formatted action display name
  String get actionDisplayName {
    return action
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get formatted resource type display name
  String get resourceTypeDisplayName {
    return resourceType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  /// Get browser name from user agent
  String? get browserName {
    if (userAgent == null) return null;

    if (userAgent!.contains('Chrome')) return 'Chrome';
    if (userAgent!.contains('Firefox')) return 'Firefox';
    if (userAgent!.contains('Safari')) return 'Safari';
    if (userAgent!.contains('Edge')) return 'Edge';
    if (userAgent!.contains('Opera')) return 'Opera';

    return 'Unknown';
  }

  /// Get operating system from user agent
  String? get operatingSystem {
    if (userAgent == null) return null;

    if (userAgent!.contains('Windows')) return 'Windows';
    if (userAgent!.contains('Mac OS')) return 'macOS';
    if (userAgent!.contains('Linux')) return 'Linux';
    if (userAgent!.contains('Android')) return 'Android';
    if (userAgent!.contains('iOS')) return 'iOS';

    return 'Unknown';
  }

  /// Copy with method for immutable updates
  AdminAuditLogModel copyWith({
    String? id,
    String? adminUserId,
    String? adminRole,
    String? action,
    String? resourceType,
    String? resourceId,
    String? affectedUserId,
    Map<String, dynamic>? details,
    String? ipAddress,
    String? userAgent,
    DateTime? createdAt,
  }) {
    return AdminAuditLogModel(
      id: id ?? this.id,
      adminUserId: adminUserId ?? this.adminUserId,
      adminRole: adminRole ?? this.adminRole,
      action: action ?? this.action,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      affectedUserId: affectedUserId ?? this.affectedUserId,
      details: details ?? this.details,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminAuditLogModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AdminAuditLogModel(id: $id, action: $action, resourceType: $resourceType, adminUserId: $adminUserId)';
  }
}

/// Audit log severity enum
enum AuditLogSeverity {
  low('low'),
  medium('medium'),
  high('high');

  final String value;
  const AuditLogSeverity(this.value);

  /// Get display name for severity
  String get displayName {
    switch (this) {
      case AuditLogSeverity.low:
        return 'Low';
      case AuditLogSeverity.medium:
        return 'Medium';
      case AuditLogSeverity.high:
        return 'High';
    }
  }

  /// Get severity from string value
  static AuditLogSeverity fromString(String value) {
    return AuditLogSeverity.values.firstWhere(
      (severity) => severity.value == value.toLowerCase(),
      orElse: () => AuditLogSeverity.low,
    );
  }

  /// Get color for severity (for UI display)
  String get colorHex {
    switch (this) {
      case AuditLogSeverity.low:
        return '#4CAF50'; // Green
      case AuditLogSeverity.medium:
        return '#FF9800'; // Orange
      case AuditLogSeverity.high:
        return '#F44336'; // Red
    }
  }
}
