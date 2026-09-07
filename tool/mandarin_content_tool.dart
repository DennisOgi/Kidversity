import 'dart:convert';
import 'dart:io';

const _sourceId = 'kidversity-first-party-mfv1';
const _courseId = 'mandarin_foundation_v1';
const _allowedTypes = {'listen_tap', 'match', 'mcq', 'fill_blank'};
final _toneMark = RegExp(r'[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛ]');

void main(List<String> args) {
  final root = Directory.current.path;
  final packFile = File(
    '$root/content/mandarin/mandarin_foundation_lessons_04_30.json',
  );
  final sqlFile = File(
    '$root/content/mandarin/mandarin_foundation_lessons_04_30.seed.sql',
  );
  if (args.contains('--write-pack')) {
    packFile.parent.createSync(recursive: true);
    packFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(_buildPack())}\n',
    );
    stdout.writeln('Wrote ${packFile.path}');
  }
  if (!packFile.existsSync()) {
    stderr.writeln(
      'Missing content pack. Run: dart run tool/mandarin_content_tool.dart --write-pack',
    );
    exitCode = 2;
    return;
  }
  final pack = jsonDecode(packFile.readAsStringSync()) as Map<String, dynamic>;
  final errors = _validate(pack);
  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln('ERROR: $error');
    }
    stderr.writeln('Validation failed with ${errors.length} error(s).');
    exitCode = 1;
    return;
  }
  final sql = _emitSql(pack);
  sqlFile.writeAsStringSync(sql);
  final lessons = pack['lessons'] as List;
  final vocab = lessons.fold<int>(
    0,
    (n, l) => n + ((l as Map)['vocabulary'] as List).length,
  );
  final examples = lessons.fold<int>(
    0,
    (n, l) => n + ((l as Map)['examples'] as List).length,
  );
  final activities = lessons.fold<int>(
    0,
    (n, l) => n + ((l as Map)['activities'] as List).length,
  );
  final assessments = lessons.fold<int>(
    0,
    (n, l) => n + ((l as Map)['assessments'] as List).length,
  );
  final audio = lessons.fold<int>(
    0,
    (n, l) => n + ((l as Map)['audioRequests'] as List).length,
  );
  stdout.writeln(
    'VALID: ${lessons.length} lessons, $vocab vocabulary, $examples examples, '
    '$activities activities, $assessments assessments, $audio audio requests.',
  );
  stdout.writeln('Wrote deterministic SQL: ${sqlFile.path}');
}

List<String> _validate(Map<String, dynamic> pack) {
  final errors = <String>[];
  if (pack['courseId'] != _courseId) errors.add('courseId must be $_courseId');
  final lessons = pack['lessons'];
  if (lessons is! List || lessons.length != 27) {
    errors.add('Expected exactly 27 lessons.');
    return errors;
  }
  final allIds = <String>{};
  void uniqueId(String id, String context) {
    if (id.isEmpty || !allIds.add(id)) {
      errors.add('$context has missing or duplicate id "$id".');
    }
  }

  for (var index = 0; index < lessons.length; index++) {
    final lesson = lessons[index] as Map<String, dynamic>;
    final sequence = index + 4;
    final expectedId = 'mfv1_l${sequence.toString().padLeft(2, '0')}';
    if (lesson['id'] != expectedId) {
      errors.add('Lesson $sequence id must be $expectedId.');
    }
    uniqueId('${lesson['id']}', 'Lesson $sequence');
    if (lesson['sequence'] != sequence) {
      errors.add('$expectedId has incorrect sequence.');
    }
    final module = sequence <= 10 ? 1 : (sequence <= 20 ? 2 : 3);
    if (lesson['moduleSequence'] != module) {
      errors.add('$expectedId has incorrect moduleSequence.');
    }
    if (lesson['reviewStatus'] != 'ready') {
      errors.add('$expectedId must have ready reviewStatus.');
    }
    for (final field in ['title', 'objective', 'explanation']) {
      if ('${lesson[field]}'.trim().isEmpty) {
        errors.add('$expectedId has empty $field.');
      }
    }
    final vocabulary = lesson['vocabulary'] as List? ?? [];
    if (vocabulary.length < 4 || vocabulary.length > 6) {
      errors.add('$expectedId must have 4–6 vocabulary entries.');
    }
    final examples = lesson['examples'] as List? ?? [];
    if (examples.length < 2) {
      errors.add('$expectedId needs at least two examples.');
    }
    final grammar = lesson['grammar'] as List? ?? [];
    if (grammar.isEmpty) {
      errors.add('$expectedId needs explicit grammar entries.');
    }
    final functions = lesson['languageFunctions'] as List? ?? [];
    if (functions.isEmpty) {
      errors.add('$expectedId needs explicit language-function entries.');
    }
    final activities = lesson['activities'] as List? ?? [];
    if (activities.length < 2 ||
        activities.map((a) => (a as Map)['type']).toSet().length < 2) {
      errors.add('$expectedId needs at least two varied activities.');
    }
    final assessments = lesson['assessments'] as List? ?? [];
    if (assessments.length != 5) {
      errors.add('$expectedId must have exactly five assessments.');
    }
    final audio = lesson['audioRequests'] as List? ?? [];
    if (audio.isEmpty) errors.add('$expectedId needs requested audio texts.');

    final itemLists = <List>[
      vocabulary,
      examples,
      grammar,
      functions,
      lesson['dialogue'] as List? ?? [],
      activities,
      assessments,
      audio,
    ];
    for (final list in itemLists) {
      for (final raw in list) {
        final item = raw as Map<String, dynamic>;
        uniqueId('${item['id']}', expectedId);
        if (item['reviewStatus'] != 'pending') {
          errors.add('${item['id']} must have pending reviewStatus.');
        }
        if (item['sourceId'] != _sourceId) {
          errors.add('${item['id']} has incorrect sourceId.');
        }
      }
    }
    for (final raw in [
      ...vocabulary,
      ...examples,
      ...grammar,
      ...(lesson['dialogue'] as List? ?? []),
    ]) {
      final item = raw as Map<String, dynamic>;
      final pinyin = '${item['pinyin']}';
      final numbered = '${item['pinyinNumbered']}';
      final numberedSyllables = RegExp(r'[A-Za-züÜvV]+([1-5])')
          .allMatches(numbered)
          .map((match) => match.group(1))
          .whereType<String>()
          .toList();
      final neutralOnly =
          numberedSyllables.isNotEmpty &&
          numberedSyllables.every((tone) => tone == '5');
      if (!_toneMark.hasMatch(pinyin) && !neutralOnly) {
        errors.add('${item['id']} lacks tone-marked Pinyin.');
      }
      if (!RegExp(r'[1-5]').hasMatch(numbered)) {
        errors.add('${item['id']} lacks numbered-tone Pinyin.');
      }
    }
    for (final raw in [...activities, ...assessments]) {
      final item = raw as Map<String, dynamic>;
      if (!_allowedTypes.contains(item['type'])) {
        errors.add('${item['id']} has unsupported type.');
      }
      final answer = '${item['correctAnswer'] ?? item['answer']}';
      final options = (item['options'] as List? ?? [])
          .map((e) => '$e')
          .toList();
      if (!options.contains(answer)) {
        errors.add('${item['id']} options do not contain its answer.');
      }
      if (options.toSet().length != options.length) {
        errors.add('${item['id']} has duplicate options.');
      }
      if ('${item['explanation']}'.trim().isEmpty) {
        errors.add('${item['id']} lacks an explanation.');
      }
    }
  }
  return errors;
}

Map<String, dynamic> _buildPack() => {
  'schemaVersion': 1,
  'courseId': _courseId,
  'packId': 'mandarin-foundation-v1-lessons-04-30',
  'title': 'Mandarin Foundation Lessons 4–30',
  'targetAge': '7–12',
  'level': 'complete beginner',
  'source': {
    'id': _sourceId,
    'name': 'Kidversity Foundation V1 first-party curriculum drafting',
    'licence': 'All rights reserved — original Kidversity content',
    'datasetVersion': '1.0-draft',
    'provenance':
        'Original beginner-safe sentences authored for Kidversity; no imported sentence corpus.',
  },
  'reviewPolicy': {
    'lessonStatus': 'ready',
    'itemStatus': 'pending',
    'humanReviewRequired': true,
  },
  'lessons': _drafts.map(_lesson).toList(growable: false),
};

