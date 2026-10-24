import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayProvider extends ChangeNotifier {
  Razorpay? _razorpay;
  Completer<PaymentSuccessResponse>? _paymentCompleter;
  bool isOpeningCheckout = false;

  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  RazorpayProvider() {
    if (isSupportedPlatform) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  Future<PaymentSuccessResponse> openCheckout({
    required Map<String, dynamic> options,
  }) {
    if (!isSupportedPlatform) {
      throw UnsupportedError(
        'Razorpay payments are only supported on Android and iOS devices. Please run the app on an Android emulator or mobile phone.',
      );
    }
    if (isOpeningCheckout) {
      throw StateError('A Razorpay checkout is already open.');
    }

    final completer = Completer<PaymentSuccessResponse>();
    _paymentCompleter = completer;
    isOpeningCheckout = true;
    notifyListeners();

    try {
      _razorpay!.open(options);
    } catch (error) {
      _completeError(error);
    }
    return completer.future;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final completer = _paymentCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(response);
    _finishCheckout();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _completeError(
      Exception(response.message ?? 'Razorpay could not complete the payment.'),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay external wallet selected: ${response.walletName}');
  }

  void _completeError(Object error) {
    final completer = _paymentCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
    _finishCheckout();
  }

  void _finishCheckout() {
    _paymentCompleter = null;
    isOpeningCheckout = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _completeError(StateError('Razorpay checkout was closed.'));
    _razorpay?.clear();
    super.dispose();
  }
}
