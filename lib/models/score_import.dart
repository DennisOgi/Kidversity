import 'results_models.dart';

/// Turns an uploaded sheet into scores for a class, flagging every problem
/// before anything is saved.
///
/// Expected layout (the downloadable template): a header row with "Pupil",
/// optionally "Pupil ID", then one column per subject. Pupils are matched by
/// ID first, then by name (case and spacing ignored). Blank cells are skipped.
class ScoreImport {
  final List<ImportRow> rows;
  final List<String> unknownColumns;
  final Map<int, SchoolSubject> subjectColumns;
  final String? headerProblem;

  const ScoreImport({
    required this.rows,
    required this.unknownColumns,
    required this.subjectColumns,
    this.headerProblem,
  });

  int get scoreCount => rows.fold(0, (n, r) => n + r.validScores.length);
  int get problemCount => rows.where((r) => r.problems.isNotEmpty).length;
  bool get canSave =>
      headerProblem == null && scoreCount > 0 && problemCount == 0;

  /// Rows ready for the server: student_id, subject_id, score.
  List<Map<String, Object>> toPayload() => [
    for (final r in rows)
      if (r.studentId != null)
        for (final e in r.validScores.entries)
          {'student_id': r.studentId!, 'subject_id': e.key, 'score': e.value},
  ];

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static ScoreImport build(List<List<String>> sheet, ClassResults cls) {
    if (sheet.isEmpty) {
      return const ScoreImport(
        rows: [],
        unknownColumns: [],
        subjectColumns: {},
        headerProblem: 'The file is empty.',
      );
    }
    final header = sheet.first;
    int? nameCol;
    int? idCol;
    final subjectCols = <int, SchoolSubject>{};
    final unknown = <String>[];
    final bySubject = {for (final s in cls.subjects) _norm(s.name): s};
    for (var i = 0; i < header.length; i++) {
      final h = _norm(header[i]);
      if (h.isEmpty) continue;
      if (h == 'pupil' ||
          h == 'name' ||
          h == 'student' ||
          h == 'pupil name' ||
          h == 'student name') {
        nameCol ??= i;
      } else if (h == 'pupil id' || h == 'student id' || h == 'id') {
        idCol ??= i;
      } else if (bySubject[h] != null) {
        subjectCols[i] = bySubject[h]!;
      } else {
        unknown.add(header[i]);
      }
    }
    if (nameCol == null && idCol == null) {
      return ScoreImport(
        rows: const [],
        unknownColumns: unknown,
        subjectColumns: subjectCols,
        headerProblem:
            'Add a "Pupil" column with each pupil\'s name. The template has one.',
      );
    }
    if (subjectCols.isEmpty) {
      return ScoreImport(
        rows: const [],
        unknownColumns: unknown,
        subjectColumns: subjectCols,
        headerProblem:
            'No column matches a subject in your school '
            '(${cls.subjects.map((s) => s.name).join(', ')}). Use the subject names as column headings.',
      );
    }

    final byId = {for (final p in cls.pupils) p.studentId: p};
    final byName = <String, List<ClassPupilResults>>{};
    for (final p in cls.pupils) {
      byName.putIfAbsent(_norm(p.displayName), () => []).add(p);
    }

    final rows = <ImportRow>[];
    final seen = <String>{};
    for (var r = 1; r < sheet.length; r++) {
      final line = sheet[r];
      String cell(int? i) => i != null && i < line.length ? line[i] : '';
      final name = cell(nameCol);
      final id = cell(idCol);
      final problems = <String>[];
      ClassPupilResults? pupil;
      if (id.isNotEmpty) {
        pupil = byId[id];
        if (pupil == null) problems.add('Pupil ID not in this class');
      } else if (name.isNotEmpty) {
        final matches = byName[_norm(name)] ?? const [];
        if (matches.length == 1) {
          pupil = matches.first;
        } else if (matches.isEmpty) {
          problems.add('No pupil called "$name" in this class');
        } else {
          problems.add(
            'Two pupils are called "$name". Add the Pupil ID column.',
          );
        }
      } else {
        continue; // fully blank identity: ignore the row
      }
      if (pupil != null && !seen.add(pupil.studentId)) {
        problems.add('${pupil.displayName} appears more than once');
      }

      final valid = <String, double>{};
      final cellProblems = <String, String>{};
      for (final e in subjectCols.entries) {
        final raw = cell(e.key).replaceAll('%', '').trim();
        if (raw.isEmpty) continue;
        // Accept a comma decimal ("71,5") from European-locale spreadsheets.
        final v = double.tryParse(
          RegExp(r'^\d+,\d+$').hasMatch(raw) ? raw.replaceAll(',', '.') : raw,
        );
        if (v == null) {
          cellProblems[e.value.id] = '"${cell(e.key)}" is not a number';
        } else if (v < 0 || v > 100) {
          cellProblems[e.value.id] = '$raw is outside 0–100';
        } else {
          valid[e.value.id] = v;
        }
      }
      problems.addAll(
        cellProblems.entries.map(
          (e) =>
              '${subjectCols.values.firstWhere((s) => s.id == e.key).name}: ${e.value}',
        ),
      );
      rows.add(
        ImportRow(
          line: r + 1,
          name: pupil?.displayName ?? (name.isEmpty ? id : name),
          studentId: pupil?.studentId,
          validScores: valid,
          cellProblems: cellProblems,
          problems: problems,
        ),
      );
    }
    return ScoreImport(
      rows: rows,
      unknownColumns: unknown,
      subjectColumns: subjectCols,
    );
  }
}

class ImportRow {
  final int line;
  final String name;
  final String? studentId;
  final Map<String, double> validScores;
  final Map<String, String> cellProblems;
  final List<String> problems;

  const ImportRow({
    required this.line,
    required this.name,
    required this.studentId,
    required this.validScores,
    required this.cellProblems,
    required this.problems,
  });
}

/// Template rows for a class: header plus one row per pupil.
List<List<String>> scoreTemplate(ClassResults cls) => [
  ['Pupil', 'Pupil ID', for (final s in cls.subjects) s.name],
  for (final p in cls.pupils)
    [p.displayName, p.studentId, for (final _ in cls.subjects) ''],
];
