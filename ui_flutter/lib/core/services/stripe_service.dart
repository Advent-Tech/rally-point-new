import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';
import '../network/api_client.dart';
import '../constants/api_constants.dart';

class StripeService {
  static StripeService? _instance;
  ApiClient? _apiClient;
  bool _isInitialized = false;

  StripeService._();

  static Future<StripeService> getInstance() async {
    if (_instance == null) {
      _instance = StripeService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    _apiClient = await ApiClient.getInstance();

    // Initialize Stripe with publishable key
    // This should be fetched from backend or environment config
    Stripe.publishableKey = const String.fromEnvironment(
      'STRIPE_PUBLISHABLE_KEY',
      defaultValue: 'pk_test_placeholder', // Replace with actual test key
    );

    try {
      await Stripe.instance.applySettings();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Stripe: $e');
    }
  }

  /// Process a card payment for a donation
  /// Returns the payment intent ID on success, null on failure
  Future<PaymentResult> processCardPayment({
    required double amountInCents,
    required String recipientName,
    String? email,
    String? description,
  }) async {
    try {
      // 1. Create PaymentIntent on the backend
      final response = await _apiClient!.post(
        ApiConstants.createPaymentIntent,
        data: {
          'amount': amountInCents.toInt(),
          'currency': 'usd',
          'description': description ?? 'Donation from $recipientName',
          'metadata': {
            'donor_name': recipientName,
            if (email != null) 'donor_email': email,
          },
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return PaymentResult.failure('Failed to create payment intent');
      }

      final clientSecret = response.data['client_secret'] as String;
      final paymentIntentId = response.data['payment_intent_id'] as String;

      // 2. Present the payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Rally Point',
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            name: recipientName,
            email: email,
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // 3. Payment successful
      return PaymentResult.success(paymentIntentId);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return PaymentResult.cancelled();
      }
      return PaymentResult.failure(e.error.localizedMessage ?? 'Payment failed');
    } catch (e) {
      return PaymentResult.failure(e.toString());
    }
  }

  /// Confirm a payment was successful (for verification)
  Future<bool> verifyPayment(String paymentIntentId) async {
    try {
      final response = await _apiClient!.get(
        '${ApiConstants.verifyPayment}/$paymentIntentId',
      );

      if (response.statusCode == 200) {
        return response.data['status'] == 'succeeded';
      }
      return false;
    } catch (e) {
      debugPrint('Failed to verify payment: $e');
      return false;
    }
  }
}

/// Result of a payment operation
class PaymentResult {
  final PaymentStatus status;
  final String? paymentIntentId;
  final String? errorMessage;

  PaymentResult._({
    required this.status,
    this.paymentIntentId,
    this.errorMessage,
  });

  factory PaymentResult.success(String paymentIntentId) {
    return PaymentResult._(
      status: PaymentStatus.success,
      paymentIntentId: paymentIntentId,
    );
  }

  factory PaymentResult.failure(String message) {
    return PaymentResult._(
      status: PaymentStatus.failed,
      errorMessage: message,
    );
  }

  factory PaymentResult.cancelled() {
    return PaymentResult._(
      status: PaymentStatus.cancelled,
    );
  }

  bool get isSuccess => status == PaymentStatus.success;
  bool get isCancelled => status == PaymentStatus.cancelled;
  bool get isFailed => status == PaymentStatus.failed;
}

enum PaymentStatus {
  success,
  failed,
  cancelled,
}
