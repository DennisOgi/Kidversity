import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/error_handler.dart' as app_errors;
import '../models/admin_models.dart';
import 'supabase_service.dart';

class AdminService {
  AdminService._();
  static final instance = AdminService._();

  Future<app_errors.Result<AdminOverview>> fetchOverview() async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'admin_platform_overview',
      );
      return app_errors.Result.success(AdminOverview.fromJson(_asMap(raw)));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_platform_overview',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_platform_overview',
      );
      return app_errors.Result.failure('Overview could not be loaded.');
    }
  }

  Future<app_errors.Result<List<AdminSchoolSummary>>> listSchools() async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'admin_list_schools',
      );
      final List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        // Single-row clients sometimes unwrap a one-element jsonb array.
        list = [raw];
      } else {
        list = _asList(raw);
      }
      return app_errors.Result.success(
        list
            .whereType<Map>()
            .map((e) => AdminSchoolSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_list_schools',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_list_schools',
      );
      return app_errors.Result.failure('Schools could not be loaded.');
    }
  }

  Future<app_errors.Result<AdminSchoolDetail>> schoolDetail(
    String schoolId,
  ) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'admin_school_detail',
        params: {'p_school_id': schoolId},
      );
      return app_errors.Result.success(
        AdminSchoolDetail.fromJson(_asMap(raw)),
      );
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_school_detail',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_school_detail',
      );
      return app_errors.Result.failure('School detail could not be loaded.');
    }
  }

  Future<app_errors.Result<AdminUserList>> listUsers({
    String? role,
    String? schoolId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'admin_list_users',
        params: {
          'p_role': ?role,
          'p_school_id': ?schoolId,
          'p_search': ?search,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return app_errors.Result.success(AdminUserList.fromJson(_asMap(raw)));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_list_users',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_list_users',
      );
      return app_errors.Result.failure('Users could not be loaded.');
    }
  }

  Future<app_errors.Result<AdminUserPerformance>> userPerformance(
    String userId,
  ) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'admin_user_performance',
        params: {'p_user_id': userId},
      );
      return app_errors.Result.success(
        AdminUserPerformance.fromJson(_asMap(raw)),
      );
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_user_performance',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_user_performance',
      );
      return app_errors.Result.failure('Performance could not be loaded.');
    }
  }

  Future<app_errors.Result<AdminSchoolSummary>> createSchool({
    required String name,
    String? adminEmail,
  }) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'admin_create_school',
        params: {
          'p_name': name.trim(),
          'p_admin_email': ?adminEmail,
        },
      );
      final map = _asMap(raw);
      return app_errors.Result.success(
        AdminSchoolSummary(
          id: map['id'] as String? ?? '',
          name: map['name'] as String? ?? name.trim(),
          studentCount: 0,
          teacherCount: map['admin_user_id'] != null ? 1 : 0,
          classCount: 0,
          weeklyXp: 0,
        ),
      );
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_create_school',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_create_school',
      );
      return app_errors.Result.failure('School could not be created.');
    }
  }

  Future<app_errors.Result<void>> assignSchoolAdmin({
    required String schoolId,
    required String userId,
  }) async {
    try {
      await SupabaseService.instance.client.rpc(
        'admin_assign_school_admin',
        params: {'p_school_id': schoolId, 'p_user_id': userId},
      );
      return app_errors.Result.success(null);
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_assign_school_admin',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_assign_school_admin',
      );
      return app_errors.Result.failure('School admin could not be assigned.');
    }
  }

  Future<app_errors.Result<void>> setUserActive({
    required String userId,
    required bool active,
  }) async {
    try {
      await SupabaseService.instance.client.rpc(
        'admin_set_user_active',
        params: {'p_user_id': userId, 'p_active': active},
      );
      return app_errors.Result.success(null);
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_set_user_active',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'admin_set_user_active',
      );
      return app_errors.Result.failure('Account status could not be updated.');
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  List<dynamic> _asList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is String) {
      // Some PostgREST clients return JSON text for jsonb.
      return const [];
    }
    return const [];
  }

  String _message(PostgrestException error) {
    final text = error.message;
    if (text.contains('NOT_AUTHORIZED')) {
      return 'Platform admin access is required.';
    }
    if (text.contains('ADMIN_USER_NOT_FOUND')) {
      return 'No Kidversity account uses that email yet.';
    }
    if (text.contains('SCHOOL_NOT_FOUND')) return 'School not found.';
    if (text.contains('USER_NOT_FOUND')) return 'User not found.';
    if (text.contains('INVALID_NAME')) {
      return 'School name must be 2–80 characters.';
    }
    if (text.contains('CANNOT_DEACTIVATE_SELF')) {
      return 'You cannot deactivate your own account.';
    }
    if (text.contains('CANNOT_DEACTIVATE_PLATFORM_ADMIN')) {
      return 'Platform admin accounts cannot be deactivated here.';
    }
    return 'Something went wrong. Try again.';
  }
}
