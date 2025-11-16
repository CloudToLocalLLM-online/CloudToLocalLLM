/// Subscription model for Admin Center
/// Represents a user's subscription tier and billing information
class SubscriptionModel {
  final String id;
  final String userId;
  final String? stripeSubscriptionId;
  final String? stripeCustomerId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? canceledAt;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const SubscriptionModel({
    required this.id,
    required this.userId,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    required this.tier,
    required this.status,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.canceledAt,
    this.trialStart,
    this.trialEnd,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  /// Create SubscriptionModel from JSON
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      stripeSubscriptionId:
          json['stripe_subscription_id'] ?? json['stripeSubscriptionId'],
      stripeCustomerId: json['stripe_customer_id'] ?? json['stripeCustomerId'],
      tier: _parseTier(json['tier']),
      status: _parseStatus(json['status']),
      currentPeriodStart: json['current_period_start'] != null
          ? DateTime.tryParse(json['current_period_start'])
          : (json['currentPeriodStart'] != null
              ? DateTime.tryParse(json['currentPeriodStart'])
              : null),
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'])
          : (json['currentPeriodEnd'] != null
              ? DateTime.tryParse(json['currentPeriodEnd'])
              : null),
      cancelAtPeriodEnd:
          json['cancel_at_period_end'] ?? json['cancelAtPeriodEnd'] ?? false,
      canceledAt: json['canceled_at'] != null
          ? DateTime.tryParse(json['canceled_at'])
          : (json['canceledAt'] != null
              ? DateTime.tryParse(json['canceledAt'])
              : null),
      trialStart: json['trial_start'] != null
          ? DateTime.tryParse(json['trial_start'])
          : (json['trialStart'] != null
              ? DateTime.tryParse(json['trialStart'])
              : null),
      trialEnd: json['trial_end'] != null
          ? DateTime.tryParse(json['trial_end'])
          : (json['trialEnd'] != null
              ? DateTime.tryParse(json['trialEnd'])
              : null),
      createdAt:
          DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ??
              DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert SubscriptionModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'stripe_subscription_id': stripeSubscriptionId,
      'stripe_customer_id': stripeCustomerId,
      'tier': tier.value,
      'status': status.value,
      'current_period_start': currentPeriodStart?.toIso8601String(),
      'current_period_end': currentPeriodEnd?.toIso8601String(),
      'cancel_at_period_end': cancelAtPeriodEnd,
      'canceled_at': canceledAt?.toIso8601String(),
      'trial_start': trialStart?.toIso8601String(),
      'trial_end': trialEnd?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Parse tier from string
  static SubscriptionTier _parseTier(dynamic value) {
    if (value == null) return SubscriptionTier.free;
    final tierStr = value.toString().toLowerCase();
    return SubscriptionTier.values.firstWhere(
      (t) => t.value == tierStr,
      orElse: () => SubscriptionTier.free,
    );
  }

  /// Parse status from string
  static SubscriptionStatus _parseStatus(dynamic value) {
    if (value == null) return SubscriptionStatus.active;
    final statusStr = value.toString().toLowerCase();
    return SubscriptionStatus.values.firstWhere(
      (s) => s.value == statusStr,
      orElse: () => SubscriptionStatus.active,
    );
  }

  /// Check if subscription is active
  bool get isActive => status == SubscriptionStatus.active;

  /// Check if subscription is in trial
  bool get isTrialing => status == SubscriptionStatus.trialing;

  /// Check if subscription is canceled
  bool get isCanceled => status == SubscriptionStatus.canceled;

  /// Check if subscription is past due
  bool get isPastDue => status == SubscriptionStatus.pastDue;

  /// Get days remaining in current period
  int? get daysRemaining {
    if (currentPeriodEnd == null) return null;
    final now = DateTime.now();
    if (currentPeriodEnd!.isBefore(now)) return 0;
    return currentPeriodEnd!.difference(now).inDays;
  }

  /// Copy with method for immutable updates
  SubscriptionModel copyWith({
    String? id,
    String? userId,
    String? stripeSubscriptionId,
    String? stripeCustomerId,
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    bool? cancelAtPeriodEnd,
    DateTime? canceledAt,
    DateTime? trialStart,
    DateTime? trialEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      canceledAt: canceledAt ?? this.canceledAt,
      trialStart: trialStart ?? this.trialStart,
      trialEnd: trialEnd ?? this.trialEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubscriptionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SubscriptionModel(id: $id, userId: $userId, tier: ${tier.value}, status: ${status.value})';
  }
}

/// Subscription tier enum
enum SubscriptionTier {
  free('free'),
  premium('premium'),
  enterprise('enterprise');

  final String value;
  const SubscriptionTier(this.value);

  /// Get display name for tier
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.enterprise:
        return 'Enterprise';
    }
  }

  /// Get tier from string value
  static SubscriptionTier fromString(String value) {
    return SubscriptionTier.values.firstWhere(
      (tier) => tier.value == value.toLowerCase(),
      orElse: () => SubscriptionTier.free,
    );
  }
}

/// Subscription status enum
enum SubscriptionStatus {
  active('active'),
  canceled('canceled'),
  pastDue('past_due'),
  trialing('trialing'),
  incomplete('incomplete');

  final String value;
  const SubscriptionStatus(this.value);

  /// Get display name for status
  String get displayName {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.canceled:
        return 'Canceled';
      case SubscriptionStatus.pastDue:
        return 'Past Due';
      case SubscriptionStatus.trialing:
        return 'Trialing';
      case SubscriptionStatus.incomplete:
        return 'Incomplete';
    }
  }

  /// Get status from string value
  static SubscriptionStatus fromString(String value) {
    return SubscriptionStatus.values.firstWhere(
      (status) => status.value == value.toLowerCase(),
      orElse: () => SubscriptionStatus.active,
    );
  }

  /// Check if status indicates an issue
  bool get hasIssue =>
      this == SubscriptionStatus.pastDue ||
      this == SubscriptionStatus.incomplete;
}
