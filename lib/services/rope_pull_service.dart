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
    if (text.contains('NEEDS_SCHOOL')) {
      return 'Quick match pairs you with classmates. Join your class first, or share a code.';
    }
    if (text.contains('INVALID_BANK')) return 'INVALID_BANK';
    if (text.contains('INVALID_QUESTIONS')) return 'INVALID_QUESTIONS';
    if (text.contains('NOT_ENOUGH_QUESTIONS')) return 'NOT_ENOUGH_QUESTIONS';
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

  /// Opens a match whose questions the server picks, so no device ever holds
  /// the answers. [deck] says how many questions and, for past questions,
  /// which paper.
  Future<app_errors.Result<RopePullSnapshot>> createRoom({
    required RopePullBank bank,
    RopePullDeckOptions deck = const RopePullDeckOptions(),
    required bool hostPlays,
    required String displayName,
    required String avatar,
    String? challengedUserId,
    String? classId,
  }) {
    return _rpc('create_rope_pull_match', {
      'p_bank': bank.wire,
      'p_options': deck.toJson(),
      'p_host_plays': hostPlays,
      'p_display_name': displayName,
      'p_avatar': avatar,
      if (challengedUserId != null && challengedUserId.isNotEmpty)
        'p_challenged_user_id': challengedUserId,
      if (classId != null && classId.isNotEmpty) 'p_class_id': classId,
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

  Future<app_errors.Result<RopePullSnapshot>> joinRoomById({
    required String roomId,
    required String displayName,
    required String avatar,
  }) {
    return _rpc('join_rope_pull_room_by_id', {
      'p_room_id': roomId,
      'p_display_name': displayName,
      'p_avatar': avatar,
    });
  }

  Future<app_errors.Result<RopePullSchoolPlay>> fetchSchoolPlay() async {
    try {
      final client = _client;
      if (client == null || client.auth.currentUser == null) {
        return app_errors.Result.success(RopePullSchoolPlay.empty);
      }
      final raw = await client.rpc('fetch_rope_pull_school_play');
      final map = switch (raw) {
        final Map value => Map<String, dynamic>.from(value),
        _ => <String, dynamic>{},
      };
      return app_errors.Result.success(RopePullSchoolPlay.fromJson(map));
    } on PostgrestException catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'rope_pull.fetch_school_play',
      );
      return app_errors.Result.failure('Could not load your class.');
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'rope_pull.fetch_school_play',
      );
      return app_errors.Result.failure('Could not load your class.');
    }
  }

  /// Pairs the caller with a classmate waiting for the same game, or opens
  /// a room that the next classmate drops into. The pull starts on its own.
  Future<app_errors.Result<RopePullSnapshot>> quickMatch({
    required RopePullBank bank,
    RopePullDeckOptions deck = const RopePullDeckOptions(),
    required String displayName,
    required String avatar,
  }) {
    return _rpc('rope_pull_quick_match_v2', {
      'p_bank': bank.wire,
      'p_options': deck.toJson(),
      'p_display_name': displayName,
      'p_avatar': avatar,
    });
  }

  /// This week's winners in the caller's school.
  Future<List<RopePullLadderEntry>> ladder({int days = 7}) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return const [];
    try {
      final raw = await client.rpc(
        'rope_pull_ladder',
        params: {'p_days': days},
      );
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            RopePullLadderEntry.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'rope_pull.ladder',
      );
      return const [];
    }
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
    Timer? debounce;
    var inFlight = false;
    var again = false;

    // One fetch at a time. Events that land while a fetch runs ask for one
    // more fetch afterwards, never one each, so a class of 30 answering does
    // not turn into 30 reloads on every phone.
    Future<void> refresh() async {
      if (inFlight) {
        again = true;
        return;
      }
      inFlight = true;
      try {
        do {
          again = false;
          final result = await fetch(roomId);
          if (controller.isClosed) return;
          controller.add(result.data);
        } while (again);
      } finally {
        inFlight = false;
      }
    }

    // Realtime events often arrive in bursts (room row + player rows).
    void soon() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 150), refresh);
    }

    void poll(Duration every) {
      timer?.cancel();
      // A late subscribe status after the screen closed must not restart it.
      if (controller.isClosed) return;
      timer = Timer.periodic(every, (_) => refresh());
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
            callback: (_) => soon(),
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
            callback: (_) => soon(),
          )
          // Every answer touches the room row, so rooms + players are enough.
          // rope_pull_answers is not published: picks stay secret mid-round.
          .subscribe((status, _) {
            // Live: a slow safety poll is enough. Not live: poll quickly so
            // the match still moves.
            poll(
              status == RealtimeSubscribeStatus.subscribed
                  ? const Duration(seconds: 8)
                  : const Duration(seconds: 2),
            );
            if (status == RealtimeSubscribeStatus.subscribed) refresh();
          });
      poll(const Duration(seconds: 2));
    }

    controller.onCancel = () async {
      timer?.cancel();
      debounce?.cancel();
      if (channel != null && client != null) {
        await client.removeChannel(channel);
      }
      if (!controller.isClosed) await controller.close();
    };

    return controller.stream;
  }
}
