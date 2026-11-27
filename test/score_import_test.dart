import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/core/sheet_reader.dart';
import 'package:kidversity/models/results_models.dart';
import 'package:kidversity/models/score_import.dart';

ClassPupilResults _pupil(String id, String name) => ClassPupilResults(
  studentId: id,
  displayName: name,
  avatarEmoji: '🦊',
  scores: const {},
);

const _maths = SchoolSubject('s-maths', 'Mathematics');
const _eng = SchoolSubject('s-eng', 'English');

final _cls = ClassResults(
  subjects: const [_maths, _eng],
  pupils: [
    _pupil('p1', 'Ada Obi'),
    _pupil('p2', 'Tunde Bello'),
    _pupil('p3', 'Chi Eze'),
    _pupil('p4', 'Chi Eze'),
  ],
);

Uint8List _xlsx() {
  final a = Archive();
  void add(String name, String xml) {
    final bytes = utf8.encode(xml);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add(
    'xl/workbook.xml',
    '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="Scores" sheetId="1" r:id="rId1"/></sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
  );
  add(
    'xl/sharedStrings.xml',
    '<sst><si><t>Pupil</t></si><si><t>Mathematics</t></si><si><t>Ada Obi</t></si></sst>',
  );
  add(
    'xl/worksheets/sheet1.xml',
    '<worksheet><sheetData>'
        '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="s"><v>1</v></c></row>'
        '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="C2"><v>87.5</v></c></row>'
        '<row r="3"><c r="A3" t="inlineStr"><is><t>Tunde Bello</t></is></c><c r="C3"><v>64</v></c></row>'
        '</sheetData></worksheet>',
  );
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  group('parseCsv', () {
    test('handles quotes, escaped quotes, CRLF and a BOM', () {
      final rows = parseCsv(
        '﻿Pupil,Note\r\n"Obi, Ada","She said ""hi"""\r\n\r\n',
      );
      expect(rows, [
        ['Pupil', 'Note'],
        ['Obi, Ada', 'She said "hi"'],
      ]);
    });

    test('detects semicolon separators', () {
      expect(parseCsv('Pupil;Mathematics\nAda Obi;71,5'), [
        ['Pupil', 'Mathematics'],
        ['Ada Obi', '71,5'],
      ]);
    });

    test('toCsv round-trips', () {
      final rows = [
        ['a,b', 'c"d', 'e'],
      ];
      expect(parseCsv(toCsv(rows)), rows);
    });
  });

  group('readSheet', () {
    test('reads xlsx shared and inline strings and keeps column gaps', () {
      final rows = readSheet(_xlsx(), 'scores.xlsx');
      expect(rows, [
        ['Pupil', '', 'Mathematics'],
        ['Ada Obi', '', '87.5'],
        ['Tunde Bello', '', '64'],
      ]);
    });

    test('rejects old .xls files with a clear message', () {
      expect(
        () => readSheet(Uint8List(4), 'old.xls'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ScoreImport.build', () {
    test('matches by name and ID and builds the payload', () {
      final imp = ScoreImport.build([
        ['Pupil', 'Pupil ID', 'mathematics', 'English', 'Art'],
        ['ada obi', '', '80', '72%', ''],
        ['Whoever', 'p2', '55', '61,5', ''],
      ], _cls);
      expect(imp.headerProblem, isNull);
      expect(imp.unknownColumns, ['Art']);
      expect(imp.problemCount, 0);
      expect(imp.canSave, isTrue);
      expect(imp.toPayload(), [
        {'student_id': 'p1', 'subject_id': 's-maths', 'score': 80.0},
        {'student_id': 'p1', 'subject_id': 's-eng', 'score': 72.0},
        {'student_id': 'p2', 'subject_id': 's-maths', 'score': 55.0},
        {'student_id': 'p2', 'subject_id': 's-eng', 'score': 61.5},
      ]);
    });

    test('flags unknown, ambiguous and duplicate pupils and bad values', () {
      final imp = ScoreImport.build([
        ['Pupil', 'Mathematics', 'English'],
        ['Nobody', '50', ''],
        ['Chi Eze', '50', ''],
        ['Ada Obi', 'abc', '101'],
        ['Ada Obi', '40', ''],
        ['', '', ''],
      ], _cls);
      expect(imp.rows.length, 4);
      expect(imp.problemCount, 4);
      expect(imp.canSave, isFalse);
      expect(imp.rows[0].problems.single, contains('No pupil'));
      expect(imp.rows[1].problems.single, contains('Two pupils'));
      expect(imp.rows[2].cellProblems.keys, containsAll(['s-maths', 's-eng']));
      expect(imp.rows[3].problems.single, contains('more than once'));
    });

    test('needs a pupil column and at least one subject', () {
      expect(
        ScoreImport.build([
          ['Mathematics'],
          ['50'],
        ], _cls).headerProblem,
        isNotNull,
      );
      expect(
        ScoreImport.build([
          ['Pupil', 'Art'],
          ['Ada Obi', '50'],
        ], _cls).headerProblem,
        isNotNull,
      );
      expect(ScoreImport.build(const [], _cls).canSave, isFalse);
    });

    test('template lists every pupil with their ID', () {
      final t = scoreTemplate(_cls);
      expect(t.first, ['Pupil', 'Pupil ID', 'Mathematics', 'English']);
      expect(t[1], ['Ada Obi', 'p1', '', '']);
      expect(t.length, 5);
    });
  });
}
