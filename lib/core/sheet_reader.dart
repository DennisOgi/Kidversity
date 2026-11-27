import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads the first sheet of an .xlsx file or a .csv file into rows of
/// trimmed cell text. Throws [FormatException] with a plain message when the
/// file cannot be read.
List<List<String>> readSheet(Uint8List bytes, String fileName) {
  final name = fileName.toLowerCase();
  if (name.endsWith('.xlsx')) return _readXlsx(bytes);
  if (name.endsWith('.csv') || name.endsWith('.txt')) {
    return parseCsv(utf8.decode(bytes, allowMalformed: true));
  }
  if (name.endsWith('.xls')) {
    throw const FormatException(
      'Old .xls files are not supported. In Excel, choose Save As > Excel Workbook (.xlsx) or CSV.',
    );
  }
  throw const FormatException('Upload an Excel (.xlsx) or CSV (.csv) file.');
}

/// RFC 4180 CSV: quoted fields, doubled quotes, commas and newlines inside
/// quotes. Also accepts semicolon-separated files (common in some locales).
List<List<String>> parseCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final sep = firstLine.split(';').length > firstLine.split(',').length
      ? ';'
      : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
      continue;
    }
    if (c == '"') {
      quoted = true;
    } else if (c == sep) {
      row.add(field.toString().trim());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString().trim());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString().trim());
    rows.add(row);
  }
  return rows.where((r) => r.any((c) => c.isNotEmpty)).toList();
}

/// Writes rows as CSV, quoting where needed.
String toCsv(List<List<String>> rows) => rows
    .map(
      (r) => r
          .map(
            (c) => c.contains(RegExp(r'[",\n\r]'))
                ? '"${c.replaceAll('"', '""')}"'
                : c,
          )
          .join(','),
    )
    .join('\r\n');

List<List<String>> _readXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException(
      'That file could not be opened as an Excel workbook.',
    );
  }
  String? text(String path) {
    final f = zip.findFile(path);
    return f == null
        ? null
        : utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final shared = <String>[];
  final sharedXml = text('xl/sharedStrings.xml');
  if (sharedXml != null) {
    for (final si in XmlDocument.parse(sharedXml).findAllElements('si')) {
      shared.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  // First sheet in workbook order.
  var sheetPath = 'xl/worksheets/sheet1.xml';
  final wb = text('xl/workbook.xml');
  final rels = text('xl/_rels/workbook.xml.rels');
  if (wb != null && rels != null) {
    final first = XmlDocument.parse(wb).findAllElements('sheet').firstOrNull;
    final rid =
        first?.getAttribute('r:id') ??
        first?.attributes.where((a) => a.name.local == 'id').firstOrNull?.value;
    if (rid != null) {
      for (final r in XmlDocument.parse(rels).findAllElements('Relationship')) {
        if (r.getAttribute('Id') == rid) {
          final target = r.getAttribute('Target') ?? '';
          sheetPath = target.startsWith('/')
              ? target.substring(1)
              : 'xl/$target';
        }
      }
    }
  }
  final sheet = text(sheetPath);
  if (sheet == null) throw const FormatException('The workbook has no sheets.');

  final rows = <List<String>>[];
  for (final r in XmlDocument.parse(sheet).findAllElements('row')) {
    final cells = <int, String>{};
    var next = 0;
    for (final c in r.findElements('c')) {
      final ref = c.getAttribute('r');
      final col = ref == null ? next : _colIndex(ref);
      next = col + 1;
      final type = c.getAttribute('t');
      String value;
      if (type == 'inlineStr') {
        value = c.findAllElements('t').map((t) => t.innerText).join();
      } else {
        final v = c.findElements('v').firstOrNull?.innerText ?? '';
        if (type == 's') {
          final i = int.tryParse(v);
          value = i != null && i < shared.length ? shared[i] : '';
        } else {
          value = v;
        }
      }
      cells[col] = value.trim();
    }
    if (cells.isEmpty) continue;
    final width = cells.keys.reduce((a, b) => a > b ? a : b) + 1;
    final row = [for (var i = 0; i < width; i++) cells[i] ?? ''];
    if (row.any((c) => c.isNotEmpty)) rows.add(row);
  }
  return rows;
}

int _colIndex(String ref) {
  var n = 0;
  for (final ch in ref.codeUnits) {
    if (ch < 65 || ch > 90) break;
    n = n * 26 + (ch - 64);
  }
  return n - 1;
}
