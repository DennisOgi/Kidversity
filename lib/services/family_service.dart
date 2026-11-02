import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/error_handler.dart' as app_errors;
import '../data/auth_state.dart';
import '../models/family_models.dart';
import 'supabase_service.dart';

/// Parents, children, and the family code that links them.
class FamilyService {
  FamilyService._();
  static final instance = FamilyService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  /// Parent: the code a child types in to join this family.
  Future<app_errors.Result<String>> myCode() async {
    try {
      final raw = await _client.rpc('family_my_code');
      final code = raw is Map ? raw['code'] as String? : null;
      if (code == null || code.isEmpty) {
        return app_errors.Result.failure('Your family code is not ready yet.');
      }
      return app_errors.Result.success(code);
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'family_my_code',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'family_my_code',
      );
      return app_errors.Result.failure('Your family code is not ready yet.');
    }
  }

  /// Child: join a parent's family. Returns the family label.
  Future<app_errors.Result<String>> join(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return app_errors.Result.failure('Enter the family code.');
    }
    try {
      final raw = await _client.rpc(
        'family_join',
        params: {
          'p_code': trimmed.startsWith('FAM-') ? trimmed : 'FAM-$trimmed',
        },
      );
      final label = raw is Map ? raw['label'] as String? : null;
      return app_errors.Result.success(label ?? 'your family');
    } on PostgrestException catch (error) {
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'family_join',
      );
      return app_errors.Result.failure('That code did not work. Try again.');
    }
  }

  Future<app_errors.Result<void>> removeLearner(String learnerUserId) async {
    try {
      await _client.rpc(
        'family_remove_learner',
        params: {'p_learner_user_id': learnerUserId},
      );
      return app_errors.Result.success(null);
    } on PostgrestException catch (error) {
      return app_errors.Result.failure(_message(error));
    } catch (_) {
      return app_errors.Result.failure('Could not update your family.');
    }
  }

  Future<app_errors.Result<FamilyOverview>> overview() async {
    try {
      final raw = await _client.rpc('family_overview');
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return app_errors.Result.success(FamilyOverview.fromJson(map));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'family_overview',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'family_overview',
      );
      return app_errors.Result.failure('Your family could not be loaded.');
    }
  }

  Future<app_errors.Result<PaymentAnalytics>> adminAnalytics() async {
    try {
      final raw = await _client.rpc('admin_payment_analytics');
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return app_errors.Result.success(PaymentAnalytics.fromJson(map));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_payment_analytics',
      );
      return app_errors.Result.failure(_message(error));
    } catch (_) {
      return app_errors.Result.failure('Payment analytics could not load.');
    }
  }

  String _message(PostgrestException error) {
    final text = error.message;
    if (text.contains('FAMILY_NOT_FOUND')) {
      return 'That family code does not match. Check it with your parent.';
    }
    if (text.contains('ONLY_LEARNERS_JOIN')) {
      return 'Only learner accounts can join a family with a code.';
    }
    if (text.contains('LEARNER_NOT_IN_FAMILY')) {
      return 'That learner is not linked to your family.';
    }
    if (text.contains('NOT_AUTHORIZED')) {
      return 'This is only available to parent accounts.';
    }
    return 'Something went wrong. Try again.';
  }
}

final familyOverviewProvider = FutureProvider.autoDispose<FamilyOverview>((
  ref,
) async {
  ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
  final result = await FamilyService.instance.overview();
  if (result.isFailure) {
    throw StateError(result.error ?? 'Your family could not be loaded.');
  }
  return result.data!;
});

final familyCodeProvider = FutureProvider.autoDispose<String>((ref) async {
  ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
  final result = await FamilyService.instance.myCode();
  if (result.isFailure) {
    throw StateError(result.error ?? 'Your family code is not ready yet.');
  }
  return result.data!;
});

final paymentAnalyticsProvider = FutureProvider.autoDispose<PaymentAnalytics>((
  ref,
) async {
  ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
  final result = await FamilyService.instance.adminAnalytics();
  if (result.isFailure) {
    throw StateError(result.error ?? 'Payment analytics could not load.');
  }
  return result.data!;
});
