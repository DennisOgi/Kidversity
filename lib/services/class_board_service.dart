import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/error_handler.dart' as app_errors;
import '../models/class_board_models.dart';
import 'supabase_service.dart';

class ClassBoardService {
  ClassBoardService._();
  static final instance = ClassBoardService._();

  Future<app_errors.Result<ClassBoardSnapshot>> fetchBoard() async {
    try {
      final service = SupabaseService.instance;
      if (!service.isInitialized || service.currentUser == null) {
        return app_errors.Result.failure('Sign in to see the class board.');
      }
      final raw = await service.client.rpc('fetch_class_board');
      final map = switch (raw) {
        final Map value => Map<String, dynamic>.from(value),
        final String value => Map<String, dynamic>.from(
          jsonDecode(value) as Map,
        ),
        _ => throw StateError('Unexpected class board payload'),
      };
      return app_errors.Result.success(ClassBoardSnapshot.fromJson(map));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'fetch_class_board',
      );
      return app_errors.Result.failure('The class board could not be loaded.');
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'fetch_class_board',
      );
      return app_errors.Result.failure('The class board could not be loaded.');
    }
  }
}