Map<String, dynamic> _lesson(_Draft d) {
  final n = d.sequence;
  final prefix = 'l$n';
  Map<String, dynamic> item(String id, Map<String, dynamic> body) => {
    'id': id,
    ...body,
    'sourceId': _sourceId,
    'reviewStatus': 'pending',
  };
  final vocab = <Map<String, dynamic>>[];
  for (var i = 0; i < d.vocab.length; i++) {
    final v = d.vocab[i];
    vocab.add(
      item('${prefix}v${i + 1}', {
        'simplified': v[0],
        'pinyin': v[1],
        'pinyinNumbered': v[2],
        'english': v[3],
        'partOfSpeech': v[4],
        if (v.length > 5 && v[5].isNotEmpty) 'classifierOrNotes': v[5],
      }),
    );
  }
  final examples = <Map<String, dynamic>>[];
  for (var i = 0; i < d.examples.length; i++) {
    final e = d.examples[i];
    examples.add(
      item('${prefix}e${i + 1}', {
        'chinese': e[0],
        'pinyin': e[1],
        'pinyinNumbered': e[2],
        'english': e[3],
      }),
    );
  }
  final grammar = [
    item('${prefix}g1', {
      'pattern': d.grammar[0],
      'explanation': d.grammar[1],
      'chinese': d.grammar[2],
      'pinyin': d.grammar[3],
      'pinyinNumbered': d.grammar[4],
      'english': d.grammar[5],
    }),
  ];
  final functions = [
    item('${prefix}f1', {
      'function': d.languageFunction,
      'canDoStatement': d.canDo,
    }),
  ];
  final dialogue = <Map<String, dynamic>>[];
  for (var i = 0; i < d.dialogue.length; i++) {
    final line = d.dialogue[i];
    dialogue.add(
      item('${prefix}d${i + 1}', {
        'speaker': line[0],
        'chinese': line[1],
        'pinyin': line[2],
        'pinyinNumbered': line[3],
        'english': line[4],
      }),
    );
  }
  final v0 = vocab[0], v1 = vocab[1], v2 = vocab[2], v3 = vocab[3];
  final activity2Type = ['match', 'fill_blank', 'mcq'][n % 3];
  List<String> options(String answer, Iterable<Object?> candidates) {
    final values = <String>[answer];
    for (final candidate in [
      ...candidates.map((value) => '$value'),
      '你好',
      '再见',
      '不知道',
    ]) {
      if (candidate != answer && !values.contains(candidate)) {
        values.add(candidate);
      }
      if (values.length == 3) break;
    }
    return values;
  }

  final activities = [
    item('${prefix}a1', {
      'type': 'listen_tap',
      'prompt': 'Listen and choose “${v0['english']}”.',
      'answer': v0['simplified'],
      'options': [v0['simplified'], v1['simplified'], v2['simplified']],
      'explanation':
          '${v0['simplified']} (${v0['pinyin']}) means ${v0['english']}.',
    }),
    item('${prefix}a2', {
      'type': activity2Type,
      'prompt': activity2Type == 'match'
          ? 'Match the Mandarin to its meaning.'
          : activity2Type == 'fill_blank'
          ? 'Complete the key expression: ${d.activityStem}'
          : 'Choose the best expression for this lesson.',
      'answer': activity2Type == 'match'
          ? '${v1['simplified']} = ${v1['english']}'
          : d.activityAnswer,
      'options': activity2Type == 'match'
          ? [
              '${v1['simplified']} = ${v1['english']}',
              '${v2['simplified']} = ${v1['english']}',
              '${v3['simplified']} = ${v1['english']}',
            ]
          : options(d.activityAnswer, [v2['simplified'], v3['simplified']]),
      'explanation': d.activityExplanation,
    }),
  ];
  final assessments = [
    item('${prefix}q1', {
      'type': 'mcq',
      'question': 'What does ${v0['simplified']} mean?',
      'correctAnswer': v0['english'],
      'options': [v0['english'], v1['english'], v2['english']],
      'explanation': '${v0['simplified']} means ${v0['english']}.',
    }),
    item('${prefix}q2', {
      'type': 'mcq',
      'question': 'Which Mandarin expression means “${v1['english']}”?',
      'correctAnswer': v1['simplified'],
      'options': [v1['simplified'], v2['simplified'], v3['simplified']],
      'explanation':
          '${v1['simplified']} (${v1['pinyin']}) means ${v1['english']}.',
    }),
    item('${prefix}q3', {
      'type': 'listen_tap',
      'question': 'Choose the Pinyin for ${v2['simplified']}.',
      'correctAnswer': v2['pinyin'],
      'options': [v2['pinyin'], v0['pinyin'], v3['pinyin']],
      'explanation': '${v2['simplified']} is pronounced ${v2['pinyin']}.',
    }),
    item('${prefix}q4', {
      'type': 'fill_blank',
      'question': 'Complete: ${d.activityStem}',
      'correctAnswer': d.activityAnswer,
      'options': options(d.activityAnswer, [
        v2['simplified'],
        v3['simplified'],
      ]),
      'explanation': d.activityExplanation,
    }),
    item('${prefix}q5', {
      'type': 'mcq',
      'question': 'Which sentence best shows: ${d.languageFunction}?',
      'correctAnswer': d.examples[0][0],
      'options': [d.examples[0][0], v2['simplified'], v3['simplified']],
      'explanation': '${d.examples[0][0]} means “${d.examples[0][3]}”.',
    }),
  ];
  final audio = <Map<String, dynamic>>[];
  for (final v in vocab) {
    audio.add(
      item('${v['id']}audio', {
        'itemType': 'vocab',
        'itemId': v['id'],
        'audioText': v['simplified'],
        'speechLang': 'zh-CN',
      }),
    );
  }
  for (final line in dialogue) {
    audio.add(
      item('${line['id']}audio', {
        'itemType': 'dialogue',
        'itemId': line['id'],
        'audioText': line['chinese'],
        'speechLang': 'zh-CN',
      }),
    );
  }
  for (final e in examples) {
    audio.add(
      item('${e['id']}audio', {
        'itemType': 'example',
        'itemId': e['id'],
        'audioText': e['chinese'],
        'speechLang': 'zh-CN',
      }),
    );
  }
  return {
    'id': 'mfv1_l${n.toString().padLeft(2, '0')}',
    'sequence': n,
    'moduleSequence': n <= 10 ? 1 : (n <= 20 ? 2 : 3),
    'title': d.title,
    'objective': d.objective,
    'reviewStatus': 'ready',
    'explanation': d.explanation,
    'xpReward': n % 10 == 0 ? (n == 30 ? 200 : 150) : 100,
    'sourceId': _sourceId,
    'vocabulary': vocab,
    'examples': examples,
    'grammar': grammar,
    'languageFunctions': functions,
    'dialogue': dialogue,
    'activities': activities,
    'assessments': assessments,
    'audioRequests': audio,
  };
}

String _emitSql(Map<String, dynamic> pack) {
  String q(Object? value) => "'${value.toString().replaceAll("'", "''")}'";
  String json(List values) => '${q(jsonEncode(values))}::jsonb';
  final out = StringBuffer()
    ..writeln(
      '-- Generated deterministically by tool/mandarin_content_tool.dart.',
    )
    ..writeln(
      '-- Draft content only: lessons are ready and all items are pending review.',
    )
    ..writeln('BEGIN;');
  for (final raw in pack['lessons'] as List) {
    final l = raw as Map<String, dynamic>;
    out.writeln(
      'INSERT INTO course_lessons (id, course_id, module_sequence, sequence, title, objective, explanation, status, xp_reward) VALUES '
      '(${q(l['id'])}, ${q(_courseId)}, ${l['moduleSequence']}, ${l['sequence']}, ${q(l['title'])}, ${q(l['objective'])}, ${q(l['explanation'])}, '
      "'ready', ${l['xpReward']}) ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, objective=EXCLUDED.objective, "
      'explanation=EXCLUDED.explanation, status=EXCLUDED.status, xp_reward=EXCLUDED.xp_reward;',
    );
    void rows(
      String key,
      String table,
      String Function(Map<String, dynamic>, int) values,
    ) {
      final list = l[key] as List;
      for (var i = 0; i < list.length; i++) {
        out.writeln(values(list[i] as Map<String, dynamic>, i + 1));
      }
    }

    rows(
      'vocabulary',
      'vocab_items',
      (v, i) =>
          'INSERT INTO vocab_items (id, lesson_id, simplified_chinese, pinyin, english_meaning, part_of_speech, source_id, review_status, sequence) VALUES '
          '(${q(v['id'])},${q(l['id'])},${q(v['simplified'])},${q(v['pinyin'])},${q(v['english'])},${q(v['partOfSpeech'])},'
          "'f1000000-0000-4000-8000-000000000001','pending',$i) ON CONFLICT (id) DO UPDATE SET "
          'simplified_chinese=EXCLUDED.simplified_chinese,pinyin=EXCLUDED.pinyin,english_meaning=EXCLUDED.english_meaning,review_status=EXCLUDED.review_status;',
    );
    rows(
      'examples',
      'examples',
      (e, i) =>
          'INSERT INTO examples (id,lesson_id,chinese,pinyin,english,source_id,review_status,sequence) VALUES '
          '(${q(e['id'])},${q(l['id'])},${q(e['chinese'])},${q(e['pinyin'])},${q(e['english'])},'
          "'f1000000-0000-4000-8000-000000000001','pending',$i) ON CONFLICT (id) DO UPDATE SET "
          'chinese=EXCLUDED.chinese,pinyin=EXCLUDED.pinyin,english=EXCLUDED.english,review_status=EXCLUDED.review_status;',
    );
    rows(
      'grammar',
      'grammar_patterns',
      (g, i) =>
          'INSERT INTO grammar_patterns (id,lesson_id,pattern,explanation,chinese,pinyin,english,source_id,review_status) VALUES '
          '(${q(g['id'])},${q(l['id'])},${q(g['pattern'])},${q(g['explanation'])},${q(g['chinese'])},${q(g['pinyin'])},${q(g['english'])},'
          "'f1000000-0000-4000-8000-000000000001','pending') ON CONFLICT (id) DO UPDATE SET pattern=EXCLUDED.pattern,"
          'explanation=EXCLUDED.explanation,chinese=EXCLUDED.chinese,pinyin=EXCLUDED.pinyin,english=EXCLUDED.english,review_status=EXCLUDED.review_status;',
    );
    rows(
      'dialogue',
      'dialogues',
      (d, i) =>
          'INSERT INTO dialogues (id,lesson_id,speaker,chinese,pinyin,english,source_id,review_status,sequence) VALUES '
          '(${q(d['id'])},${q(l['id'])},${q(d['speaker'])},${q(d['chinese'])},${q(d['pinyin'])},${q(d['english'])},'
          "'f1000000-0000-4000-8000-000000000001','pending',$i) ON CONFLICT (id) DO UPDATE SET speaker=EXCLUDED.speaker,"
          'chinese=EXCLUDED.chinese,pinyin=EXCLUDED.pinyin,english=EXCLUDED.english,review_status=EXCLUDED.review_status;',
    );
    rows(
      'activities',
      'activities',
      (a, i) =>
          'INSERT INTO activities (id,lesson_id,type,prompt,answer,distractors,explanation,difficulty,source_id,review_status,sequence) VALUES '
          '(${q(a['id'])},${q(l['id'])},${q(a['type'])},${q(a['prompt'])},${q(a['answer'])},'
          "${json((a['options'] as List).where((x) => x != a['answer']).toList())},${q(a['explanation'])},1,"
          "'f1000000-0000-4000-8000-000000000001','pending',$i) ON CONFLICT (id) DO UPDATE SET prompt=EXCLUDED.prompt,"
          'answer=EXCLUDED.answer,distractors=EXCLUDED.distractors,explanation=EXCLUDED.explanation,review_status=EXCLUDED.review_status;',
    );
    rows(
      'assessments',
      'assessment_items',
      (a, i) =>
          'INSERT INTO assessment_items (id,lesson_id,question,type,correct_answer,distractors,explanation,source_id,review_status,sequence) VALUES '
          '(${q(a['id'])},${q(l['id'])},${q(a['question'])},${q(a['type'])},${q(a['correctAnswer'])},'
          "${json((a['options'] as List).where((x) => x != a['correctAnswer']).toList())},${q(a['explanation'])},"
          "'f1000000-0000-4000-8000-000000000001','pending',$i) ON CONFLICT (id) DO UPDATE SET question=EXCLUDED.question,"
          'correct_answer=EXCLUDED.correct_answer,distractors=EXCLUDED.distractors,explanation=EXCLUDED.explanation,review_status=EXCLUDED.review_status;',
    );
    rows(
      'audioRequests',
      'audio_clips',
      (a, i) =>
          'INSERT INTO audio_clips (lesson_id,item_type,item_id,audio_text,speech_lang,provider,source_id,review_status) SELECT '
          '${q(l['id'])},${q(a['itemType'])},${q(a['itemId'])},${q(a['audioText'])},${q(a['speechLang'])},'
          "'device_tts','f1000000-0000-4000-8000-000000000001','pending' WHERE NOT EXISTS "
          '(SELECT 1 FROM audio_clips WHERE item_type=${q(a['itemType'])} AND item_id=${q(a['itemId'])});',
    );
  }
  out.writeln('COMMIT;');
  return out.toString();
}

