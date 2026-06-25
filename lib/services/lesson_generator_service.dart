import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../core/error_handler.dart' as app_errors;
import '../models/models.dart';

/// Generated lesson draft for teacher create flow.
class GeneratedLesson {
  final String title;
  final String subject;
  final String description;
  final String emoji;
  final String colorHex;
  final List<LessonSlide> slides;
  final List<Checkpoint> checkpoints;

  const GeneratedLesson({
    required this.title,
    required this.subject,
    required this.description,
    required this.emoji,
    required this.colorHex,
    required this.slides,
    required this.checkpoints,
  });

  factory GeneratedLesson.fromLesson(Lesson lesson) {
    return GeneratedLesson(
      title: lesson.title,
      subject: lesson.subject,
      description: lesson.description,
      emoji: lesson.emoji,
      colorHex: '#${lesson.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      slides: lesson.slides,
      checkpoints: lesson.checkpoints,
    );
  }
}

/// Builds lesson content from a teacher prompt — OpenAI when configured, else smart templates.
class LessonGeneratorService {
  LessonGeneratorService._();
  static final instance = LessonGeneratorService._();

  Future<app_errors.Result<GeneratedLesson>> generate({
    required String prompt,
    required int slideCount,
    required bool includeQuiz,
    required bool aiVoice,
    required String gradeBand,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return app_errors.Result.failure('Enter a topic or lesson description first.');
    }

    if (Env.openAiApiKey.isNotEmpty) {
      try {
        final ai = await _generateWithOpenAi(
          prompt: trimmed,
          slideCount: slideCount,
          includeQuiz: includeQuiz,
          aiVoice: aiVoice,
          gradeBand: gradeBand,
        );
        if (ai != null) return app_errors.Result.success(ai);
      } catch (e, stack) {
        await app_errors.ErrorHandler.reportError(e, stack, context: 'OpenAI lesson generation');
      }
    }

    return app_errors.Result.success(
      _templateLesson(
        prompt: trimmed,
        slideCount: slideCount,
        includeQuiz: includeQuiz,
        aiVoice: aiVoice,
        gradeBand: gradeBand,
      ),
    );
  }

