import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/payment_transaction_model.dart';
import '../models/subscription_model.dart';
import '../models/refund_model.dart';
import 'auth_service.dart';

/// Payment Gateway Service for Admin Center
///
/// Provides payment processing functionality including:
/// - Payment transaction management
/// - Subscription creation and management
/// - Refund processing
/// - Payment method management
///
/// Features:
/// - Connects to admin API backend (/admin/payments)
/// - JWT authentication with admin role validation
/// - Comprehensive error handling and logging
/// - Real-time data updates
class PaymentGatewayService extends ChangeNotifier {
  final Dio _dio;
  final AuthService _authService;

  // Service state
  bool _isLoading = false;
  String? _error;

  // Cached data
  final List<PaymentTransactionModel> _transactions = [];
  final List<SubscriptionModel> _subscriptions = [];
  DateTime? _lastTransactionsUpdate;
  DateTime? _lastSubscriptionsUpdate;

  PaymentGatewayService({required AuthService authService})
      : _authService = authService,
        _dio = Dio() {
    _setupDio();
    _authService.addListener(_onAuthStateChanged);
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<PaymentTransactionModel> get transactions => _transactions;
  List<SubscriptionModel> get subscriptions => _subscriptions;

  void _setupDio() {
    _dio.options.baseUrl = AppConfig.adminApiBaseUrl;
    _dio.options.connectTimeout = AppConfig.adminApiTimeout;
    _dio.options.receiveTimeout = AppConfig.adminApiTimeout;

    // Add auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getValidatedAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          debugPrint('❌ [PaymentGatewayService] API Error: ${error.message}');
          if (error.response?.statusCode == 403) {
            _setError(
              'Admin access denied. Please ensure you have admin privileges.',
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  void _onAuthStateChanged() {
    if (!_authService.isAuthenticated.value) {
      _clearAllData();
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearAllData() {
    _transactions.clear();
    _subscriptions.clear();
    _lastTransactionsUpdate = null;
    _lastSubscriptionsUpdate = null;
  }

  /// Clear any previous error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============================================================================
  // Payment Processing Methods
  // ============================================================================

  /// Process a payment for a user
  Future<PaymentTransactionModel?> processPayment({
    required String userId,
    required double amount,
    String currency = 'USD',
    required String paymentMethodId,
  }) async {
    try {
      debugPrint(
          '💳 [PaymentGatewayService] Processing payment for user: $userId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.post(
        '/admin/payments/process',
        data: {
          'user_id': userId,
          'amount': amount,
          'currency': currency,
          'payment_method_id': paymentMethodId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final transaction = PaymentTransactionModel.fromJson(
          response.data['data'],
        );
        debugPrint('✅ [PaymentGatewayService] Payment processed successfully');
        return transaction;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to process payment',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to process payment: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get payment transactions with optional filtering
  Future<List<PaymentTransactionModel>> getTransactions({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int page = 1,
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _transactions.isNotEmpty &&
        _lastTransactionsUpdate != null &&
        DateTime.now().difference(_lastTransactionsUpdate!).inMinutes < 5) {
      return _transactions;
    }

    try {
      debugPrint('💳 [PaymentGatewayService] Fetching transactions');
      _setLoading(true);
      _setError(null);

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (userId != null) queryParams['user_id'] = userId;
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/admin/payments/transactions',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final transactionsList = response.data['data']['transactions'] as List;
        _transactions.clear();
        _transactions.addAll(
          transactionsList
              .map((json) => PaymentTransactionModel.fromJson(json))
              .toList(),
        );
        _lastTransactionsUpdate = DateTime.now();

        debugPrint(
          '✅ [PaymentGatewayService] Fetched ${_transactions.length} transactions',
        );
        notifyListeners();
        return _transactions;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch transactions',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch transactions: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get transaction details by ID
  Future<PaymentTransactionModel?> getTransactionDetails(
    String transactionId,
  ) async {
    try {
      debugPrint(
        '💳 [PaymentGatewayService] Fetching transaction details: $transactionId',
      );
      _setLoading(true);
      _setError(null);

      final response = await _dio.get(
        '/admin/payments/transactions/$transactionId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final transaction = PaymentTransactionModel.fromJson(
          response.data['data'],
        );
        debugPrint('✅ [PaymentGatewayService] Transaction details fetched');
        return transaction;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch transaction details',
        );
      }
    } catch (e) {
      final errorMessage =
          'Failed to fetch transaction details: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // Subscription Management Methods
  // ============================================================================

  /// Create a new subscription for a user
  Future<SubscriptionModel?> createSubscription({
    required String userId,
    required String priceId,
    required String paymentMethodId,
  }) async {
    try {
      debugPrint(
        '📋 [PaymentGatewayService] Creating subscription for user: $userId',
      );
      _setLoading(true);
      _setError(null);

      final response = await _dio.post(
        '/admin/subscriptions',
        data: {
          'user_id': userId,
          'price_id': priceId,
          'payment_method_id': paymentMethodId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final subscription = SubscriptionModel.fromJson(
          response.data['data'],
        );
        debugPrint(
            '✅ [PaymentGatewayService] Subscription created successfully');
        return subscription;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to create subscription',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to create subscription: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing subscription
  Future<SubscriptionModel?> updateSubscription({
    required String subscriptionId,
    required String newPriceId,
  }) async {
    try {
      debugPrint(
        '📋 [PaymentGatewayService] Updating subscription: $subscriptionId',
      );
      _setLoading(true);
      _setError(null);

      final response = await _dio.patch(
        '/admin/subscriptions/$subscriptionId',
        data: {
          'price_id': newPriceId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final subscription = SubscriptionModel.fromJson(
          response.data['data'],
        );
        debugPrint(
            '✅ [PaymentGatewayService] Subscription updated successfully');
        return subscription;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to update subscription',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to update subscription: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel a subscription
  Future<SubscriptionModel?> cancelSubscription({
    required String subscriptionId,
    bool immediate = false,
  }) async {
    try {
      debugPrint(
        '📋 [PaymentGatewayService] Canceling subscription: $subscriptionId',
      );
      _setLoading(true);
      _setError(null);

      final response = await _dio.post(
        '/admin/subscriptions/$subscriptionId/cancel',
        data: {
          'immediate': immediate,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final subscription = SubscriptionModel.fromJson(
          response.data['data'],
        );
        debugPrint(
            '✅ [PaymentGatewayService] Subscription canceled successfully');
        return subscription;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to cancel subscription',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to cancel subscription: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get subscriptions with optional filtering
  Future<List<SubscriptionModel>> getSubscriptions({
    String? userId,
    String? tier,
    String? status,
    int page = 1,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _subscriptions.isNotEmpty &&
        _lastSubscriptionsUpdate != null &&
        DateTime.now().difference(_lastSubscriptionsUpdate!).inMinutes < 5) {
      return _subscriptions;
    }

    try {
      debugPrint('📋 [PaymentGatewayService] Fetching subscriptions');
      _setLoading(true);
      _setError(null);

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (userId != null) queryParams['user_id'] = userId;
      if (tier != null) queryParams['tier'] = tier;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/admin/subscriptions',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final subscriptionsList =
            response.data['data']['subscriptions'] as List;
        _subscriptions.clear();
        _subscriptions.addAll(
          subscriptionsList
              .map((json) => SubscriptionModel.fromJson(json))
              .toList(),
        );
        _lastSubscriptionsUpdate = DateTime.now();

        debugPrint(
          '✅ [PaymentGatewayService] Fetched ${_subscriptions.length} subscriptions',
        );
        notifyListeners();
        return _subscriptions;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch subscriptions',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch subscriptions: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get subscription details by ID
  Future<SubscriptionModel?> getSubscriptionDetails(
    String subscriptionId,
  ) async {
    try {
      debugPrint(
        '📋 [PaymentGatewayService] Fetching subscription details: $subscriptionId',
      );
      _setLoading(true);
      _setError(null);

      final response = await _dio.get(
        '/admin/subscriptions/$subscriptionId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final subscription = SubscriptionModel.fromJson(
          response.data['data'],
        );
        debugPrint('✅ [PaymentGatewayService] Subscription details fetched');
        return subscription;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch subscription details',
        );
      }
    } catch (e) {
      final errorMessage =
          'Failed to fetch subscription details: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // Refund Processing Methods
  // ============================================================================

  /// Process a refund for a transaction
  Future<RefundModel?> processRefund({
    required String transactionId,
    double? amount,
    required RefundReason reason,
    String? reasonDetails,
  }) async {
    // Validate refund reason
    if (!_isValidRefundReason(reason)) {
      _setError('Invalid refund reason');
      return null;
    }

    try {
      debugPrint(
        '💰 [PaymentGatewayService] Processing refund for transaction: $transactionId',
      );
      _setLoading(true);
      _setError(null);

      final requestData = <String, dynamic>{
        'transaction_id': transactionId,
        'reason': reason.value,
      };

      if (amount != null) {
        requestData['amount'] = amount;
      }
      if (reasonDetails != null && reasonDetails.isNotEmpty) {
        requestData['reason_details'] = reasonDetails;
      }

      final response = await _dio.post(
        '/admin/payments/refunds',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final refund = RefundModel.fromJson(response.data['data']);
        debugPrint('✅ [PaymentGatewayService] Refund processed successfully');
        return refund;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to process refund',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to process refund: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Validate refund reason
  bool _isValidRefundReason(RefundReason reason) {
    final validReasons = [
      RefundReason.customerRequest,
      RefundReason.billingError,
      RefundReason.serviceIssue,
      RefundReason.duplicate,
      RefundReason.fraudulent,
      RefundReason.other,
    ];
    return validReasons.contains(reason);
  }

  /// Get refunds for a transaction
  Future<List<RefundModel>> getRefundsForTransaction(
    String transactionId,
  ) async {
    try {
      debugPrint(
        '💰 [PaymentGatewayService] Fetching refunds for transaction: $transactionId',
      );
      _setLoading(true);
      _setError(null);

      final response = await _dio.get(
        '/admin/payments/transactions/$transactionId/refunds',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final refundsList = response.data['data']['refunds'] as List;
        final refunds =
            refundsList.map((json) => RefundModel.fromJson(json)).toList();

        debugPrint(
          '✅ [PaymentGatewayService] Fetched ${refunds.length} refunds',
        );
        return refunds;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch refunds',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch refunds: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get payment methods for a user
  Future<List<Map<String, dynamic>>> getPaymentMethods(String userId) async {
    try {
      debugPrint(
        '💳 [PaymentGatewayService] Fetching payment methods for user: $userId',
      );
      _setLoading(true);
      _setError(null);

      final response = await _dio.get(
        '/admin/payments/methods/$userId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final methodsList = response.data['data']['payment_methods'] as List;
        final methods = List<Map<String, dynamic>>.from(methodsList);

        debugPrint(
          '✅ [PaymentGatewayService] Fetched ${methods.length} payment methods',
        );
        return methods;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch payment methods',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch payment methods: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [PaymentGatewayService] $errorMessage');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _dio.close();
    super.dispose();
  }
}
