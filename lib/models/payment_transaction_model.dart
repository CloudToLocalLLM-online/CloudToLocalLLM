/// Payment transaction model for Admin Center
/// Represents a payment transaction with Stripe
class PaymentTransactionModel {
  final String id;
  final String userId;
  final String? subscriptionId;
  final String? stripePaymentIntentId;
  final String? stripeChargeId;
  final double amount;
  final String currency;
  final TransactionStatus status;
  final String? paymentMethodType;
  final String? paymentMethodLast4;
  final String? failureCode;
  final String? failureMessage;
  final String? receiptUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const PaymentTransactionModel({
    required this.id,
    required this.userId,
    this.subscriptionId,
    this.stripePaymentIntentId,
    this.stripeChargeId,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentMethodType,
    this.paymentMethodLast4,
    this.failureCode,
    this.failureMessage,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  /// Create PaymentTransactionModel from JSON
  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      subscriptionId: json['subscription_id'] ?? json['subscriptionId'],
      stripePaymentIntentId:
          json['stripe_payment_intent_id'] ?? json['stripePaymentIntentId'],
      stripeChargeId: json['stripe_charge_id'] ?? json['stripeChargeId'],
      amount: _parseAmount(json['amount']),
      currency: json['currency'] ?? 'USD',
      status: _parseStatus(json['status']),
      paymentMethodType:
          json['payment_method_type'] ?? json['paymentMethodType'],
      paymentMethodLast4:
          json['payment_method_last4'] ?? json['paymentMethodLast4'],
      failureCode: json['failure_code'] ?? json['failureCode'],
      failureMessage: json['failure_message'] ?? json['failureMessage'],
      receiptUrl: json['receipt_url'] ?? json['receiptUrl'],
      createdAt:
          DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ??
              DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert PaymentTransactionModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subscription_id': subscriptionId,
      'stripe_payment_intent_id': stripePaymentIntentId,
      'stripe_charge_id': stripeChargeId,
      'amount': amount,
      'currency': currency,
      'status': status.value,
      'payment_method_type': paymentMethodType,
      'payment_method_last4': paymentMethodLast4,
      'failure_code': failureCode,
      'failure_message': failureMessage,
      'receipt_url': receiptUrl,
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

  /// Parse status from string
  static TransactionStatus _parseStatus(dynamic value) {
    if (value == null) return TransactionStatus.pending;
    final statusStr = value.toString().toLowerCase();
    return TransactionStatus.values.firstWhere(
      (s) => s.value == statusStr,
      orElse: () => TransactionStatus.pending,
    );
  }

  /// Check if transaction was successful
  bool get isSuccessful => status == TransactionStatus.succeeded;

  /// Check if transaction failed
  bool get isFailed => status == TransactionStatus.failed;

  /// Check if transaction is pending
  bool get isPending => status == TransactionStatus.pending;

  /// Check if transaction was refunded
  bool get isRefunded =>
      status == TransactionStatus.refunded ||
      status == TransactionStatus.partiallyRefunded;

  /// Check if transaction is disputed
  bool get isDisputed => status == TransactionStatus.disputed;

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
  PaymentTransactionModel copyWith({
    String? id,
    String? userId,
    String? subscriptionId,
    String? stripePaymentIntentId,
    String? stripeChargeId,
    double? amount,
    String? currency,
    TransactionStatus? status,
    String? paymentMethodType,
    String? paymentMethodLast4,
    String? failureCode,
    String? failureMessage,
    String? receiptUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      stripePaymentIntentId:
          stripePaymentIntentId ?? this.stripePaymentIntentId,
      stripeChargeId: stripeChargeId ?? this.stripeChargeId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethodType: paymentMethodType ?? this.paymentMethodType,
      paymentMethodLast4: paymentMethodLast4 ?? this.paymentMethodLast4,
      failureCode: failureCode ?? this.failureCode,
      failureMessage: failureMessage ?? this.failureMessage,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentTransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PaymentTransactionModel(id: $id, amount: $formattedAmount, status: ${status.value})';
  }
}

/// Transaction status enum
enum TransactionStatus {
  pending('pending'),
  succeeded('succeeded'),
  failed('failed'),
  refunded('refunded'),
  partiallyRefunded('partially_refunded'),
  disputed('disputed');

  final String value;
  const TransactionStatus(this.value);

  /// Get display name for status
  String get displayName {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.succeeded:
        return 'Succeeded';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.refunded:
        return 'Refunded';
      case TransactionStatus.partiallyRefunded:
        return 'Partially Refunded';
      case TransactionStatus.disputed:
        return 'Disputed';
    }
  }

  /// Get status from string value
  static TransactionStatus fromString(String value) {
    return TransactionStatus.values.firstWhere(
      (status) => status.value == value.toLowerCase(),
      orElse: () => TransactionStatus.pending,
    );
  }

  /// Check if status indicates success
  bool get isSuccess => this == TransactionStatus.succeeded;

  /// Check if status indicates failure
  bool get isFailure => this == TransactionStatus.failed;

  /// Check if status indicates refund
  bool get isRefund =>
      this == TransactionStatus.refunded ||
      this == TransactionStatus.partiallyRefunded;
}
