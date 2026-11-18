/// Official school results: per subject, a teacher target, a baseline and the
/// scores recorded this term (all percentages).
library;

double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

enum ResultKind {
  baseline('Baseline'),
  test('Test'),
  exam('Exam');

  const ResultKind(this.label);
  final String label;

  static ResultKind parse(Object? raw) => switch (raw) {
    'baseline' => ResultKind.baseline,
    'exam' => ResultKind.exam,
    _ => ResultKind.test,
  };
}

class ResultEntry {
  final String id;
  final ResultKind kind;
  final String title;
  final double score;
  final DateTime? assessedOn;

  const ResultEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.score,
    this.assessedOn,
  });

  factory ResultEntry.fromJson(Map<String, dynamic> j) => ResultEntry(
    id: j['id'] as String,
    kind: ResultKind.parse(j['kind']),
    title: (j['title'] as String?) ?? '',
    score: _num(j['score']) ?? 0,
    assessedOn: DateTime.tryParse('${j['assessed_on']}'),
  );

  String get label => title.isNotEmpty ? title : kind.label;
}

/// Where a pupil stands against the target in one subject.
enum TargetStatus { noData, below, onTarget, above }

class SubjectProgress {
  final String subjectId;
  final String name;
  final double? target;
  final double? baseline;
  final double? latest;
  final List<ResultEntry> results;

  const SubjectProgress({
    required this.subjectId,
    required this.name,
    this.target,
    this.baseline,
    this.latest,
    this.results = const [],
  });

  factory SubjectProgress.fromJson(Map<String, dynamic> j) => SubjectProgress(
    subjectId: j['subject_id'] as String,
    name: (j['name'] as String?) ?? 'Subject',
    target: _num(j['target']),
    baseline: _num(j['baseline']),
    latest: _num(j['latest']),
    results: [
      for (final r in (j['results'] as List? ?? const []))
        ResultEntry.fromJson(Map<String, dynamic>.from(r as Map)),
    ],
  );

  /// Latest minus target, in percentage points.
  double? get gap =>
      latest == null || target == null ? null : latest! - target!;

  /// Latest minus baseline, in percentage points.
  double? get growth =>
      latest == null || baseline == null ? null : latest! - baseline!;

  TargetStatus get status => statusFor(latest, target);
}

TargetStatus statusFor(double? latest, double? target) {
  if (latest == null || target == null) return TargetStatus.noData;
  final gap = latest - target;
  if (gap < 0) return TargetStatus.below;
  if (gap < 5) return TargetStatus.onTarget;
  return TargetStatus.above;
}

/// 58.0 -> "58", 58.5 -> "58.5".
String fmtScore(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// "7 points below target", "2 points above target", "On target".
String gapLabel(double gap) {
  final points = fmtScore(gap.abs());
  final unit = gap.abs() == 1 ? 'point' : 'points';
  if (gap < 0) return '$points $unit below target';
  if (gap == 0) return 'On target';
  return '$points $unit above target';
}

class PupilProfile {
  final String studentId;
  final String displayName;
  final String avatarEmoji;
  final String? schoolName;
  final String? className;
  final String? termLabel;
  final bool canEdit;
  final int xp;
  final int level;
  final int streakDays;
  final int lessonsCompleted;
  final List<SubjectProgress> subjects;

  const PupilProfile({
    required this.studentId,
    required this.displayName,
    required this.avatarEmoji,
    required this.canEdit,
    required this.subjects,
    this.schoolName,
    this.className,
    this.termLabel,
    this.xp = 0,
    this.level = 1,
    this.streakDays = 0,
    this.lessonsCompleted = 0,
  });

  factory PupilProfile.fromJson(Map<String, dynamic> j) => PupilProfile(
    studentId: j['student_id'] as String,
    displayName: (j['display_name'] as String?) ?? 'Learner',
    avatarEmoji: (j['avatar_emoji'] as String?) ?? '🦊',
    schoolName: j['school_name'] as String?,
    className: j['class_name'] as String?,
    termLabel: j['term_label'] as String?,
    canEdit: j['can_edit'] == true,
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    level: (j['level'] as num?)?.toInt() ?? 1,
    streakDays: (j['streak_days'] as num?)?.toInt() ?? 0,
    lessonsCompleted: (j['lessons_completed'] as num?)?.toInt() ?? 0,
    subjects: [
      for (final s in (j['subjects'] as List? ?? const []))
        SubjectProgress.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );

  /// Subjects with a score below target.
  int get needsSupport =>
      subjects.where((s) => s.status == TargetStatus.below).length;
}

class SchoolSubject {
  final String id;
  final String name;

  const SchoolSubject(this.id, this.name);
}

class ScoreCell {
  final double? target;
  final double? latest;

  const ScoreCell({this.target, this.latest});

  TargetStatus get status => statusFor(latest, target);
}

class ClassPupilResults {
  final String studentId;
  final String displayName;
  final String avatarEmoji;
  final Map<String, ScoreCell> scores;

  const ClassPupilResults({
    required this.studentId,
    required this.displayName,
    required this.avatarEmoji,
    required this.scores,
  });

  bool get needsSupport =>
      scores.values.any((c) => c.status == TargetStatus.below);
}

class ClassResults {
  final String? termLabel;
  final List<SchoolSubject> subjects;
  final List<ClassPupilResults> pupils;

  const ClassResults({
    required this.subjects,
    required this.pupils,
    this.termLabel,
  });

  factory ClassResults.fromJson(Map<String, dynamic> j) => ClassResults(
    termLabel: j['term_label'] as String?,
    subjects: [
      for (final s in (j['subjects'] as List? ?? const []))
        SchoolSubject((s as Map)['id'] as String, s['name'] as String),
    ],
    pupils: [
      for (final p in (j['pupils'] as List? ?? const []))
        ClassPupilResults(
          studentId: (p as Map)['student_id'] as String,
          displayName: (p['display_name'] as String?) ?? 'Learner',
          avatarEmoji: (p['avatar_emoji'] as String?) ?? '🦊',
          scores: {
            for (final e in Map<String, dynamic>.from(
              p['scores'] as Map? ?? const {},
            ).entries)
              e.key: ScoreCell(
                target: _num((e.value as Map)['target']),
                latest: _num((e.value as Map)['latest']),
              ),
          },
        ),
    ],
  );

  int get needSupport => pupils.where((p) => p.needsSupport).length;
}
