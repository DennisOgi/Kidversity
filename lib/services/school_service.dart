import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/error_handler.dart' as app_errors;
import '../models/school_models.dart';
import 'supabase_service.dart';

class SchoolService {
  SchoolService._();
  static final instance = SchoolService._();

  Future<app_errors.Result<SchoolOverview>> fetchOverview({
    String? schoolId,
  }) async {
    try {
      final service = SupabaseService.instance;
      if (!service.isInitialized || service.currentUser == null) {
        return app_errors.Result.success(SchoolOverview.empty);
      }
      final raw = schoolId == null || schoolId.isEmpty
          ? await service.client.rpc('fetch_school_overview')
          : await service.client.rpc(
              'fetch_school_overview',
              params: {'p_school_id': schoolId},
            );
      return app_errors.Result.success(SchoolOverview.fromJson(_asMap(raw)));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'fetch_school_overview',
      );
      return app_errors.Result.failure('The school could not be loaded.');
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'fetch_school_overview',
      );
      return app_errors.Result.failure('The school could not be loaded.');
    }
  }

  Future<app_errors.Result<SchoolClassInfo>> createClass(
    String name, {
    String? schoolId,
  }) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'create_school_class',
        params: {
          'p_name': name.trim(),
          'p_school_id': ?schoolId,
        },
      );
      final map = _asMap(raw);
      return app_errors.Result.success(
        SchoolClassInfo(
          id: map['id'] as String? ?? '',
          name: map['name'] as String? ?? name.trim(),
          joinCode: map['join_code'] as String?,
          teacherId: SupabaseService.instance.currentUser?.id ?? '',
          teacherName: 'You',
          memberCount: 0,
        ),
      );
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'create_school_class',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'create_school_class',
      );
      return app_errors.Result.failure('Could not create the class.');
    }
  }

  Future<app_errors.Result<String>> addTeacher(
    String email, {
    String? schoolId,
  }) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'add_school_teacher',
        params: {
          'p_email': email.trim(),
          'p_school_id': ?schoolId,
        },
      );
      final map = _asMap(raw);
      final name = map['display_name'] as String? ?? email.trim();
      return app_errors.Result.success(name);
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'add_school_teacher',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'add_school_teacher',
      );
      return app_errors.Result.failure('Could not add that teacher.');
    }
  }

  Future<app_errors.Result<SchoolMembership>> createSchool(String name) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'create_school',
        params: {'p_name': name.trim()},
      );
      final map = _asMap(raw);
      return app_errors.Result.success(
        SchoolMembership(
          id: map['id'] as String? ?? '',
          name: map['name'] as String? ?? name.trim(),
          role: 'admin',
        ),
      );
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'create_school',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'create_school',
      );
      return app_errors.Result.failure('Could not create the school.');
    }
  }

  String _message(PostgrestException error) {
    final text = error.message;
    if (text.contains('NOT_FOUND')) {
      return 'No Kidversity account uses that email yet.';
    }
    if (text.contains('NOT_AUTHORIZED')) {
      return 'Only a school admin can do that.';
    }
    if (text.contains('INVALID_NAME')) {
      return 'Use a class name between 2 and 60 characters.';
    }
    return 'That did not work. Try again.';
  }

  Map<String, dynamic> _asMap(Object? raw) => switch (raw) {
    final Map value => Map<String, dynamic>.from(value),
    final String value => Map<String, dynamic>.from(
      jsonDecode(value) as Map,
    ),
    _ => throw StateError('Unexpected school payload'),
  };
}
