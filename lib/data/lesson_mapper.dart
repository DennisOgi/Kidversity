import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';

/// Maps Supabase `lessons` rows (JSONB slides/checkpoints) to app models.
class LessonMapper {
  static Lesson fromRow(Map<String, dynamic> row, {double progress = 0}) {
    return Lesson(
      id: row['id'] as String,
      title: row['title'] as String,
      subject: row['subject'] as String,
      description: row['description'] as String? ?? '',
      source: _sourceFromDb(row['source'] as String?),
      status: _statusFromDb(row['status'] as String?),
      authorName: row['author_name'] as String? ?? 'Kidversity',
      color: _colorFromHex(row['color'] as String?),
      emoji: row['emoji'] as String? ?? '📘',
      gradeBandLabel: (row['grade_band_label'] as num?)?.toInt() ?? 5,
      xpReward: (row['xp_reward'] as num?)?.toInt() ?? 120,
      progress: progress,
      slides: _slidesFromJson(row['slides']),
      checkpoints: _checkpointsFromJson(row['checkpoints']),
    );
  }

  static List<LessonSlide> _slidesFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return LessonSlide(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        imageEmoji: m['image_emoji'] as String?,
        caption: m['caption'] as String?,
        audioDuration: Duration(
          milliseconds: (m['audio_duration_ms'] as num?)?.toInt() ?? 18000,
        ),
        aiVoice: m['ai_voice'] as bool? ?? false,
        speechText: m['speech_text'] as String?,
        speechLang: m['speech_lang'] as String? ?? 'en-US',
      );
    }).toList();
  }

  static List<Checkpoint> _checkpointsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final optionsRaw = m['options'] as List? ?? const [];
      return Checkpoint(
        id: m['id'] as String? ?? '',
        type: _checkpointType(m['type'] as String?),
        prompt: m['prompt'] as String? ?? '',
        hint: m['hint'] as String?,
        audioPrompt: m['audio_prompt'] as String?,
        audioLang: m['audio_lang'] as String? ?? 'zh-CN',
        options: optionsRaw
            .map((o) {
              final opt = Map<String, dynamic>.from(o as Map);
              return QuizOption(
                id: opt['id'] as String? ?? '',
                label: opt['label'] as String? ?? '',
                isCorrect: opt['is_correct'] as bool? ?? false,
              );
            })
            .toList(),
      );
    }).toList();
  }

  static ContentSource _sourceFromDb(String? value) => switch (value) {
        'uploaded' => ContentSource.uploaded,
        'ai_generated' => ContentSource.aiGenerated,
        'hybrid' => ContentSource.hybrid,
        _ => ContentSource.aiGenerated,
      };

  static LessonStatus _statusFromDb(String? value) => switch (value) {
        'draft' => LessonStatus.draft,
        'assigned' => LessonStatus.assigned,
        _ => LessonStatus.published,
      };

  static CheckpointType _checkpointType(String? value) => switch (value) {
        'matching' => CheckpointType.matching,
        'pronunciation' => CheckpointType.pronunciation,
        'typed' => CheckpointType.typed,
        _ => CheckpointType.multipleChoice,
      };

  static Color _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return AppColors.primary;
  }

  static RewardBadge badgeFromRow(
    Map<String, dynamic> badgeRow, {
    bool unlocked = false,
    double progress = 0,
  }) {
    return RewardBadge(
      id: badgeRow['id'] as String,
      name: badgeRow['name'] as String,
      description: badgeRow['description'] as String? ?? '',
      emoji: badgeRow['emoji'] as String? ?? '🏆',
      color: _colorFromHex(badgeRow['color'] as String?),
      unlocked: unlocked,
      progress: progress,
    );
  }

  static LeaderboardEntry leaderboardFromProfile(
    Map<String, dynamic> row, {
    required int rank,
    String? currentUserId,
  }) {
    final userId = row['user_id'] as String?;
    return LeaderboardEntry(
      rank: rank,
      name: row['display_name'] as String? ?? 'Learner',
      avatarEmoji: row['avatar_emoji'] as String? ?? '🦊',
      xp: (row['xp'] as num?)?.toInt() ?? 0,
      isCurrentUser: currentUserId != null && userId == currentUserId,
    );
  }

  /// Serialize a lesson for Supabase `lessons` insert/upsert.
  static Map<String, dynamic> lessonToInsert({
    required String title,
    required String subject,
    required String description,
    required ContentSource source,
    required String authorId,
    required String authorName,
    required List<LessonSlide> slides,
    required List<Checkpoint> checkpoints,
    String? colorHex,
    String emoji = '📘',
    int gradeBandLabel = 5,
    int xpReward = 120,
    int estimatedMinutes = 10,
    LessonStatus status = LessonStatus.published,
  }) {
    return {
      'title': title,
      'subject': subject,
      'description': description,
      'source': _sourceToDb(source),
      'status': _statusToDb(status),
      'author_id': authorId,
      'author_name': authorName,
      'color': colorHex ?? '#6C5CE7',
      'emoji': emoji,
      'grade_band_label': gradeBandLabel,
      'xp_reward': xpReward,
      'estimated_minutes': estimatedMinutes,
      'slides': slidesToJson(slides),
      'checkpoints': checkpointsToJson(checkpoints),
    };
  }

  static List<Map<String, dynamic>> slidesToJson(List<LessonSlide> slides) {
    return slides
        .map((s) => {
              'id': s.id,
              'title': s.title,
              'body': s.body,
              if (s.imageEmoji != null) 'image_emoji': s.imageEmoji,
              if (s.caption != null) 'caption': s.caption,
              'audio_duration_ms': s.audioDuration.inMilliseconds,
              'ai_voice': s.aiVoice,
              if (s.speechText != null) 'speech_text': s.speechText,
              'speech_lang': s.speechLang,
            })
        .toList();
  }

  static List<Map<String, dynamic>> checkpointsToJson(List<Checkpoint> checkpoints) {
    return checkpoints
        .map((c) => {
              'id': c.id,
              'type': _checkpointTypeToDb(c.type),
              'prompt': c.prompt,
              if (c.hint != null) 'hint': c.hint,
              if (c.audioPrompt != null) 'audio_prompt': c.audioPrompt,
              'audio_lang': c.audioLang,
              'options': c.options
                  .map((o) => {
                        'id': o.id,
                        'label': o.label,
                        if (o.isCorrect) 'is_correct': true,
                      })
                  .toList(),
            })
        .toList();
  }

  static String _sourceToDb(ContentSource source) => switch (source) {
        ContentSource.uploaded => 'uploaded',
        ContentSource.hybrid => 'hybrid',
        _ => 'ai_generated',
      };

  static String _statusToDb(LessonStatus status) => switch (status) {
        LessonStatus.draft => 'draft',
        LessonStatus.assigned => 'assigned',
        _ => 'published',
      };

  static String _checkpointTypeToDb(CheckpointType type) => switch (type) {
        CheckpointType.matching => 'matching',
        CheckpointType.pronunciation => 'pronunciation',
        CheckpointType.typed => 'typed',
        _ => 'multipleChoice',
      };

  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}

/// Stable IDs for seeded catalog content.
abstract final class CatalogIds {
  static const mandarinFamily = 'a1000001-0001-4001-8001-000000000001';
  static const mandarinNumbers = 'a1000001-0002-4001-8001-000000000002';
}
