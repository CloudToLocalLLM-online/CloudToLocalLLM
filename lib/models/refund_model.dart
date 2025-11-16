/// Refund model for Admin Center
/// Represents a refund for a payment transaction
class RefundModel {
  final String id;
  final String transactionId;
  final String stripeRefundId;
  final double amount;
  final String currency;
  final RefundReason reason;
  final String? reasonDetails;
  final RefundStatus status;
  final String? failureReason;
  final String? adminUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const RefundModel({
    required this.id,
    required this.transactionId,
    required this.stripeRefundId,
    required this.amount,
    required this.currency,
    required this.reason,
    this.reasonDetails,
    required this.status,
    this.failureReason,
    this.adminUserId,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  /// Create RefundModel from JSON
  factory RefundModel.fromJson(Map<String, dynamic> json) {
    return RefundModel(
      id: json['id'] ?? '',
      transactionId: json['transaction_id'] ?? json['transactionId'] ?? '',
      stripeRefundId: json['stripe_refund_id'] ?? json['stripeRefundId'] ?? '',
      amount: _parseAmount(json['amount']),
      currency: json['currency'] ?? 'USD',
      reason: _parseReason(json['reason']),
      reasonDetails: json['reason_details'] ?? json['reasonDetails'],
      status: _parseStatus(json['status']),
      failureReason: json['failure_reason'] ?? json['failureReason'],
      adminUserId: json['admin_user_id'] ?? json['adminUserId'],
      createdAt:
          DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ??
              DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert RefundModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'stripe_refund_id': stripeRefundId,
      'amount': amount,
      'currency': currency,
      'reason': reason.value,
      'reason_details': reasonDetails,
      'status': status.value,
      'failure_reason': failureReason,
      'admin_user_id': adminUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Parse amount from dynamic value
  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Parse reason from string
  static RefundReason _parseReason(dynamic value) {
    if (value == null) return RefundReason.other;
    final reasonStr = value.toString().toLowerCase();
    return RefundReason.values.firstWhere(
      (r) => r.value == reasonStr,
      orElse: () => RefundReason.other,
    );
  }

  /// Parse status from string
  static RefundStatus _parseStatus(dynamic value) {
    if (value == null) return RefundStatus.pending;
    final statusStr = value.toString().toLowerCase();
    return RefundStatus.values.firstWhere(
      (s) => s.value == statusStr,
      orElse: () => RefundStatus.pending,
    );
  }

  /// Check if refund was successful
  bool get isSuccessful => status == RefundStatus.succeeded;

  /// Check if refund failed
  bool get isFailed => status == RefundStatus.failed;

  /// Check if refund is pending
  bool get isPending => status == RefundStatus.pending;

  /// Check if refund was canceled
  bool get isCanceled => status == RefundStatus.canceled;

  /// Get formatted amount with currency
  String get formattedAmount {
    final currencySymbol = _getCurrencySymbol(currency);
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }

  /// Get currency symbol
  static String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency.toUpperCase();
    }
  }

  /// Copy with method for immutable updates
  RefundModel copyWith({
    String? id,
    String? transactionId,
    String? stripeRefundId,
    double? amount,
    String? currency,
    RefundReason? reason,
    String? reasonDetails,
    RefundStatus? status,
    String? failureReason,
    String? adminUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return RefundModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      stripeRefundId: stripeRefundId ?? this.stripeRefundId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      reason: reason ?? this.reason,
      reasonDetails: reasonDetails ?? this.reasonDetails,
      status: status ?? this.status,
      failureReason: failureReason ?? this.failureReason,
      adminUserId: adminUserId ?? this.adminUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RefundModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RefundModel(id: $id, amount: $formattedAmount, status: ${status.value}, reason: ${reason.value})';
  }
}

/// Refund reason enum
enum RefundReason {
  customerRequest('customer_request'),
  billingError('billing_error'),
  serviceIssue('service_issue'),
  duplicate('duplicate'),
  fraudulent('fraudulent'),
  other('other');

  final String value;
  const RefundReason(this.value);

  /// Get display name for reason
  String get displayName {
    switch (this) {
      case RefundReason.customerRequest:
        return 'Customer Request';
      case RefundReason.billingError:
        return 'Billing Error';
      case RefundReason.serviceIssue:
        return 'Service Issue';
      case RefundReason.duplicate:
        return 'Duplicate';
      case RefundReason.fraudulent:
        return 'Fraudulent';
      case RefundReason.other:
        return 'Other';
    }
  }

  /// Get reason from string value
  static RefundReason fromString(String value) {
    return RefundReason.values.firstWhere(
      (reason) => reason.value == value.toLowerCase(),
      orElse: () => RefundReason.other,
    );
  }
}

/// Refund status enum
enum RefundStatus {
  pending('pending'),
  succeeded('succeeded'),
  failed('failed'),
  canceled('canceled');

  final String value;
  const RefundStatus(this.value);

  /// Get display name for status
  String get displayName {
    switch (this) {
      case RefundStatus.pending:
        return 'Pending';
      case RefundStatus.succeeded:
        return 'Succeeded';
      case RefundStatus.failed:
        return 'Failed';
      case RefundStatus.canceled:
        return 'Canceled';
    }
  }

  /// Get status from string value
  static RefundStatus fromString(String value) {
    return RefundStatus.values.firstWhere(
      (status) => status.value == value.toLowerCase(),
      orElse: () => RefundStatus.pending,
    );
  }

  /// Check if status indicates success
  bool get isSuccess => this == RefundStatus.succeeded;

  /// Check if status indicates failure
  bool get isFailure => this == RefundStatus.failed;
}
