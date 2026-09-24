import '../../models/learning_records_models.dart';
import '../student/maths_bank.dart';

const foundationLessonCount = 30;

String dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

/// Plain-language suggestions, strongest signal first.
List<String> reportNextSteps(ProgressReport report) {
  final steps = <String>[];
  final weak = report.subjects.where(
    (s) => s.questions >= 10 && s.averagePercent < 60,
  );
  for (final subject in weak.take(2)) {
    steps.add(
      '${subject.label} is averaging ${subject.averagePercent}%. '
      'A mistakes retry and one Quick 10 a day will lift it.',
    );
  }
  if (report.openMistakes > 0) {
    steps.add(
      '${report.openMistakes} missed exam questions are waiting in the mistakes list.',
    );
  }
  if (report.lessonsDone == 0) {
    steps.add('Start Mandarin Lesson 1. Each lesson takes about fifteen minutes.');
  } else if (report.lessonsDone < foundationLessonCount) {
    steps.add(
      'Continue Mandarin: ${foundationLessonCount - report.lessonsDone} lessons left in the Foundation path.',
    );
  }
  final passed = report.mathsLevelsPassed;
  for (final level in mathsLevels) {
    if (!passed.contains(level.sequence)) {
      steps.add('Maths: clear level ${level.sequence}, ${level.title}.');
      break;
    }
  }
  if (report.activeDaysThisWeek() < 3) {
    steps.add('Aim for three short sessions this week. Little and often beats one long cram.');
  }
  if (steps.isEmpty) {
    steps.add('Everything is on track. Try a Timed mock to practise exam pacing.');
  }
  return steps;
}

String _esc(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// A standalone page parents can print or save as PDF from the browser.
String reportHtml(
  ProgressReport report, {
  Map<String, String> lessonTitles = const {},
  String? className,
}) {
  final b = StringBuffer();
  String stat(String label, String value, String detail) =>
      '<div class="stat"><div class="label">${_esc(label)}</div>'
      '<div class="value">${_esc(value)}</div>'
      '<div class="detail">${_esc(detail)}</div></div>';

  b.write('''<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>${_esc(report.name)} · Kidversity progress report</title>
<style>
body{font-family:"DM Sans",system-ui,-apple-system,Segoe UI,sans-serif;color:#15122b;margin:0;background:#f5f6fb}
.page{max-width:820px;margin:24px auto;background:#fff;padding:40px 44px;border-radius:16px}
h1{font-size:26px;margin:0 0 4px}h2{font-size:17px;margin:28px 0 10px;color:#4433CC}
.muted{color:#5b5875}.brand{color:#4433CC;font-weight:800;letter-spacing:.5px}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-top:20px}
.stat{border:1px solid #e3e2ef;border-radius:12px;padding:14px}
.label{font-size:12px;color:#5b5875;text-transform:uppercase;letter-spacing:.6px}
.value{font-size:24px;font-weight:800;margin:6px 0 2px}.detail{font-size:13px;color:#5b5875}
table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:8px 6px;border-bottom:1px solid #eeedf5}
th{font-size:12px;color:#5b5875;text-transform:uppercase;letter-spacing:.5px}
li{margin:6px 0}.actions{text-align:right;margin-bottom:12px}
button{background:#4433CC;color:#fff;border:0;border-radius:8px;padding:10px 16px;font-weight:700;cursor:pointer}
@media print{body{background:#fff}.page{margin:0;padding:0}.actions{display:none}}
</style></head><body><div class="page">
<div class="actions"><button onclick="window.print()">Print or save as PDF</button></div>
<div class="brand">KIDVERSITY</div>
<h1>${_esc(report.name)}</h1>
<div class="muted">Progress report · ${dateLabel(report.generatedAt)}${className == null ? '' : ' · ${_esc(className)}'}</div>
<div class="stats">''');
  b.write(stat(
    'Mandarin',
    '${report.lessonsDone}/$foundationLessonCount',
    report.lessons.isEmpty ? 'Not started' : 'lessons · avg ${report.lessonAverage}%',
  ));
  b.write(stat(
    'Exam practice',
    report.attempts.isEmpty ? '—' : '${report.examAverage}%',
    '${report.examQuestions} questions · ${report.attempts.length} sessions',
  ));
  b.write(stat(
    'Maths',
    '${report.mathsLevelsPassed.length}/${mathsLevels.length}',
    report.maths.isEmpty ? 'Not started' : 'levels cleared · avg ${report.mathsAverage}%',
  ));
  b.write(stat(
    'This week',
    '${report.activeDaysThisWeek()}',
    'active days',
  ));
  b.write('</div>');

  b.write('<h2>Suggested next steps</h2><ul>');
  for (final step in reportNextSteps(report)) {
    b.write('<li>${_esc(step)}</li>');
  }
  b.write('</ul>');

  final subjects = report.subjects;
  if (subjects.isNotEmpty) {
    b.write('<h2>Exam subjects</h2><table><tr><th>Paper</th><th>Sessions</th>'
        '<th>Questions</th><th>Average</th><th>Best</th></tr>');
    for (final s in subjects) {
      b.write('<tr><td>${_esc(s.label)}</td><td>${s.attempts}</td>'
          '<td>${s.questions}</td><td>${s.averagePercent}%</td>'
          '<td>${s.bestPercent}%</td></tr>');
    }
    b.write('</table>');
  }

  if (report.attempts.isNotEmpty) {
    b.write('<h2>Recent exam sessions</h2><table><tr><th>Date</th><th>Paper</th>'
        '<th>Mode</th><th>Score</th></tr>');
    for (final a in report.attempts.take(10)) {
      b.write('<tr><td>${dateLabel(a.createdAt)}</td><td>${_esc(a.headline)}</td>'
          '<td>${_esc(a.modeLabel)}</td><td>${a.correct}/${a.total} (${a.percent}%)</td></tr>');
    }
    b.write('</table>');
  }

  if (report.lessons.isNotEmpty) {
    final lessons = [...report.lessons]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    b.write('<h2>Mandarin lessons</h2><table><tr><th>Date</th><th>Lesson</th><th>Score</th></tr>');
    for (final l in lessons.take(10)) {
      b.write('<tr><td>${dateLabel(l.completedAt)}</td>'
          '<td>${_esc(lessonTitles[l.lessonId] ?? l.lessonId)}</td><td>${l.score}%</td></tr>');
    }
    b.write('</table>');
  }

  if (report.maths.isNotEmpty) {
    b.write('<h2>Maths levels cleared</h2><p>');
    final names = [
      for (final level in mathsLevels)
        if (report.mathsLevelsPassed.contains(level.sequence))
          '${level.sequence}. ${level.title}',
    ];
    b.write(names.isEmpty ? 'None yet. Seven of ten right clears a level.' : _esc(names.join(' · ')));
    b.write('</p>');
  }

  b.write('<p class="muted" style="margin-top:32px;font-size:12px">'
      'Generated by Kidversity from saved lessons, exam sessions, and maths drills.</p>'
      '</div></body></html>');
  return b.toString();
}
