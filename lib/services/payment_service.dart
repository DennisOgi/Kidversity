import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/error_handler.dart' as app_errors;
import '../models/payment_models.dart';
import 'supabase_service.dart';

class PaymentService {
  PaymentService._();
  static final instance = PaymentService._();

  Future<app_errors.Result<PaymentCatalog>> fetchCatalog() async {
    try {
      final raw = await SupabaseService.instance.client.rpc('payment_catalog');
      return app_errors.Result.success(PaymentCatalog.fromJson(_asMap(raw)));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'payment_catalog',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'payment_catalog',
      );
      return app_errors.Result.failure('Payment catalog could not be loaded.');
    }
  }

  Future<app_errors.Result<PaymentAccess>> fetchMyAccess() async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'payment_my_access',
      );
      return app_errors.Result.success(PaymentAccess.fromJson(_asMap(raw)));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'payment_my_access',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'payment_my_access',
      );
      return app_errors.Result.failure('Payment access could not be loaded.');
    }
  }

  /// [learnerUserId] lets a parent buy for a child already in the family.
  Future<app_errors.Result<PaymentCheckoutSession>> startCheckout({
    required String productType,
    String? packId,
    String? callbackUrl,
    String? learnerUserId,
  }) async {
    try {
      final email = SupabaseService.instance.currentUser?.email;
      final response = await SupabaseService.instance.client.functions.invoke(
        'payments-checkout',
        body: {
          'productType': productType,
          'packId': ?packId,
          'email': ?email,
          'callbackUrl': ?callbackUrl,
          'learnerUserId': ?learnerUserId,
        },
      );
      final data = _asMap(response.data);
      if (data['error'] != null) {
        return app_errors.Result.failure(_codeMessage('${data['error']}'));
      }
      return app_errors.Result.success(PaymentCheckoutSession.fromJson(data));
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map
          ? '${details['error']}'
          : '${error.reasonPhrase}';
      return app_errors.Result.failure(_codeMessage(code));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'payments-checkout',
      );
      return app_errors.Result.failure(
        'Checkout could not be started. Confirm Paystack is configured.',
      );
    }
  }

  Future<app_errors.Result<void>> verifyReference(String reference) async {
    try {
      final response = await SupabaseService.instance.client.functions.invoke(
        'payments-verify',
        body: {'reference': reference},
      );
      final data = _asMap(response.data);
      if (data['ok'] == true) return app_errors.Result.success(null);
      return app_errors.Result.failure('Payment is not complete yet.');
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'payments-verify',
      );
      return app_errors.Result.failure('Payment could not be verified.');
    }
  }

  Future<app_errors.Result<int>> redeemCredit(
    String packId, {
    String? learnerUserId,
  }) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'payment_redeem_credit',
        params: {'p_pack_id': packId, 'p_learner_user_id': ?learnerUserId},
      );
      final map = _asMap(raw);
      return app_errors.Result.success(_int(map['credits_remaining']));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'payment_redeem_credit',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'payment_redeem_credit',
      );
      return app_errors.Result.failure('Credit could not be redeemed.');
    }
  }

  Future<void> markPromptSeen(String packId) async {
    try {
      await SupabaseService.instance.client.rpc(
        'payment_mark_prompt_seen',
        params: {'p_pack_id': packId},
      );
    } catch (_) {}
  }

  Future<bool> openCheckoutUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _message(PostgrestException error) => _codeMessage(error.message);

  String _codeMessage(String text) {
    if (text.contains('PACK_ALREADY_OWNED')) {
      return 'This pack is already unlocked.';
    }
    if (text.contains('NO_CREDITS')) {
      return 'No pack credits left. Buy a bundle or a single pack.';
    }
    if (text.contains('PACK_NOT_FOUND')) return 'That pack was not found.';
    if (text.contains('LEARNER_NOT_IN_FAMILY')) {
      return 'Link your child with the family code first.';
    }
    if (text.contains('PAYSTACK_SECRET_KEY_MISSING')) {
      return 'Payments are not switched on yet. Please try again later.';
    }
    if (text.contains('EMAIL_REQUIRED')) {
      return 'Add an email address to your account to pay.';
    }
    return 'Something went wrong with payments. Try again.';
  }
}
