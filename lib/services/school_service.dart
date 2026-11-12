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
        params: {'p_name': name.trim(), 'p_school_id': ?schoolId},
      );
      final map = _asMap(raw);
      return app_errors.Result.success(
        SchoolClassInfo(
          id: map['id'] as String? ?? '',
          name: map['name'] as String? ?? name.trim(),
          joinCode: map['join_code'] as String?,
          teacherId: map['teacher_id'] as String? ?? '',
          teacherName: 'Unassigned',
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
        params: {'p_email': email.trim(), 'p_school_id': ?schoolId},
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

  Future<app_errors.Result<String>> assignTeacherToClass({
    required String classId,
    required String email,
  }) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'assign_class_teacher',
        params: {'p_class_id': classId, 'p_email': email.trim()},
      );
      final map = _asMap(raw);
      return app_errors.Result.success(
        map['display_name'] as String? ?? email.trim(),
      );
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'assign_class_teacher',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'assign_class_teacher',
      );
      return app_errors.Result.failure('Could not assign that teacher.');
    }
  }

  Future<app_errors.Result<String>> assignStudentToClass({
    required String classId,
    required String email,
  }) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'assign_class_student',
        params: {'p_class_id': classId, 'p_email': email.trim()},
      );
      final map = _asMap(raw);
      return app_errors.Result.success(
        map['display_name'] as String? ?? email.trim(),
      );
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'assign_class_student',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'assign_class_student',
      );
      return app_errors.Result.failure('Could not add that student.');
    }
  }

  Future<app_errors.Result<SchoolDirectory>> fetchDirectory({
    String? schoolId,
  }) async {
    try {
      final raw = schoolId == null || schoolId.isEmpty
          ? await SupabaseService.instance.client.rpc('fetch_school_directory')
          : await SupabaseService.instance.client.rpc(
              'fetch_school_directory',
              params: {'p_school_id': schoolId},
            );
      return app_errors.Result.success(SchoolDirectory.fromJson(_asMap(raw)));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'fetch_school_directory',
      );
      return app_errors.Result.failure('Could not load the school list.');
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'fetch_school_directory',
      );
      return app_errors.Result.failure('Could not load the school list.');
    }
  }

  Future<app_errors.Result<void>> removeStudentFromClass({
    required String classId,
    required String userId,
  }) async {
    try {
      await SupabaseService.instance.client.rpc(
        'remove_class_student',
        params: {'p_class_id': classId, 'p_user_id': userId},
      );
      return app_errors.Result.success(null);
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'remove_class_student',
      );
      return app_errors.Result.failure(_message(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'remove_class_student',
      );
      return app_errors.Result.failure('Could not remove that student.');
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

  /// Calls a school RPC, reports failures, and turns error codes into words.
  Future<app_errors.Result<T>> _call<T>(
    String fn,
    Map<String, dynamic> params,
    T Function(Object? raw) parse, {
    required String fallback,
  }) async {
    try {
      final raw = await SupabaseService.instance.client.rpc(fn, params: params);
      return app_errors.Result.success(parse(raw));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(error, stack, context: fn);
      final message = _message(error);
      return app_errors.Result.failure(
        message == _unknown ? fallback : message,
      );
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(error, stack, context: fn);
      return app_errors.Result.failure(fallback);
    }
  }

  Map<String, dynamic> _withSchool(String? schoolId) => {
    if (schoolId != null && schoolId.isNotEmpty) 'p_school_id': schoolId,
  };

  Future<app_errors.Result<SchoolAdminInfo>> fetchAdmin({String? schoolId}) =>
      _call(
        'fetch_school_admin',
        _withSchool(schoolId),
        (raw) => SchoolAdminInfo.fromJson(_asMap(raw)),
        fallback: 'The school settings could not be loaded.',
      );

  /// Adds an existing account now, or keeps an invite for when they sign up.
  /// Success data is true when the person was added straight away.
  Future<app_errors.Result<bool>> inviteStaff({
    required String email,
    String role = 'teacher',
    String? schoolId,
  }) => _call(
    'invite_school_staff',
    {'p_email': email.trim(), 'p_role': role, ..._withSchool(schoolId)},
    (raw) => _asMap(raw)['status'] == 'added',
    fallback: 'The invite could not be sent.',
  );

  Future<app_errors.Result<void>> revokeInvite(String inviteId) => _call(
    'revoke_school_invite',
    {'p_invite_id': inviteId},
    (_) {},
    fallback: 'The invite could not be cancelled.',
  );

  /// Returns the school name.
  Future<app_errors.Result<String>> joinWithStaffCode(String code) => _call(
    'join_school_with_staff_code',
    {'p_code': code.trim()},
    (raw) => _asMap(raw)['name'] as String? ?? 'your school',
    fallback: 'That staff code did not work.',
  );

  Future<app_errors.Result<String>> regenerateStaffCode({String? schoolId}) =>
      _call(
        'regenerate_school_staff_code',
        _withSchool(schoolId),
        (raw) => '$raw',
        fallback: 'A new staff code could not be made.',
      );

  Future<app_errors.Result<String>> renameSchool(
    String name, {
    String? schoolId,
  }) => _call(
    'rename_school',
    {'p_name': name.trim(), ..._withSchool(schoolId)},
    (raw) => _asMap(raw)['name'] as String? ?? name.trim(),
    fallback: 'The school could not be renamed.',
  );

  /// Returns the class name.
  Future<app_errors.Result<String>> placeStudent({
    required String classId,
    required String userId,
  }) => _call(
    'place_school_student',
    {'p_class_id': classId, 'p_user_id': userId},
    (raw) => _asMap(raw)['class_name'] as String? ?? 'the class',
    fallback: 'That student could not be placed.',
  );

  Future<app_errors.Result<void>> removeMember(
    String userId, {
    String? schoolId,
  }) => _call(
    'remove_school_member',
    {'p_user_id': userId, ..._withSchool(schoolId)},
    (_) {},
    fallback: 'They could not be removed.',
  );

  Future<app_errors.Result<void>> setStaffRole(
    String userId,
    String role, {
    String? schoolId,
  }) => _call(
    'set_school_staff_role',
    {'p_user_id': userId, 'p_role': role, ..._withSchool(schoolId)},
    (_) {},
    fallback: 'Their role could not be changed.',
  );

  static const _unknown = 'That did not work. Try again.';

  String _message(PostgrestException error) {
    final text = error.message;
    if (text.contains('INVALID_EMAIL')) return 'Check the email address.';
    if (text.contains('NOT_STAFF_ACCOUNT')) {
      return 'That account is a student or parent account, not staff.';
    }
    if (text.contains('INVALID_CODE')) {
      return 'That code did not match a school. Check it with your school admin.';
    }
    if (text.contains('LAST_ADMIN')) {
      return 'A school needs at least one admin. Make someone else admin first.';
    }
    if (text.contains('CANNOT_REMOVE_SELF')) {
      return 'You cannot remove yourself. Ask another admin.';
    }
    if (text.contains('NOT_FOUND')) {
      return 'No Kidversity account uses that email yet.';
    }
    if (text.contains('NOT_AUTHORIZED')) {
      return 'Only a school admin can do that.';
    }
    if (text.contains('INVALID_NAME')) {
      return 'Use a class name between 2 and 60 characters.';
    }
    return _unknown;
  }

  Map<String, dynamic> _asMap(Object? raw) => switch (raw) {
    final Map value => Map<String, dynamic>.from(value),
    final String value => Map<String, dynamic>.from(jsonDecode(value) as Map),
    _ => throw StateError('Unexpected school payload'),
  };
}