class _Draft {
  final int sequence;
  final String title, objective, explanation, languageFunction, canDo;
  final List<List<String>> vocab, examples, dialogue;
  final List<String> grammar;
  final String activityStem, activityAnswer, activityExplanation;
  const _Draft(
    this.sequence,
    this.title,
    this.objective,
    this.explanation,
    this.vocab,
    this.examples,
    this.grammar,
    this.languageFunction,
    this.canDo,
    this.dialogue,
    this.activityStem,
    this.activityAnswer,
    this.activityExplanation,
  );
}

const _drafts = <_Draft>[
  _Draft(
    4,
    'What Is Your Name?',
    'Ask someone’s name.',
    'In Mandarin, ask 你叫什么名字？ to learn someone’s name. 叫 means “to be called.” A question mark and a friendly voice show that you are asking.',
    [
      ['你', 'nǐ', 'ni3', 'you', 'pronoun'],
      ['叫', 'jiào', 'jiao4', 'to be called', 'verb'],
      ['什么', 'shénme', 'shen2me5', 'what', 'question word'],
      ['名字', 'míngzi', 'ming2zi5', 'name', 'noun'],
      ['我', 'wǒ', 'wo3', 'I / me', 'pronoun'],
    ],
    [
      [
        '你叫什么名字？',
        'Nǐ jiào shénme míngzi?',
        'Ni3 jiao4 shen2me5 ming2zi5?',
        'What is your name?',
      ],
      ['我叫乐乐。', 'Wǒ jiào Lèlè.', 'Wo3 jiao4 Le4le5.', 'My name is Lele.'],
    ],
    [
      '你 + 叫 + 什么名字？',
      'Put the person before 叫什么名字 to ask their name.',
      '你叫什么名字？',
      'Nǐ jiào shénme míngzi?',
      'Ni3 jiao4 shen2me5 ming2zi5?',
      'What is your name?',
    ],
    'ask for a name',
    'I can politely ask a new friend’s name.',
    [
      [
        'Ming',
        '你叫什么名字？',
        'Nǐ jiào shénme míngzi?',
        'Ni3 jiao4 shen2me5 ming2zi5?',
        'What is your name?',
      ],
      [
        'Lele',
        '我叫乐乐。',
        'Wǒ jiào Lèlè.',
        'Wo3 jiao4 Le4le5.',
        'My name is Lele.',
      ],
    ],
    '你叫____名字？',
    '什么',
    '你叫什么名字？ is the complete name question.',
  ),
  _Draft(
    5,
    'Introducing Yourself',
    'Say your name and introduce yourself.',
    'Use 我叫 plus your name for a simple introduction. You can also say 我是 plus your name. Both are natural for a beginner introduction.',
    [
      ['我', 'wǒ', 'wo3', 'I / me', 'pronoun'],
      ['叫', 'jiào', 'jiao4', 'to be called', 'verb'],
      ['是', 'shì', 'shi4', 'am / is / are', 'verb'],
      ['同学', 'tóngxué', 'tong2xue2', 'classmate', 'noun'],
      ['很高兴', 'hěn gāoxìng', 'hen3 gao1xing4', 'glad to meet you', 'phrase'],
    ],
    [
      ['我叫安安。', 'Wǒ jiào Ān’ān.', 'Wo3 jiao4 An1’an1.', 'My name is Anan.'],
      [
        '我是新同学。',
        'Wǒ shì xīn tóngxué.',
        'Wo3 shi4 xin1 tong2xue2.',
        'I am a new classmate.',
      ],
    ],
    [
      '我叫 + name',
      'Place your name after 我叫 to introduce yourself.',
      '我叫安安。',
      'Wǒ jiào Ān’ān.',
      'Wo3 jiao4 An1’an1.',
      'My name is Anan.',
    ],
    'introduce yourself',
    'I can tell someone my name.',
    [
      [
        'Anan',
        '你好！我叫安安。',
        'Nǐ hǎo! Wǒ jiào Ān’ān.',
        'Ni3 hao3! Wo3 jiao4 An1’an1.',
        'Hello! My name is Anan.',
      ],
      [
        'Ming',
        '你好，很高兴！',
        'Nǐ hǎo, hěn gāoxìng!',
        'Ni3 hao3, hen3 gao1xing4!',
        'Hello, glad to meet you!',
      ],
    ],
    '我____安安。',
    '叫',
    '我叫安安 means “My name is Anan.”',
  ),
  _Draft(
    6,
    'Yes and No',
    'Respond with 是 and 不是.',
    '是 can confirm that something is true. Put 不 before 是 to make 不是, “is not.” In everyday Mandarin, answers often repeat the useful verb.',
    [
      ['是', 'shì', 'shi4', 'yes / is', 'verb'],
      [
        '不是',
        'bú shì',
        'bu2 shi4',
        'no / is not',
        'verb phrase',
        '不 changes to second tone before a fourth tone.',
      ],
      ['不', 'bù', 'bu4', 'not', 'adverb'],
      ['对', 'duì', 'dui4', 'correct / right', 'adjective'],
      [
        '吗',
        'ma',
        'ma5',
        'question particle',
        'particle',
        'Neutral tone; placed at the end of a yes/no question.',
      ],
    ],
    [
      [
        '你是学生吗？',
        'Nǐ shì xuésheng ma?',
        'Ni3 shi4 xue2sheng5 ma5?',
        'Are you a student?',
      ],
      [
        '是，我是学生。',
        'Shì, wǒ shì xuésheng.',
        'Shi4, wo3 shi4 xue2sheng5.',
        'Yes, I am a student.',
      ],
    ],
    [
      'statement + 吗？',
      'Add 吗 to turn a statement into a yes/no question.',
      '你是学生吗？',
      'Nǐ shì xuésheng ma?',
      'Ni3 shi4 xue2sheng5 ma5?',
      'Are you a student?',
    ],
    'answer yes or no',
    'I can confirm or correct simple information.',
    [
      [
        'Teacher',
        '你是明明吗？',
        'Nǐ shì Míngming ma?',
        'Ni3 shi4 Ming2ming5 ma5?',
        'Are you Mingming?',
      ],
      [
        'Lele',
        '不是，我是乐乐。',
        'Bú shì, wǒ shì Lèlè.',
        'Bu2 shi4, wo3 shi4 Le4le5.',
        'No, I am Lele.',
      ],
    ],
    '你是学生____？',
    '吗',
    '吗 at the end makes a yes/no question.',
  ),
  _Draft(
    7,
    'Numbers 1–5',
    'Count from one to five.',
    'Mandarin number words are short. Practise them in order, then try spotting each one on its own. 二 is the number two when counting.',
    [
      ['一', 'yī', 'yi1', 'one', 'number'],
      ['二', 'èr', 'er4', 'two', 'number'],
      ['三', 'sān', 'san1', 'three', 'number'],
      ['四', 'sì', 'si4', 'four', 'number'],
      ['五', 'wǔ', 'wu3', 'five', 'number'],
    ],
    [
      ['一、二、三。', 'Yī, èr, sān.', 'Yi1, er4, san1.', 'One, two, three.'],
      [
        '我有五本书。',
        'Wǒ yǒu wǔ běn shū.',
        'Wo3 you3 wu3 ben3 shu1.',
        'I have five books.',
      ],
    ],
    [
      'number + classifier + noun',
      'A number normally comes before a classifier and noun.',
      '五本书',
      'wǔ běn shū',
      'wu3 ben3 shu1',
      'five books',
    ],
    'count from one to five',
    'I can count and recognise 1–5.',
    [
      [
        'Kai',
        '一、二、三、四。',
        'Yī, èr, sān, sì.',
        'Yi1, er4, san1, si4.',
        'One, two, three, four.',
      ],
      ['Mei', '五！', 'Wǔ!', 'Wu3!', 'Five!'],
    ],
    '一、二、____、四、五',
    '三',
    '三 is three, between 二 and 四.',
  ),
  _Draft(
    8,
    'Numbers 6–10',
    'Count from six to ten.',
    'Add 六 through 十 to finish counting to ten. 十 means ten. Later, these same building blocks help make larger numbers.',
    [
      ['六', 'liù', 'liu4', 'six', 'number'],
      ['七', 'qī', 'qi1', 'seven', 'number'],
      ['八', 'bā', 'ba1', 'eight', 'number'],
      ['九', 'jiǔ', 'jiu3', 'nine', 'number'],
      ['十', 'shí', 'shi2', 'ten', 'number'],
    ],
    [
      ['六、七、八。', 'Liù, qī, bā.', 'Liu4, qi1, ba1.', 'Six, seven, eight.'],
      [
        '九加一是十。',
        'Jiǔ jiā yī shì shí.',
        'Jiu3 jia1 yi1 shi4 shi2.',
        'Nine plus one is ten.',
      ],
    ],
    [
      '九 + 一 = 十',
      'Use familiar numbers in a simple number sentence.',
      '九加一是十。',
      'Jiǔ jiā yī shì shí.',
      'Jiu3 jia1 yi1 shi4 shi2.',
      'Nine plus one is ten.',
    ],
    'count from six to ten',
    'I can count and recognise 6–10.',
    [
      [
        'Mei',
        '六、七、八、九。',
        'Liù, qī, bā, jiǔ.',
        'Liu4, qi1, ba1, jiu3.',
        'Six, seven, eight, nine.',
      ],
      ['Kai', '十！', 'Shí!', 'Shi2!', 'Ten!'],
    ],
    '六、七、八、____、十',
    '九',
    '九 is nine, between 八 and 十.',
  ),
  _Draft(
    9,
    'How Old Are You?',
    'Ask and answer about age.',
    'Ask 你几岁？ when speaking with a child. Answer with 我 plus your age and 岁. 岁 tells us that the number is an age in years.',
    [
      ['几', 'jǐ', 'ji3', 'how many', 'question word'],
      [
        '岁',
        'suì',
        'sui4',
        'years old',
        'age classifier',
        'Used after an age number.',
      ],
      ['你', 'nǐ', 'ni3', 'you', 'pronoun'],
      ['我', 'wǒ', 'wo3', 'I / me', 'pronoun'],
      ['八', 'bā', 'ba1', 'eight', 'number'],
    ],
    [
      ['你几岁？', 'Nǐ jǐ suì?', 'Ni3 ji3 sui4?', 'How old are you?'],
      ['我八岁。', 'Wǒ bā suì.', 'Wo3 ba1 sui4.', 'I am eight years old.'],
    ],
    [
      'person + number + 岁',
      'Put 岁 after the number to state someone’s age.',
      '我八岁。',
      'Wǒ bā suì.',
      'Wo3 ba1 sui4.',
      'I am eight years old.',
    ],
    'ask and state age',
    'I can ask another child’s age and answer.',
    [
      ['Mei', '你几岁？', 'Nǐ jǐ suì?', 'Ni3 ji3 sui4?', 'How old are you?'],
      ['Kai', '我八岁。', 'Wǒ bā suì.', 'Wo3 ba1 sui4.', 'I am eight.'],
    ],
    '我八____。',
    '岁',
    '岁 follows the age number.',
  ),
  _Draft(
    10,
    'Module 1 Quest — Review and Assessment',
    'Use Module 1 language in a short quest.',
    'This quest brings together greetings, names, yes/no answers, numbers and age. Listen for key words before choosing your reply.',
    [
      ['你好', 'nǐ hǎo', 'ni3 hao3', 'hello', 'greeting'],
      ['名字', 'míngzi', 'ming2zi5', 'name', 'noun'],
      ['是', 'shì', 'shi4', 'yes / is', 'verb'],
      ['十', 'shí', 'shi2', 'ten', 'number'],
      ['岁', 'suì', 'sui4', 'years old', 'age classifier'],
    ],
    [
      [
        '你好，我叫小雨。',
        'Nǐ hǎo, wǒ jiào Xiǎoyǔ.',
        'Ni3 hao3, wo3 jiao4 Xiao3yu3.',
        'Hello, my name is Xiaoyu.',
      ],
      ['我十岁。', 'Wǒ shí suì.', 'Wo3 shi2 sui4.', 'I am ten years old.'],
    ],
    [
      'greeting + name + age',
      'Link short familiar sentences to introduce yourself.',
      '你好，我叫小雨。我十岁。',
      'Nǐ hǎo, wǒ jiào Xiǎoyǔ. Wǒ shí suì.',
      'Ni3 hao3, wo3 jiao4 Xiao3yu3. Wo3 shi2 sui4.',
      'Hello, my name is Xiaoyu. I am ten.',
    ],
    'complete a first-meeting exchange',
    'I can greet, share my name and age, and say goodbye.',
    [
      [
        'Xiaoyu',
        '你好！你叫什么名字？',
        'Nǐ hǎo! Nǐ jiào shénme míngzi?',
        'Ni3 hao3! Ni3 jiao4 shen2me5 ming2zi5?',
        'Hello! What is your name?',
      ],
      [
        'Lele',
        '我叫乐乐。我十岁。',
        'Wǒ jiào Lèlè. Wǒ shí suì.',
        'Wo3 jiao4 Le4le5. Wo3 shi2 sui4.',
        'My name is Lele. I am ten.',
      ],
      ['Xiaoyu', '再见！', 'Zàijiàn!', 'Zai4jian4!', 'Goodbye!'],
    ],
    '我十____。',
    '岁',
    '岁 completes an age statement.',
  ),
  _Draft(
    11,
    'My Family',
    'Name close family members.',
    'Family words can be repeated sounds, such as 妈妈 and 爸爸. 哥哥 and 姐姐 name an older brother and older sister.',
    [
      ['妈妈', 'māma', 'ma1ma5', 'mum', 'noun'],
      ['爸爸', 'bàba', 'ba4ba5', 'dad', 'noun'],
      ['哥哥', 'gēge', 'ge1ge5', 'older brother', 'noun'],
      ['姐姐', 'jiějie', 'jie3jie5', 'older sister', 'noun'],
      ['家人', 'jiārén', 'jia1ren2', 'family members', 'noun'],
    ],
    [
      [
        '这是我妈妈。',
        'Zhè shì wǒ māma.',
        'Zhe4 shi4 wo3 ma1ma5.',
        'This is my mum.',
      ],
      [
        '我爱我的家人。',
        'Wǒ ài wǒ de jiārén.',
        'Wo3 ai4 wo3 de5 jia1ren2.',
        'I love my family.',
      ],
    ],
    [
      '我 + family word',
      'Use 我 before a family word to mean “my” in a simple label.',
      '我妈妈',
      'wǒ māma',
      'wo3 ma1ma5',
      'my mum',
    ],
    'name close family members',
    'I can identify people in my family.',
    [
      ['Mei', '这是谁？', 'Zhè shì shéi?', 'Zhe4 shi4 shei2?', 'Who is this?'],
      [
        'Kai',
        '这是我姐姐。',
        'Zhè shì wǒ jiějie.',
        'Zhe4 shi4 wo3 jie3jie5.',
        'This is my older sister.',
      ],
    ],
    '这是我____。',
    '妈妈',
    '这是我妈妈 introduces your mum.',
  ),
  _Draft(
    12,
    'This Is My…',
    'Introduce a person or belonging.',
    '这是 means “this is.” Add 我的 before a noun when you want to clearly show that something belongs to you. 的 links the owner and the thing.',
    [
      ['这', 'zhè', 'zhe4', 'this', 'pronoun'],
      ['我的', 'wǒ de', 'wo3 de5', 'my / mine', 'possessive phrase'],
      [
        '的',
        'de',
        'de5',
        'possessive particle',
        'particle',
        'Neutral tone; links an owner to a noun.',
      ],
      ['朋友', 'péngyou', 'peng2you5', 'friend', 'noun'],
      ['书', 'shū', 'shu1', 'book', 'noun', 'Classifier: 本 běn.'],
    ],
    [
      [
        '这是我的书。',
        'Zhè shì wǒ de shū.',
        'Zhe4 shi4 wo3 de5 shu1.',
        'This is my book.',
      ],
      [
        '这是我的朋友。',
        'Zhè shì wǒ de péngyou.',
        'Zhe4 shi4 wo3 de5 peng2you5.',
        'This is my friend.',
      ],
    ],
    [
      'owner + 的 + noun',
      '的 shows who a person or thing belongs with.',
      '我的书',
      'wǒ de shū',
      'wo3 de5 shu1',
      'my book',
    ],
    'introduce a person or possession',
    'I can say “This is my…”',
    [
      [
        'Kai',
        '这是什么？',
        'Zhè shì shénme?',
        'Zhe4 shi4 shen2me5?',
        'What is this?',
      ],
      [
        'Mei',
        '这是我的书。',
        'Zhè shì wǒ de shū.',
        'Zhe4 shi4 wo3 de5 shu1.',
        'This is my book.',
      ],
    ],
    '这是我____书。',
    '的',
    '的 links 我 and 书 to make “my book.”',
  ),
  _Draft(
    13,
    'My School',
    'Talk about school.',
    '学校 is school, 老师 is teacher and 学生 is student. Use 我在学校 to say you are at school.',
    [
      ['学校', 'xuéxiào', 'xue2xiao4', 'school', 'noun'],
      ['老师', 'lǎoshī', 'lao3shi1', 'teacher', 'noun'],
      ['学生', 'xuésheng', 'xue2sheng5', 'student', 'noun'],
      ['同学', 'tóngxué', 'tong2xue2', 'classmate', 'noun'],
      ['在', 'zài', 'zai4', 'to be at / in', 'verb'],
    ],
    [
      ['我在学校。', 'Wǒ zài xuéxiào.', 'Wo3 zai4 xue2xiao4.', 'I am at school.'],
      [
        '她是我的老师。',
        'Tā shì wǒ de lǎoshī.',
        'Ta1 shi4 wo3 de5 lao3shi1.',
        'She is my teacher.',
      ],
    ],
    [
      'person + 在 + place',
      'Use 在 before a place to say where someone is.',
      '我在学校。',
      'Wǒ zài xuéxiào.',
      'Wo3 zai4 xue2xiao4.',
      'I am at school.',
    ],
    'talk about people and location at school',
    'I can say I am at school and name school people.',
    [
      ['Teacher', '你在哪儿？', 'Nǐ zài nǎr?', 'Ni3 zai4 nar3?', 'Where are you?'],
      [
        'Kai',
        '我在学校。',
        'Wǒ zài xuéxiào.',
        'Wo3 zai4 xue2xiao4.',
        'I am at school.',
      ],
    ],
    '我在____。',
    '学校',
    '学校 is the place in “I am at school.”',
  ),
  _Draft(
    14,
    'Things in My Classroom',
    'Name common classroom objects.',
    'Mandarin uses classifiers between numbers and many nouns. 本 goes with bound books; 支 can count long thin objects such as pencils.',
    [
      ['书', 'shū', 'shu1', 'book', 'noun', 'Classifier: 本 běn.'],
      ['铅笔', 'qiānbǐ', 'qian1bi3', 'pencil', 'noun', 'Classifier: 支 zhī.'],
      ['桌子', 'zhuōzi', 'zhuo1zi5', 'desk / table', 'noun'],
      ['椅子', 'yǐzi', 'yi3zi5', 'chair', 'noun'],
      ['书包', 'shūbāo', 'shu1bao1', 'school bag', 'noun'],
    ],
    [
      [
        '这是一本书。',
        'Zhè shì yì běn shū.',
        'Zhe4 shi4 yi4 ben3 shu1.',
        'This is a book.',
      ],
      [
        '我有一支铅笔。',
        'Wǒ yǒu yì zhī qiānbǐ.',
        'Wo3 you3 yi4 zhi1 qian1bi3.',
        'I have a pencil.',
      ],
    ],
    [
      'number + classifier + noun',
      'Use a suitable classifier between a number and a noun.',
      '一本书',
      'yì běn shū',
      'yi4 ben3 shu1',
      'one book',
    ],
    'name and count classroom objects',
    'I can identify common things in a classroom.',
    [
      [
        'Mei',
        '你有什么？',
        'Nǐ yǒu shénme?',
        'Ni3 you3 shen2me5?',
        'What do you have?',
      ],
      [
        'Kai',
        '我有一支铅笔。',
        'Wǒ yǒu yì zhī qiānbǐ.',
        'Wo3 you3 yi4 zhi1 qian1bi3.',
        'I have a pencil.',
      ],
    ],
    '一____书',
    '本',
    '本 is the classifier used here for a book.',
  ),
  _Draft(
    15,
    'Colours',
    'Recognise and name basic colours.',
    'Colour words can come before 色, which means “colour.” 红色 is red and 蓝色 is blue. When naming a colour, you can simply say the colour word.',
    [
      ['红色', 'hóngsè', 'hong2se4', 'red', 'colour'],
      ['蓝色', 'lánsè', 'lan2se4', 'blue', 'colour'],
      ['黄色', 'huángsè', 'huang2se4', 'yellow', 'colour'],
      ['绿色', 'lǜsè', 'lü4se4', 'green', 'colour'],
      ['白色', 'báisè', 'bai2se4', 'white', 'colour'],
    ],
    [
      [
        '我的书包是蓝色的。',
        'Wǒ de shūbāo shì lánsè de.',
        'Wo3 de5 shu1bao1 shi4 lan2se4 de5.',
        'My school bag is blue.',
      ],
      ['我喜欢绿色。', 'Wǒ xǐhuan lǜsè.', 'Wo3 xi3huan5 lü4se4.', 'I like green.'],
    ],
    [
      'noun + 是 + colour + 的',
      'Use 是…的 to identify the colour of something.',
      '书包是蓝色的。',
      'Shūbāo shì lánsè de.',
      'Shu1bao1 shi4 lan2se4 de5.',
      'The school bag is blue.',
    ],
    'identify and name colours',
    'I can describe an object’s basic colour.',
    [
      [
        'Kai',
        '你的书包是什么颜色？',
        'Nǐ de shūbāo shì shénme yánsè?',
        'Ni3 de5 shu1bao1 shi4 shen2me5 yan2se4?',
        'What colour is your school bag?',
      ],
      ['Mei', '是红色的。', 'Shì hóngsè de.', 'Shi4 hong2se4 de5.', 'It is red.'],
    ],
    '书包是蓝色____。',
    '的',
    '的 completes this colour-description pattern.',
  ),
  _Draft(
    16,
    'What Is This?',
    'Ask and answer what an object is.',
    '这是什么？ asks “What is this?” Answer with 这是 plus the object. 什么 stays in the place where the missing information belongs.',
    [
      ['什么', 'shénme', 'shen2me5', 'what', 'question word'],
      ['这', 'zhè', 'zhe4', 'this', 'pronoun'],
      ['那', 'nà', 'na4', 'that', 'pronoun'],
      ['东西', 'dōngxi', 'dong1xi5', 'thing', 'noun'],
      ['书包', 'shūbāo', 'shu1bao1', 'school bag', 'noun'],
    ],
    [
      ['这是什么？', 'Zhè shì shénme?', 'Zhe4 shi4 shen2me5?', 'What is this?'],
      [
        '这是书包。',
        'Zhè shì shūbāo.',
        'Zhe4 shi4 shu1bao1.',
        'This is a school bag.',
      ],
    ],
    [
      '这 + 是 + 什么？',
      'Replace the unknown object with 什么.',
      '这是什么？',
      'Zhè shì shénme?',
      'Zhe4 shi4 shen2me5?',
      'What is this?',
    ],
    'ask and identify an object',
    'I can ask what an object is and answer.',
    [
      [
        'Mei',
        '这是什么？',
        'Zhè shì shénme?',
        'Zhe4 shi4 shen2me5?',
        'What is this?',
      ],
      [
        'Kai',
        '这是书包。',
        'Zhè shì shūbāo.',
        'Zhe4 shi4 shu1bao1.',
        'This is a school bag.',
      ],
    ],
    '这是____？',
    '什么',
    '什么 fills the unknown-object slot.',
  ),
  _Draft(
    17,
    'Food and Drinks',
    'Name beginner foods and drinks.',
    '米饭 is cooked rice and 面条 is noodles. 水 is water and 牛奶 is milk. These words can follow 吃 “eat” or 喝 “drink.”',
    [
      ['米饭', 'mǐfàn', 'mi3fan4', 'cooked rice', 'noun'],
      ['面条', 'miàntiáo', 'mian4tiao2', 'noodles', 'noun'],
      ['水', 'shuǐ', 'shui3', 'water', 'noun'],
      ['牛奶', 'niúnǎi', 'niu2nai3', 'milk', 'noun'],
      ['苹果', 'píngguǒ', 'ping2guo3', 'apple', 'noun', 'Classifier: 个 gè.'],
    ],
    [
      ['我吃米饭。', 'Wǒ chī mǐfàn.', 'Wo3 chi1 mi3fan4.', 'I eat rice.'],
      ['我喝水。', 'Wǒ hē shuǐ.', 'Wo3 he1 shui3.', 'I drink water.'],
    ],
    [
      '吃 + food / 喝 + drink',
      'Use 吃 for food and 喝 for drinks.',
      '我喝水。',
      'Wǒ hē shuǐ.',
      'Wo3 he1 shui3.',
      'I drink water.',
    ],
    'name simple foods and drinks',
    'I can identify food and choose 吃 or 喝.',
    [
      [
        'Kai',
        '你喝什么？',
        'Nǐ hē shénme?',
        'Ni3 he1 shen2me5?',
        'What do you drink?',
      ],
      ['Mei', '我喝牛奶。', 'Wǒ hē niúnǎi.', 'Wo3 he1 niu2nai3.', 'I drink milk.'],
    ],
    '我喝____。',
    '水',
    '水 is a drink and follows 喝.',
  ),
  _Draft(
    18,
    'I Like…',
    'Say what you like.',
    '喜欢 means “to like.” Put the person first, then 喜欢, then the liked thing or action. Mandarin does not change 喜欢 for different people.',
    [
      ['喜欢', 'xǐhuan', 'xi3huan5', 'to like', 'verb'],
      ['我', 'wǒ', 'wo3', 'I / me', 'pronoun'],
      ['苹果', 'píngguǒ', 'ping2guo3', 'apple', 'noun'],
      ['音乐', 'yīnyuè', 'yin1yue4', 'music', 'noun'],
      ['看书', 'kàn shū', 'kan4 shu1', 'read books', 'verb phrase'],
    ],
    [
      [
        '我喜欢苹果。',
        'Wǒ xǐhuan píngguǒ.',
        'Wo3 xi3huan5 ping2guo3.',
        'I like apples.',
      ],
      [
        '我喜欢看书。',
        'Wǒ xǐhuan kàn shū.',
        'Wo3 xi3huan5 kan4 shu1.',
        'I like reading books.',
      ],
    ],
    [
      'person + 喜欢 + thing/action',
      'Put what is liked after 喜欢.',
      '我喜欢音乐。',
      'Wǒ xǐhuan yīnyuè.',
      'Wo3 xi3huan5 yin1yue4.',
      'I like music.',
    ],
    'say what you like',
    'I can share one food or activity I like.',
    [
      [
        'Mei',
        '你喜欢什么？',
        'Nǐ xǐhuan shénme?',
        'Ni3 xi3huan5 shen2me5?',
        'What do you like?',
      ],
      [
        'Kai',
        '我喜欢音乐。',
        'Wǒ xǐhuan yīnyuè.',
        'Wo3 xi3huan5 yin1yue4.',
        'I like music.',
      ],
    ],
    '我____苹果。',
    '喜欢',
    '喜欢 goes between the person and liked thing.',
  ),
  _Draft(
    19,
    'I Don’t Like…',
    'Say what you do not like.',
    'Put 不 before 喜欢 to make 不喜欢, “do not like.” This gives a calm preference; use a kind voice when talking about someone else’s food or choice.',
    [
      ['不喜欢', 'bù xǐhuan', 'bu4 xi3huan5', 'do not like', 'verb phrase'],
      ['不', 'bù', 'bu4', 'not', 'adverb'],
      ['喜欢', 'xǐhuan', 'xi3huan5', 'to like', 'verb'],
      ['牛奶', 'niúnǎi', 'niu2nai3', 'milk', 'noun'],
      ['面条', 'miàntiáo', 'mian4tiao2', 'noodles', 'noun'],
    ],
    [
      [
        '我不喜欢牛奶。',
        'Wǒ bù xǐhuan niúnǎi.',
        'Wo3 bu4 xi3huan5 niu2nai3.',
        'I do not like milk.',
      ],
      [
        '他不喜欢面条。',
        'Tā bù xǐhuan miàntiáo.',
        'Ta1 bu4 xi3huan5 mian4tiao2.',
        'He does not like noodles.',
      ],
    ],
    [
      'person + 不 + verb',
      'Place 不 directly before the verb to make it negative.',
      '我不喜欢牛奶。',
      'Wǒ bù xǐhuan niúnǎi.',
      'Wo3 bu4 xi3huan5 niu2nai3.',
      'I do not like milk.',
    ],
    'state a dislike politely',
    'I can say what I do not like.',
    [
      [
        'Kai',
        '你喜欢牛奶吗？',
        'Nǐ xǐhuan niúnǎi ma?',
        'Ni3 xi3huan5 niu2nai3 ma5?',
        'Do you like milk?',
      ],
      [
        'Mei',
        '我不喜欢牛奶。',
        'Wǒ bù xǐhuan niúnǎi.',
        'Wo3 bu4 xi3huan5 niu2nai3.',
        'I do not like milk.',
      ],
    ],
    '我____喜欢牛奶。',
    '不',
    '不 before 喜欢 makes the sentence negative.',
  ),
  _Draft(
    20,
    'Module 2 Quest — Review and Assessment',
    'Combine Module 2 language in a quest.',
    'Use family, school, classroom, colour, food and preference words to solve this quest. Build short accurate sentences instead of rushing.',
    [
      ['家人', 'jiārén', 'jia1ren2', 'family members', 'noun'],
      ['学校', 'xuéxiào', 'xue2xiao4', 'school', 'noun'],
      ['书包', 'shūbāo', 'shu1bao1', 'school bag', 'noun'],
      ['蓝色', 'lánsè', 'lan2se4', 'blue', 'colour'],
      ['喜欢', 'xǐhuan', 'xi3huan5', 'to like', 'verb'],
    ],
    [
      [
        '这是我的蓝色书包。',
        'Zhè shì wǒ de lánsè shūbāo.',
        'Zhe4 shi4 wo3 de5 lan2se4 shu1bao1.',
        'This is my blue school bag.',
      ],
      [
        '我喜欢学校。',
        'Wǒ xǐhuan xuéxiào.',
        'Wo3 xi3huan5 xue2xiao4.',
        'I like school.',
      ],
    ],
    [
      '这是 + owner + 的 + description + noun',
      'Combine possession and colour before a noun.',
      '这是我的蓝色书包。',
      'Zhè shì wǒ de lánsè shūbāo.',
      'Zhe4 shi4 wo3 de5 lan2se4 shu1bao1.',
      'This is my blue school bag.',
    ],
    'combine familiar descriptions',
    'I can introduce and describe something in my world.',
    [
      [
        'Mei',
        '这是什么？',
        'Zhè shì shénme?',
        'Zhe4 shi4 shen2me5?',
        'What is this?',
      ],
      [
        'Kai',
        '这是我的蓝色书包。',
        'Zhè shì wǒ de lánsè shūbāo.',
        'Zhe4 shi4 wo3 de5 lan2se4 shu1bao1.',
        'This is my blue school bag.',
      ],
      [
        'Mei',
        '我喜欢蓝色！',
        'Wǒ xǐhuan lánsè!',
        'Wo3 xi3huan5 lan2se4!',
        'I like blue!',
      ],
    ],
    '这是我____书包。',
    '的',
    '的 links the owner 我 to 书包.',
  ),
  _Draft(
    21,
    'Good Morning and Other Greetings',
    'Use greetings for different moments.',
    '早上好 is used in the morning. 晚上好 is an evening greeting, and 晚安 is said when parting for sleep. Match the phrase to the moment.',
    [
      ['早上好', 'zǎoshang hǎo', 'zao3shang5 hao3', 'good morning', 'greeting'],
      ['下午好', 'xiàwǔ hǎo', 'xia4wu3 hao3', 'good afternoon', 'greeting'],
      ['晚上好', 'wǎnshang hǎo', 'wan3shang5 hao3', 'good evening', 'greeting'],
      ['晚安', 'wǎn’ān', 'wan3’an1', 'good night', 'greeting'],
      ['再见', 'zàijiàn', 'zai4jian4', 'goodbye', 'greeting'],
    ],
    [
      [
        '老师，早上好！',
        'Lǎoshī, zǎoshang hǎo!',
        'Lao3shi1, zao3shang5 hao3!',
        'Good morning, teacher!',
      ],
      ['妈妈，晚安！', 'Māma, wǎn’ān!', 'Ma1ma5, wan3’an1!', 'Good night, Mum!'],
    ],
    [
      'person/title + time greeting',
      'Put a name or title before the greeting to address someone.',
      '老师，早上好！',
      'Lǎoshī, zǎoshang hǎo!',
      'Lao3shi1, zao3shang5 hao3!',
      'Good morning, teacher!',
    ],
    'choose a time-appropriate greeting',
    'I can greet someone in the morning, afternoon or evening.',
    [
      ['Teacher', '早上好！', 'Zǎoshang hǎo!', 'Zao3shang5 hao3!', 'Good morning!'],
      [
        'Mei',
        '老师，早上好！',
        'Lǎoshī, zǎoshang hǎo!',
        'Lao3shi1, zao3shang5 hao3!',
        'Good morning, teacher!',
      ],
    ],
    '妈妈，____！',
    '晚安',
    '晚安 is the bedtime parting phrase.',
  ),
  _Draft(
    22,
    'Today and Tomorrow',
    'Talk about today and tomorrow.',
    '今天 means today and 明天 means tomorrow. Time words usually appear near the beginning, before the action.',
    [
      ['今天', 'jīntiān', 'jin1tian1', 'today', 'time word'],
      ['明天', 'míngtiān', 'ming2tian1', 'tomorrow', 'time word'],
      ['昨天', 'zuótiān', 'zuo2tian1', 'yesterday', 'time word'],
      ['现在', 'xiànzài', 'xian4zai4', 'now', 'time word'],
      ['见', 'jiàn', 'jian4', 'see / meet', 'verb'],
    ],
    [
      [
        '今天我在学校。',
        'Jīntiān wǒ zài xuéxiào.',
        'Jin1tian1 wo3 zai4 xue2xiao4.',
        'Today I am at school.',
      ],
      ['明天见！', 'Míngtiān jiàn!', 'Ming2tian1 jian4!', 'See you tomorrow!'],
    ],
    [
      'time + person + action',
      'Put the time before the person or action to set when it happens.',
      '明天我去学校。',
      'Míngtiān wǒ qù xuéxiào.',
      'Ming2tian1 wo3 qu4 xue2xiao4.',
      'Tomorrow I go to school.',
    ],
    'refer to today and tomorrow',
    'I can say when a simple event happens.',
    [
      [
        'Kai',
        '明天见！',
        'Míngtiān jiàn!',
        'Ming2tian1 jian4!',
        'See you tomorrow!',
      ],
      [
        'Mei',
        '明天见！',
        'Míngtiān jiàn!',
        'Ming2tian1 jian4!',
        'See you tomorrow!',
      ],
    ],
    '____见！',
    '明天',
    '明天见 means “See you tomorrow.”',
  ),
  _Draft(
    23,
    'Days of the Week',
    'Name the days of the week.',
    'Weekdays use 星期 plus a number: 星期一 is Monday. Sunday is commonly 星期天. Notice that the sequence begins with Monday as one.',
    [
      ['星期一', 'xīngqīyī', 'xing1qi1yi1', 'Monday', 'time word'],
      ['星期二', 'xīngqī’èr', 'xing1qi1’er4', 'Tuesday', 'time word'],
      ['星期三', 'xīngqīsān', 'xing1qi1san1', 'Wednesday', 'time word'],
      ['星期六', 'xīngqīliù', 'xing1qi1liu4', 'Saturday', 'time word'],
      ['星期天', 'xīngqītiān', 'xing1qi1tian1', 'Sunday', 'time word'],
    ],
    [
      [
        '今天星期一。',
        'Jīntiān xīngqīyī.',
        'Jin1tian1 xing1qi1yi1.',
        'Today is Monday.',
      ],
      [
        '明天星期二。',
        'Míngtiān xīngqī’èr.',
        'Ming2tian1 xing1qi1’er4.',
        'Tomorrow is Tuesday.',
      ],
    ],
    [
      '星期 + number',
      'Use numbers one through six after 星期 for Monday through Saturday.',
      '星期三',
      'xīngqīsān',
      'xing1qi1san1',
      'Wednesday',
    ],
    'name and identify weekdays',
    'I can name several days and say today’s day.',
    [
      [
        'Mei',
        '今天星期几？',
        'Jīntiān xīngqī jǐ?',
        'Jin1tian1 xing1qi1 ji3?',
        'What day is today?',
      ],
      [
        'Kai',
        '今天星期三。',
        'Jīntiān xīngqīsān.',
        'Jin1tian1 xing1qi1san1.',
        'Today is Wednesday.',
      ],
    ],
    '星期____',
    '三',
    '星期三 means Wednesday.',
  ),
  _Draft(
    24,
    'Where Are You Going?',
    'Ask and say where someone is going.',
    '你去哪儿？ asks where someone is going. 去 comes before the destination. 哪儿 is a friendly spoken word for “where.”',
    [
      ['去', 'qù', 'qu4', 'go', 'verb'],
      ['哪儿', 'nǎr', 'nar3', 'where', 'question word'],
      ['你', 'nǐ', 'ni3', 'you', 'pronoun'],
      ['我', 'wǒ', 'wo3', 'I / me', 'pronoun'],
      ['学校', 'xuéxiào', 'xue2xiao4', 'school', 'noun'],
    ],
    [
      ['你去哪儿？', 'Nǐ qù nǎr?', 'Ni3 qu4 nar3?', 'Where are you going?'],
      [
        '我去学校。',
        'Wǒ qù xuéxiào.',
        'Wo3 qu4 xue2xiao4.',
        'I am going to school.',
      ],
    ],
    [
      'person + 去 + destination',
      'Put the destination after 去. Replace it with 哪儿 to ask where.',
      '我去学校。',
      'Wǒ qù xuéxiào.',
      'Wo3 qu4 xue2xiao4.',
      'I am going to school.',
    ],
    'ask and state a destination',
    'I can ask where someone is going and answer.',
    [
      ['Mei', '你去哪儿？', 'Nǐ qù nǎr?', 'Ni3 qu4 nar3?', 'Where are you going?'],
      [
        'Kai',
        '我去学校。',
        'Wǒ qù xuéxiào.',
        'Wo3 qu4 xue2xiao4.',
        'I am going to school.',
      ],
    ],
    '我____学校。',
    '去',
    '去 goes before the destination.',
  ),
  _Draft(
    25,
    'Home, School and Other Places',
    'Name familiar places.',
    'Place words answer 哪儿. 家 is home, 学校 is school and 公园 is park. Add 去 before a place when it is your destination.',
    [
      ['家', 'jiā', 'jia1', 'home', 'noun'],
      ['学校', 'xuéxiào', 'xue2xiao4', 'school', 'noun'],
      ['公园', 'gōngyuán', 'gong1yuan2', 'park', 'noun'],
      ['商店', 'shāngdiàn', 'shang1dian4', 'shop', 'noun'],
      ['图书馆', 'túshūguǎn', 'tu2shu1guan3', 'library', 'noun'],
    ],
    [
      ['我在家。', 'Wǒ zài jiā.', 'Wo3 zai4 jia1.', 'I am at home.'],
      [
        '我们去公园。',
        'Wǒmen qù gōngyuán.',
        'Wo3men5 qu4 gong1yuan2.',
        'We are going to the park.',
      ],
    ],
    [
      '在 + place / 去 + place',
      '在 gives a current location; 去 gives a destination.',
      '我在图书馆。',
      'Wǒ zài túshūguǎn.',
      'Wo3 zai4 tu2shu1guan3.',
      'I am at the library.',
    ],
    'name a familiar location or destination',
    'I can say where I am or where I am going.',
    [
      ['Kai', '你在哪儿？', 'Nǐ zài nǎr?', 'Ni3 zai4 nar3?', 'Where are you?'],
      [
        'Mei',
        '我在图书馆。',
        'Wǒ zài túshūguǎn.',
        'Wo3 zai4 tu2shu1guan3.',
        'I am at the library.',
      ],
    ],
    '我在____。',
    '家',
    '家 completes “I am at home.”',
  ),
  _Draft(
    26,
    'Come, Go, Eat and Drink',
    'Use four everyday action verbs.',
    '来, 去, 吃 and 喝 are useful action verbs. Mandarin verbs do not change for I, you or they. Put the person before the verb.',
    [
      ['来', 'lái', 'lai2', 'come', 'verb'],
      ['去', 'qù', 'qu4', 'go', 'verb'],
      ['吃', 'chī', 'chi1', 'eat', 'verb'],
      ['喝', 'hē', 'he1', 'drink', 'verb'],
      ['水', 'shuǐ', 'shui3', 'water', 'noun'],
    ],
    [
      [
        '请来我家。',
        'Qǐng lái wǒ jiā.',
        'Qing3 lai2 wo3 jia1.',
        'Please come to my home.',
      ],
      ['我喝水。', 'Wǒ hē shuǐ.', 'Wo3 he1 shui3.', 'I drink water.'],
    ],
    [
      'person + verb + object/place',
      'Mandarin action sentences often follow who, action, then object or place.',
      '我喝水。',
      'Wǒ hē shuǐ.',
      'Wo3 he1 shui3.',
      'I drink water.',
    ],
    'use common action verbs',
    'I can understand and use come, go, eat and drink.',
    [
      ['Mum', '来吃饭！', 'Lái chīfàn!', 'Lai2 chi1fan4!', 'Come and eat!'],
      ['Kai', '好，我来！', 'Hǎo, wǒ lái!', 'Hao3, wo3 lai2!', 'Okay, I’m coming!'],
    ],
    '我____水。',
    '喝',
    '喝 is the verb used with a drink.',
  ),
  _Draft(
    27,
    'I Can…',
    'Say what you can do.',
    '会 before an action says you have learned how to do it. Use 我会 plus a skill. To say you cannot yet, use 不会.',
    [
      ['会', 'huì', 'hui4', 'can / know how to', 'modal verb'],
      [
        '不会',
        'bú huì',
        'bu2 hui4',
        'cannot / do not know how',
        'modal phrase',
        '不 changes to second tone before fourth-tone 会.',
      ],
      ['说', 'shuō', 'shuo1', 'speak', 'verb'],
      ['写', 'xiě', 'xie3', 'write', 'verb'],
      ['中文', 'Zhōngwén', 'Zhong1wen2', 'Chinese language', 'noun'],
    ],
    [
      [
        '我会说中文。',
        'Wǒ huì shuō Zhōngwén.',
        'Wo3 hui4 shuo1 Zhong1wen2.',
        'I can speak Chinese.',
      ],
      [
        '我会写“一”。',
        'Wǒ huì xiě “yī”.',
        'Wo3 hui4 xie3 “yi1”.',
        'I can write “one.”',
      ],
    ],
    [
      'person + 会 + action',
      'Put 会 before a learned skill.',
      '我会说中文。',
      'Wǒ huì shuō Zhōngwén.',
      'Wo3 hui4 shuo1 Zhong1wen2.',
      'I can speak Chinese.',
    ],
    'state a learned ability',
    'I can say one thing I know how to do.',
    [
      [
        'Teacher',
        '你会说中文吗？',
        'Nǐ huì shuō Zhōngwén ma?',
        'Ni3 hui4 shuo1 Zhong1wen2 ma5?',
        'Can you speak Chinese?',
      ],
      [
        'Mei',
        '会，我会说一点儿。',
        'Huì, wǒ huì shuō yìdiǎnr.',
        'Hui4, wo3 hui4 shuo1 yi4dian3r5.',
        'Yes, I can speak a little.',
      ],
    ],
    '我____说中文。',
    '会',
    '会 before the action expresses learned ability.',
  ),
  _Draft(
    28,
    'Please, Thank You and You’re Welcome',
    'Use essential polite phrases.',
    '请 makes a request polite. 谢谢 shows thanks. Reply with 不客气, “you’re welcome.” 对不起 and 没关系 help repair a small mistake.',
    [
      ['请', 'qǐng', 'qing3', 'please', 'polite word'],
      ['谢谢', 'xièxie', 'xie4xie5', 'thank you', 'polite phrase'],
      ['不客气', 'bú kèqi', 'bu2 ke4qi5', 'you’re welcome', 'polite phrase'],
      ['对不起', 'duìbuqǐ', 'dui4bu5qi3', 'sorry', 'polite phrase'],
      ['没关系', 'méi guānxi', 'mei2 guan1xi5', 'it is okay', 'polite phrase'],
    ],
    [
      ['请坐。', 'Qǐng zuò.', 'Qing3 zuo4.', 'Please sit.'],
      [
        '谢谢！不客气！',
        'Xièxie! Bú kèqi!',
        'Xie4xie5! Bu2 ke4qi5!',
        'Thank you! You’re welcome!',
      ],
    ],
    [
      '请 + request',
      'Put 请 before a request to make it polite.',
      '请喝水。',
      'Qǐng hē shuǐ.',
      'Qing3 he1 shui3.',
      'Please have some water.',
    ],
    'use polite phrases in context',
    'I can make a polite request, thank someone and respond.',
    [
      [
        'Mei',
        '请喝水。',
        'Qǐng hē shuǐ.',
        'Qing3 he1 shui3.',
        'Please have some water.',
      ],
      ['Kai', '谢谢！', 'Xièxie!', 'Xie4xie5!', 'Thank you!'],
      ['Mei', '不客气！', 'Bú kèqi!', 'Bu2 ke4qi5!', 'You’re welcome!'],
    ],
    '____坐。',
    '请',
    '请 before a request means “please.”',
  ),
  _Draft(
    29,
    'My First Mandarin Conversation',
    'Combine greetings and familiar language.',
    'A conversation is a chain of listening and replying. Use a greeting, exchange names, ask one simple question, then close politely.',
    [
      ['你好', 'nǐ hǎo', 'ni3 hao3', 'hello', 'greeting'],
      ['请问', 'qǐngwèn', 'qing3wen4', 'excuse me; may I ask', 'polite phrase'],
      ['名字', 'míngzi', 'ming2zi5', 'name', 'noun'],
      ['喜欢', 'xǐhuan', 'xi3huan5', 'to like', 'verb'],
      ['再见', 'zàijiàn', 'zai4jian4', 'goodbye', 'greeting'],
    ],
    [
      [
        '你好，我叫美美。',
        'Nǐ hǎo, wǒ jiào Měiměi.',
        'Ni3 hao3, wo3 jiao4 Mei3mei5.',
        'Hello, my name is Meimei.',
      ],
      [
        '请问，你喜欢什么？',
        'Qǐngwèn, nǐ xǐhuan shénme?',
        'Qing3wen4, ni3 xi3huan5 shen2me5?',
        'May I ask, what do you like?',
      ],
    ],
    [
      'greet → ask → answer → close',
      'Take turns and choose a reply that connects to the last question.',
      '你好！你叫什么名字？',
      'Nǐ hǎo! Nǐ jiào shénme míngzi?',
      'Ni3 hao3! Ni3 jiao4 shen2me5 ming2zi5?',
      'Hello! What is your name?',
    ],
    'take part in a short first conversation',
    'I can keep a beginner conversation going for several turns.',
    [
      [
        'Meimei',
        '你好！我叫美美。',
        'Nǐ hǎo! Wǒ jiào Měiměi.',
        'Ni3 hao3! Wo3 jiao4 Mei3mei5.',
        'Hello! My name is Meimei.',
      ],
      [
        'Kai',
        '你好，美美！我叫凯凯。',
        'Nǐ hǎo, Měiměi! Wǒ jiào Kǎikǎi.',
        'Ni3 hao3, Mei3mei5! Wo3 jiao4 Kai3kai5.',
        'Hello, Meimei! My name is Kaikai.',
      ],
      [
        'Meimei',
        '你喜欢什么？',
        'Nǐ xǐhuan shénme?',
        'Ni3 xi3huan5 shen2me5?',
        'What do you like?',
      ],
      [
        'Kai',
        '我喜欢看书。再见！',
        'Wǒ xǐhuan kàn shū. Zàijiàn!',
        'Wo3 xi3huan5 kan4 shu1. Zai4jian4!',
        'I like reading. Goodbye!',
      ],
    ],
    '你叫____名字？',
    '什么',
    '什么 asks for the missing information.',
  ),
  _Draft(
    30,
    'Mandarin Foundation Quest — Final Assessment',
    'Complete the final Foundation conversation.',
    'The final quest checks what you can do with familiar language. Listen for greetings, time, place, ability and politeness; then build clear short replies.',
    [
      ['早上好', 'zǎoshang hǎo', 'zao3shang5 hao3', 'good morning', 'greeting'],
      ['今天', 'jīntiān', 'jin1tian1', 'today', 'time word'],
      ['学校', 'xuéxiào', 'xue2xiao4', 'school', 'noun'],
      ['会', 'huì', 'hui4', 'can / know how to', 'modal verb'],
      ['谢谢', 'xièxie', 'xie4xie5', 'thank you', 'polite phrase'],
    ],
    [
      [
        '早上好！今天我去学校。',
        'Zǎoshang hǎo! Jīntiān wǒ qù xuéxiào.',
        'Zao3shang5 hao3! Jin1tian1 wo3 qu4 xue2xiao4.',
        'Good morning! Today I am going to school.',
      ],
      [
        '我会说一点儿中文。',
        'Wǒ huì shuō yìdiǎnr Zhōngwén.',
        'Wo3 hui4 shuo1 yi4dian3r5 Zhong1wen2.',
        'I can speak a little Chinese.',
      ],
    ],
    [
      'time + person + action + place',
      'Combine familiar chunks in the order time, person, action and place.',
      '今天我去学校。',
      'Jīntiān wǒ qù xuéxiào.',
      'Jin1tian1 wo3 qu4 xue2xiao4.',
      'Today I am going to school.',
    ],
    'complete a Foundation-level exchange',
    'I can greet, share information, ask and answer, and close politely.',
    [
      [
        'Teacher',
        '早上好！你去哪儿？',
        'Zǎoshang hǎo! Nǐ qù nǎr?',
        'Zao3shang5 hao3! Ni3 qu4 nar3?',
        'Good morning! Where are you going?',
      ],
      [
        'Mei',
        '早上好！我去学校。',
        'Zǎoshang hǎo! Wǒ qù xuéxiào.',
        'Zao3shang5 hao3! Wo3 qu4 xue2xiao4.',
        'Good morning! I am going to school.',
      ],
      [
        'Teacher',
        '你会说中文吗？',
        'Nǐ huì shuō Zhōngwén ma?',
        'Ni3 hui4 shuo1 Zhong1wen2 ma5?',
        'Can you speak Chinese?',
      ],
      [
        'Mei',
        '会一点儿。谢谢老师！',
        'Huì yìdiǎnr. Xièxie lǎoshī!',
        'Hui4 yi4dian3r5. Xie4xie5 lao3shi1!',
        'A little. Thank you, teacher!',
      ],
    ],
    '今天我____学校。',
    '去',
    '去 before 学校 gives the destination.',
  ),
];
