import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/error_handler.dart' as app_errors;
import '../models/rope_pull_models.dart';
import 'supabase_service.dart';

class RopePullService {
  RopePullService._();
  static final instance = RopePullService._();

  SupabaseClient? get _client =>
      SupabaseService.instance.isInitialized ? Supabase.instance.client : null;

  String _rpcMessage(Object error) {
    final text = error.toString();
    if (text.contains('NEED_TWO_PLAYERS')) {
      return 'Wait for a friend to join before you pull.';
    }
    if (text.contains('INVALID_CODE')) {
      return 'That code does not match a live room.';
    }
    if (text.contains('ROOM_FULL')) {
      return 'This courtyard is full.';
    }
    if (text.contains('ROOM_FINISHED')) {
      return 'This pull already finished.';
    }
    if (text.contains('NOT_AUTHORIZED') || text.contains('NOT_A_PLAYER')) {
      return 'You are not in this room.';
    }
    if (text.contains('INVALID_BANK')) return 'INVALID_BANK';
    if (text.contains('INVALID_QUESTIONS')) return 'INVALID_QUESTIONS';
    return 'Could not update the rope pull.';
  }

  Future<app_errors.Result<RopePullSnapshot>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final client = _client;
      if (client == null || client.auth.currentUser == null) {
        return app_errors.Result.failure('Sign in to play Rope Pull.');
      }
      final raw = await client.rpc(name, params: params);
      final map = switch (raw) {
        final Map value => Map<String, dynamic>.from(value),
        final String value => Map<String, dynamic>.from(
          jsonDecode(value) as Map,
        ),
        _ => throw StateError('Unexpected rope pull payload'),
      };
      return app_errors.Result.success(RopePullSnapshot.fromJson(map));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'rope_pull.$name',
      );
      return app_errors.Result.failure(_rpcMessage(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'rope_pull.$name',
      );
      return app_errors.Result.failure(_rpcMessage(error));
    }
  }

  Future<app_errors.Result<RopePullSnapshot>> createRoom({
    required RopePullBank bank,
    required List<RopePullQuestion> questions,
    required bool hostPlays,
    required String displayName,
    required String avatar,
  }) {
    return _rpc('create_rope_pull_room', {
      'p_bank': bank.wire,
      'p_questions': questions.map((item) => item.toJson()).toList(),
      'p_host_plays': hostPlays,
      'p_display_name': displayName,
      'p_avatar': avatar,
    });
  }

  Future<app_errors.Result<RopePullSnapshot>> joinRoom({
    required String code,
    required String displayName,
    required String avatar,
  }) {
    return _rpc('join_rope_pull_room', {
      'p_code': code.trim().toUpperCase(),
      'p_display_name': displayName,
      'p_avatar': avatar,
    });
  }

  Future<app_errors.Result<RopePullSnapshot>> startRoom(String roomId) {
    return _rpc('start_rope_pull_room', {'p_room_id': roomId});
  }

  Future<app_errors.Result<RopePullSnapshot>> submitAnswer({
    required String roomId,
    required int round,
    required String selected,
  }) {
    return _rpc('submit_rope_pull_answer', {
      'p_room_id': roomId,
      'p_round': round,
      'p_selected': selected,
    });
  }

  Future<app_errors.Result<RopePullSnapshot>> advance(String roomId) {
    return _rpc('advance_rope_pull_round', {'p_room_id': roomId});
  }

  Future<app_errors.Result<RopePullSnapshot>> fetch(String roomId) {
    return _rpc('fetch_rope_pull_room', {'p_room_id': roomId});
  }

  Stream<RopePullSnapshot?> watchRoom(String roomId) {
    final controller = StreamController<RopePullSnapshot?>();
    RealtimeChannel? channel;
    Timer? timer;

    Future<void> refresh() async {
      final result = await fetch(roomId);
      if (!controller.isClosed) controller.add(result.data);
    }

    refresh();
    final client = _client;
    if (client != null) {
      channel = client
          .channel('rope_pull_$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rope_pull_rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: roomId,
            ),
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rope_pull_players',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rope_pull_answers',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
      timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    }

    controller.onCancel = () async {
      timer?.cancel();
      if (channel != null && client != null) {
        await client.removeChannel(channel);
      }
      if (!controller.isClosed) await controller.close();
    };

    return controller.stream;
  }
}