  Future<GeneratedLesson?> _generateWithOpenAi({
    required String prompt,
    required int slideCount,
    required bool includeQuiz,
    required bool aiVoice,
    required String gradeBand,
  }) async {
    final system = '''
You are a K-12 lesson author. Return ONLY valid JSON (no markdown) with this shape:
{
  "title": "string",
  "subject": "string",
  "description": "string",
  "emoji": "single emoji",
  "color_hex": "#RRGGBB",
  "slides": [
    {
      "id": "s1",
      "title": "string",
      "body": "string",
      "image_emoji": "emoji",
      "caption": "narration caption",
      "speech_text": "text for TTS",
      "speech_lang": "en-US or zh-CN etc"
    }
  ],
  "checkpoints": [
    {
      "id": "c1",
      "type": "multipleChoice",
      "prompt": "question",
      "hint": "optional",
      "options": [{"id":"o1","label":"A","is_correct":true}]
    }
  ]
}
Create exactly $slideCount slides for $gradeBand learners. ${includeQuiz ? 'Include 2-4 quiz questions.' : 'Return empty checkpoints array.'}
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${Env.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'temperature': 0.7,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI error ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = body['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) return null;

    return _parseGeneratedJson(content, aiVoice: aiVoice);
  }

  GeneratedLesson? _parseGeneratedJson(String jsonStr, {required bool aiVoice}) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final slidesRaw = map['slides'] as List? ?? [];
      final checkpointsRaw = map['checkpoints'] as List? ?? [];

      final slides = slidesRaw.asMap().entries.map((e) {
        final m = Map<String, dynamic>.from(e.value as Map);
        return LessonSlide(
          id: m['id'] as String? ?? 's${e.key + 1}',
          title: m['title'] as String? ?? 'Slide ${e.key + 1}',
          body: m['body'] as String? ?? '',
          imageEmoji: m['image_emoji'] as String? ?? '📘',
          caption: m['caption'] as String?,
          speechText: m['speech_text'] as String?,
          speechLang: m['speech_lang'] as String? ?? 'en-US',
          aiVoice: aiVoice,
        );
      }).toList();

      final checkpoints = checkpointsRaw.asMap().entries.map((e) {
        final m = Map<String, dynamic>.from(e.value as Map);
        final optionsRaw = m['options'] as List? ?? [];
        return Checkpoint(
          id: m['id'] as String? ?? 'c${e.key + 1}',
          type: CheckpointType.multipleChoice,
          prompt: m['prompt'] as String? ?? '',
          hint: m['hint'] as String?,
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

      if (slides.isEmpty) return null;

      return GeneratedLesson(
        title: map['title'] as String? ?? 'Generated lesson',
        subject: map['subject'] as String? ?? 'General',
        description: map['description'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '✨',
        colorHex: map['color_hex'] as String? ?? '#6C5CE7',
        slides: slides,
        checkpoints: checkpoints,
      );
    } catch (_) {
      return null;
    }
  }

  GeneratedLesson _templateLesson({
    required String prompt,
    required int slideCount,
    required bool includeQuiz,
    required bool aiVoice,
    required String gradeBand,
  }) {
    final lower = prompt.toLowerCase();
    final isMandarin = lower.contains('mandarin') ||
        lower.contains('chinese') ||
        lower.contains('tone') ||
        RegExp(r'[\u4e00-\u9fff]').hasMatch(prompt);
    final isMath = lower.contains('math') ||
        lower.contains('fraction') ||
        lower.contains('number') ||
        lower.contains('add') ||
        lower.contains('subtract');
    final isScience = lower.contains('science') || lower.contains('planet') || lower.contains('solar');

    if (isMandarin) {
      return _mandarinTemplate(prompt, slideCount, includeQuiz, aiVoice);
    }
    if (isMath) {
      return _mathTemplate(prompt, slideCount, includeQuiz, aiVoice, gradeBand);
    }
    if (isScience) {
      return _scienceTemplate(prompt, slideCount, includeQuiz, aiVoice);
    }
    return _generalTemplate(prompt, slideCount, includeQuiz, aiVoice, gradeBand);
  }

  GeneratedLesson _mandarinTemplate(String prompt, int count, bool quiz, bool aiVoice) {
    const vocab = [
      ('一', 'yī', 'one', '1️⃣'),
      ('二', 'èr', 'two', '2️⃣'),
      ('三', 'sān', 'three', '3️⃣'),
      ('四', 'sì', 'four', '4️⃣'),
      ('五', 'wǔ', 'five', '5️⃣'),
      ('六', 'liù', 'six', '6️⃣'),
      ('七', 'qī', 'seven', '7️⃣'),
      ('八', 'bā', 'eight', '8️⃣'),
    ];
    final slides = <LessonSlide>[];
    for (var i = 0; i < count.clamp(3, vocab.length); i++) {
      final v = vocab[i];
      slides.add(LessonSlide(
        id: 's${i + 1}',
        title: '${v.$1} — ${v.$2}',
        body: 'This character means "${v.$3}". Listen and repeat.',
        imageEmoji: v.$4,
        caption: '${v.$2} means ${v.$3}.',
        speechText: '${v.$1}。${v.$2}。',
        speechLang: 'zh-CN',
        aiVoice: aiVoice,
      ));
    }
    final checkpoints = quiz
        ? [
            Checkpoint(
              id: 'c1',
              type: CheckpointType.multipleChoice,
              prompt: 'Which character means "three"?',
              options: const [
                QuizOption(id: 'o1', label: '一'),
                QuizOption(id: 'o2', label: '三', isCorrect: true),
                QuizOption(id: 'o3', label: '二'),
              ],
            ),
            Checkpoint(
              id: 'c2',
              type: CheckpointType.multipleChoice,
              prompt: 'What does "yī" mean?',
              options: const [
                QuizOption(id: 'o1', label: 'One', isCorrect: true),
                QuizOption(id: 'o2', label: 'Two'),
                QuizOption(id: 'o3', label: 'Four'),
              ],
            ),
          ]
        : <Checkpoint>[];

    return GeneratedLesson(
      title: prompt.length > 48 ? '${prompt.substring(0, 45)}…' : prompt,
      subject: 'Mandarin',
      description: prompt,
      emoji: '🔢',
      colorHex: '#6C5CE7',
      slides: slides,
      checkpoints: checkpoints,
    );
  }

  GeneratedLesson _mathTemplate(String prompt, int count, bool quiz, bool aiVoice, String grade) {
    final slides = List.generate(count.clamp(3, 6), (i) {
      final n = i + 1;
      return LessonSlide(
        id: 's$n',
        title: 'Step $n',
        body: 'Explore part $n of $prompt with clear examples.',
        imageEmoji: '🍕',
        caption: 'Let\'s learn step $n together.',
        speechText: 'Step $n. ${prompt.split('.').first}.',
        aiVoice: aiVoice,
      );
    });

    return GeneratedLesson(
      title: prompt.length > 48 ? '${prompt.substring(0, 45)}…' : prompt,
      subject: 'Maths',
      description: prompt,
      emoji: '🍕',
      colorHex: '#00CEC9',
      slides: slides,
      checkpoints: quiz
          ? [
              const Checkpoint(
                id: 'c1',
                type: CheckpointType.multipleChoice,
                prompt: 'If you eat 2 of 4 equal slices, what fraction did you eat?',
                options: [
                  QuizOption(id: 'o1', label: '1/2', isCorrect: true),
                  QuizOption(id: 'o2', label: '1/4'),
                  QuizOption(id: 'o3', label: '3/4'),
                ],
              ),
            ]
          : const [],
    );
  }

  GeneratedLesson _scienceTemplate(String prompt, int count, bool quiz, bool aiVoice) {
    const facts = [
      ('The Sun', 'A giant ball of hot plasma at the centre of our solar system.', '☀️'),
      ('Earth', 'Our home — the only planet we know with life.', '🌍'),
      ('Mars', 'The red planet with the largest volcano in the solar system.', '🔴'),
      ('Jupiter', 'The biggest planet — a gas giant with a famous storm.', '🪐'),
    ];
    final slides = List.generate(count.clamp(2, facts.length), (i) {
      final f = facts[i];
      return LessonSlide(
        id: 's${i + 1}',
        title: f.$1,
        body: f.$2,
        imageEmoji: f.$3,
        caption: f.$2,
        speechText: '${f.$1}. ${f.$2}',
        aiVoice: aiVoice,
      );
    });

    return GeneratedLesson(
      title: prompt.length > 48 ? '${prompt.substring(0, 45)}…' : prompt,
      subject: 'Science',
      description: prompt,
      emoji: '🪐',
      colorHex: '#0284C7',
      slides: slides,
      checkpoints: quiz
          ? [
              const Checkpoint(
                id: 'c1',
                type: CheckpointType.multipleChoice,
                prompt: 'Which planet is known as the red planet?',
                options: [
                  QuizOption(id: 'o1', label: 'Mars', isCorrect: true),
                  QuizOption(id: 'o2', label: 'Venus'),
                  QuizOption(id: 'o3', label: 'Mercury'),
                ],
              ),
            ]
          : const [],
    );
  }

  GeneratedLesson _generalTemplate(String prompt, int count, bool quiz, bool aiVoice, String grade) {
    final slides = List.generate(count.clamp(3, 8), (i) {
      final n = i + 1;
      return LessonSlide(
        id: 's$n',
        title: 'Part $n',
        body: 'Key idea $n about $prompt, explained for $grade learners.',
        imageEmoji: '📘',
        caption: 'Part $n of your lesson.',
        speechText: 'Part $n. $prompt',
        aiVoice: aiVoice,
      );
    });

    return GeneratedLesson(
      title: prompt.length > 48 ? '${prompt.substring(0, 45)}…' : prompt,
      subject: 'General',
      description: prompt,
      emoji: '✨',
      colorHex: '#6C5CE7',
      slides: slides,
      checkpoints: quiz
          ? [
              Checkpoint(
                id: 'c1',
                type: CheckpointType.multipleChoice,
                prompt: 'What is this lesson mainly about?',
                options: [
                  QuizOption(id: 'o1', label: prompt.split(' ').take(3).join(' '), isCorrect: true),
                  const QuizOption(id: 'o2', label: 'Something else'),
                  const QuizOption(id: 'o3', label: 'Not sure'),
                ],
              ),
            ]
          : const [],
    );
  }
}
