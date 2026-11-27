import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_state.dart';
import 'supabase_service.dart';

/// Communication Book: class announcements and private guardian updates,
/// with separate "viewed" and "acknowledged" receipts and replies. Every call
/// goes through a server function that checks the caller is the class
/// teacher or a linked guardian.
class CommService {
  CommService._();
  static final instance = CommService._();

  SupabaseClient get _db => SupabaseService.instance.client;

  Future<String> post({
    required String classId,
    required bool private,
    required String subject,
    required String body,
    String? studentId,
    bool needsAck = false,
  }) async =>
      (await _db.rpc(
            'comm_post',
            params: {
              'p_class_id': classId,
              'p_kind': private ? 'private' : 'announcement',
              'p_subject': subject,
              'p_body': body,
              'p_student': studentId,
              'p_needs_ack': needsAck,
            },
          ))
          as String;

  Future<ClassMessages> classMessages(String classId) async {
    final raw = await _db.rpc(
      'comm_class_messages',
      params: {'p_class_id': classId},
    );
    return ClassMessages.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<CommMessage> message(String id) async {
    final raw = await _db.rpc('comm_message', params: {'p_message': id});
    return CommMessage.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<CommSummary>> inbox() async {
    final raw = await _db.rpc('comm_inbox');
    return [
      for (final r in (raw as List? ?? const []))
        CommSummary.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> markViewed(String id) =>
      _db.rpc('comm_mark_viewed', params: {'p_message': id});

  Future<void> acknowledge(String id) =>
      _db.rpc('comm_acknowledge', params: {'p_message': id});

  Future<void> reply(String id, String body) =>
      _db.rpc('comm_reply', params: {'p_message': id, 'p_body': body});

  static String errorText(Object error) {
    final text = '$error';
    if (text.contains('NOT_AUTHORIZED')) {
      return 'Only the class teacher can send messages to this class.';
    }
    if (text.contains('NOT_IN_CLASS')) {
      return 'That pupil is not in this class.';
    }
    if (text.contains('INVALID_SUBJECT')) return 'Add a short subject line.';
    if (text.contains('EMPTY_MESSAGE')) return 'Write a message first.';
    if (text.contains('NOT_FOUND')) {
      return 'This message is no longer available.';
    }
    return 'That did not send. Check your connection and try again.';
  }
}

DateTime? _date(Object? v) => DateTime.tryParse('${v ?? ''}')?.toLocal();
int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// A message as it appears in a list.
class CommSummary {
  final String id;
  final bool private;
  final String subject;
  final String preview;
  final bool needsAck;
  final DateTime? createdAt;
  final String? author;
  final String? className;
  final String? student;
  // Teacher lists
  final int recipients;
  final int viewed;
  final int acknowledged;
  final int replies;
  // Parent inbox
  final DateTime? viewedAt;
  final DateTime? acknowledgedAt;

  const CommSummary({
    required this.id,
    required this.private,
    required this.subject,
    required this.preview,
    required this.needsAck,
    this.createdAt,
    this.author,
    this.className,
    this.student,
    this.recipients = 0,
    this.viewed = 0,
    this.acknowledged = 0,
    this.replies = 0,
    this.viewedAt,
    this.acknowledgedAt,
  });

  factory CommSummary.fromJson(Map<String, dynamic> j) => CommSummary(
    id: j['id'] as String,
    private: j['kind'] == 'private',
    subject: (j['subject'] as String?) ?? '',
    preview: (j['body'] as String?) ?? '',
    needsAck: j['needs_ack'] == true,
    createdAt: _date(j['created_at']),
    author: j['author'] as String?,
    className: j['class_name'] as String?,
    student: j['student'] as String?,
    recipients: _int(j['recipients']),
    viewed: _int(j['viewed']),
    acknowledged: _int(j['acknowledged']),
    replies: _int(j['replies']),
    viewedAt: _date(j['viewed_at']),
    acknowledgedAt: _date(j['acknowledged_at']),
  );

  bool get unread => viewedAt == null;
  bool get awaitingMyAck => needsAck && acknowledgedAt == null;
}

class ClassMessages {
  final int guardiansLinked;
  final int pupils;
  final List<CommSummary> messages;

  const ClassMessages({
    required this.guardiansLinked,
    required this.pupils,
    required this.messages,
  });

  factory ClassMessages.fromJson(Map<String, dynamic> j) => ClassMessages(
    guardiansLinked: _int(j['guardians_linked']),
    pupils: _int(j['pupils']),
    messages: [
      for (final m in (j['messages'] as List? ?? const []))
        CommSummary.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
  );
}

class CommRecipient {
  final String guardian;
  final String student;
  final DateTime? viewedAt;
  final DateTime? acknowledgedAt;

  const CommRecipient({
    required this.guardian,
    required this.student,
    this.viewedAt,
    this.acknowledgedAt,
  });
}

class CommReply {
  final String body;
  final String author;
  final bool mine;
  final bool fromStaff;
  final DateTime? createdAt;

  const CommReply({
    required this.body,
    required this.author,
    required this.mine,
    required this.fromStaff,
    this.createdAt,
  });
}

/// One message with receipts (teacher) and replies.
class CommMessage {
  final String id;
  final bool private;
  final String subject;
  final String body;
  final bool needsAck;
  final DateTime? createdAt;
  final bool canManage;
  final String? author;
  final String? className;
  final String? student;
  final DateTime? myViewedAt;
  final DateTime? myAcknowledgedAt;
  final List<CommRecipient> recipients;
  final List<CommReply> replies;

  const CommMessage({
    required this.id,
    required this.private,
    required this.subject,
    required this.body,
    required this.needsAck,
    required this.canManage,
    required this.recipients,
    required this.replies,
    this.createdAt,
    this.author,
    this.className,
    this.student,
    this.myViewedAt,
    this.myAcknowledgedAt,
  });

  factory CommMessage.fromJson(Map<String, dynamic> j) {
    final mine = j['mine'] == null
        ? null
        : Map<String, dynamic>.from(j['mine'] as Map);
    return CommMessage(
      id: j['id'] as String,
      private: j['kind'] == 'private',
      subject: (j['subject'] as String?) ?? '',
      body: (j['body'] as String?) ?? '',
      needsAck: j['needs_ack'] == true,
      createdAt: _date(j['created_at']),
      canManage: j['can_manage'] == true,
      author: j['author'] as String?,
      className: j['class_name'] as String?,
      student: j['student'] as String?,
      myViewedAt: _date(mine?['viewed_at']),
      myAcknowledgedAt: _date(mine?['acknowledged_at']),
      recipients: [
        for (final r in (j['recipients'] as List? ?? const []))
          CommRecipient(
            guardian: ((r as Map)['guardian'] as String?) ?? 'Parent',
            student: (r['student'] as String?) ?? 'Pupil',
            viewedAt: _date(r['viewed_at']),
            acknowledgedAt: _date(r['acknowledged_at']),
          ),
      ],
      replies: [
        for (final r in (j['replies'] as List? ?? const []))
          CommReply(
            body: ((r as Map)['body'] as String?) ?? '',
            author: (r['author'] as String?) ?? 'Someone',
            mine: r['mine'] == true,
            fromStaff: r['from_staff'] == true,
            createdAt: _date(r['created_at']),
          ),
      ],
    );
  }
}

final classMessagesProvider = FutureProvider.autoDispose
    .family<ClassMessages, String>((ref, classId) {
      ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
      return CommService.instance.classMessages(classId);
    });

final commMessageProvider = FutureProvider.autoDispose
    .family<CommMessage, String>((ref, id) {
      ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
      return CommService.instance.message(id);
    });

final commInboxProvider = FutureProvider.autoDispose<List<CommSummary>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
  return CommService.instance.inbox();
});

/// "2 h ago", "3 d ago", or a date.
String commWhen(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.day}/${t.month}/${t.year}';
}
