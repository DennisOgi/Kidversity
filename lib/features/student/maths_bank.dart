import 'dart:math';

import '../../models/rope_pull_models.dart';
import '../../services/rope_pull_questions.dart';

class MathsLevel {
  final int sequence;
  final String title;
  final String detail;
  final String strand;

  const MathsLevel(this.sequence, this.title, this.detail, this.strand);
}

const mathsSumsPerLevel = 12;

/// About 70% correct clears a level, rounded up.
int mathsClearScore(int total) => (total * 7 / 10).ceil();

const mathsLevels = [
  MathsLevel(
    1,
    'Times 2–5',
    'The first tables, one product at a time.',
    'Number',
  ),
  MathsLevel(2, 'Times 6–9', 'The tables that usually stick last.', 'Number'),
  MathsLevel(3, 'Times 2–12', 'Mixed tables, still one step.', 'Number'),
  MathsLevel(
    4,
    'Add and subtract',
    'Within 100, including a carry or a borrow.',
    'Number',
  ),
  MathsLevel(
    5,
    'Mixed operations',
    'Multiply, divide, add, or subtract.',
    'Number',
  ),
  MathsLevel(
    6,
    'One-step problems',
    'A short story, then one calculation.',
    'Number',
  ),
  MathsLevel(
    7,
    'Fractions of amounts',
    'Half, thirds, quarters, and fifths of a number.',
    'Fractions',
  ),
  MathsLevel(
    8,
    'Percentages',
    '10%, 25%, 50%, and friends, worked in your head.',
    'Fractions',
  ),
  MathsLevel(
    9,
    'Ratio and sharing',
    'Split an amount in a ratio, then find a part.',
    'Fractions',
  ),
  MathsLevel(
    10,
    'Decimals',
    'Add, subtract, and multiply with tenths.',
    'Fractions',
  ),
  MathsLevel(
    11,
    'Order of operations',
    'Multiply and divide before you add.',
    'Number',
  ),
  MathsLevel(12, 'Integers', 'Add and subtract across zero.', 'Number'),
  MathsLevel(
    13,
    'Adding fractions',
    'Same denominator. The answer stays a fraction.',
    'Fractions',
  ),
  MathsLevel(
    14,
    'Percentage change',
    'A price goes up or down. Find the new amount.',
    'Fractions',
  ),
  MathsLevel(
    15,
    'Averages',
    'The mean of a short list of whole numbers.',
    'Data',
  ),
  MathsLevel(16, 'Money', 'Naira totals, change, and equal shares.', 'Measure'),
  MathsLevel(17, 'Time', 'Add minutes and read the new clock time.', 'Measure'),
  MathsLevel(
    18,
    'Area and perimeter',
    'Rectangles only. Units stay in the question.',
    'Measure',
  ),
  MathsLevel(
    19,
    'Find the number',
    'One-step equations. Solve for n.',
    'Algebra',
  ),
  MathsLevel(
    20,
    'Speed and distance',
    'Distance, speed, or time. One of the three is missing.',
    'Measure',
  ),
];

class MathsSum {
  final String prompt;
  final String answer;
  final List<String> options;

  const MathsSum({
    required this.prompt,
    required this.answer,
    required this.options,
  });
}

MathsSum makeMathsSum(int level, Random random) {
  return switch (level) {
    1 => _times(random, 2, 5),
    2 => _times(random, 6, 9),
    3 => _times(random, 2, 12),
    4 => _addSub(random),
    5 => random.nextBool() ? _times(random, 2, 12) : _addSub(random),
    6 => _worded(random),
    7 => _fractionOf(random),
    8 => _percentOf(random),
    9 => _ratio(random),
    10 => _decimals(random),
    11 => _orderOfOperations(random),
    12 => _integers(random),
    13 => _addFractions(random),
    14 => _percentChange(random),
    15 => _mean(random),
    16 => _money(random),
    17 => _clock(random),
    18 => _rectangle(random),
    19 => _equation(random),
    20 => _speed(random),
    _ => _decimals(random),
  };
}

MathsSum _fractionOf(Random random) {
  const fractions = [(1, 2), (1, 3), (2, 3), (1, 4), (3, 4), (1, 5), (2, 5)];
  final (top, bottom) = fractions[random.nextInt(fractions.length)];
  final whole = bottom * (2 + random.nextInt(11));
  return _choices(random, '$top/$bottom of $whole = ?', whole ~/ bottom * top);
}

MathsSum _percentOf(Random random) {
  const percents = [10, 20, 25, 50, 75, 5];
  final percent = percents[random.nextInt(percents.length)];
  final step = switch (percent) {
    25 || 75 => 4,
    5 => 20,
    20 => 5,
    50 => 2,
    _ => 10,
  };
  final whole = step * (2 + random.nextInt(15));
  return _choices(random, '$percent% of $whole = ?', whole * percent ~/ 100);
}

MathsSum _ratio(Random random) {
  final a = 1 + random.nextInt(4);
  final b = 1 + random.nextInt(5);
  final part = 2 + random.nextInt(9);
  final total = (a + b) * part;
  final askBigger = random.nextBool();
  final names = [
    ('Ada', 'Tunde'),
    ('Chidi', 'Zainab'),
    ('Mei', 'Kemi'),
  ][random.nextInt(3)];
  final who = askBigger ? names.$2 : names.$1;
  return _choices(
    random,
    'Share ₦$total between ${names.$1} and ${names.$2} in the ratio $a:$b. '
    'How much does $who get?',
    (askBigger ? b : a) * part,
  );
}

MathsSum _decimals(Random random) {
  final a = 1 + random.nextInt(90);
  final b = 1 + random.nextInt(40);
  final String prompt;
  final int tenths;
  switch (random.nextInt(3)) {
    case 0:
      prompt = '${_tenths(a)} + ${_tenths(b)} = ?';
      tenths = a + b;
    case 1:
      prompt = '${_tenths(a + b)} − ${_tenths(b)} = ?';
      tenths = a;
    default:
      final times = 2 + random.nextInt(8);
      prompt = '${_tenths(a)} × $times = ?';
      tenths = a * times;
  }
  final options = <int>{tenths};
  while (options.length < 4) {
    final delta = 1 + random.nextInt(10);
    final wrong = random.nextBool() ? tenths + delta : tenths - delta;
    if (wrong > 0) options.add(wrong);
    if (options.length < 4 && tenths >= 10) options.add(tenths + 10);
  }
  final labels = options.map(_tenths).toList()..shuffle(random);
  return MathsSum(prompt: prompt, answer: _tenths(tenths), options: labels);
}

String _tenths(int value) => '${value ~/ 10}.${value % 10}';

List<RopePullQuestion> buildMathsRopeDeck({int count = 20, int? seed}) {
  final random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
  final questions = <RopePullQuestion>[];
  for (var i = 0; i < count; i++) {
    final level = 1 + random.nextInt(mathsLevels.length);
    final sum = makeMathsSum(level, random);
    questions.add(
      RopePullQuestion(
        id: 'maths-$i',
        simplified: '',
        pinyin: '',
        english: '',
        options: sum.options,
        answer: sum.answer,
        prompt: sum.prompt,
      ),
    );
  }
  return packSplitDeck(questions, kind: 'maths', limit: count);
}

MathsSum _times(Random random, int low, int high) {
  final a = low + random.nextInt(high - low + 1);
  final b = 2 + random.nextInt(11);
  return _choices(random, '$a × $b = ?', a * b);
}

MathsSum _addSub(Random random) {
  final a = 12 + random.nextInt(70);
  final b = 4 + random.nextInt(28);
  if (random.nextBool()) {
    return _choices(random, '$a + $b = ?', a + b);
  }
  final high = a + b;
  return _choices(random, '$high − $b = ?', a);
}

MathsSum _worded(Random random) {
  final rows = 3 + random.nextInt(6);
  final each = 4 + random.nextInt(8);
  final stories = [
    ('A class sits in $rows rows of $each. How many seats?', rows * each),
    ('$each friends each bring $rows pencils. How many pencils?', each * rows),
    (
      'There are ${rows * each} mangoes in $rows equal bags. How many in one bag?',
      each,
    ),
  ];
  final story = stories[random.nextInt(stories.length)];
  return _choices(random, story.$1, story.$2);
}

MathsSum _orderOfOperations(Random random) {
  switch (random.nextInt(4)) {
    case 0:
      final a = 2 + random.nextInt(8);
      final b = 2 + random.nextInt(6);
      final c = 2 + random.nextInt(6);
      return _choices(random, '$a + $b × $c = ?', a + b * c);
    case 1:
      final b = 2 + random.nextInt(6);
      final c = 2 + random.nextInt(5);
      final a = b * c + 1 + random.nextInt(8);
      return _choices(random, '$a − $b × $c = ?', a - b * c);
    case 2:
      final a = 2 + random.nextInt(5);
      final b = 2 + random.nextInt(6);
      final c = 2 + random.nextInt(5);
      return _choices(random, '($a + $b) × $c = ?', (a + b) * c);
    default:
      final c = 2 + random.nextInt(6);
      final b = 2 + random.nextInt(5);
      final quotient = 2 + random.nextInt(6);
      return _choices(random, '${quotient * c} ÷ $c + $b = ?', quotient + b);
  }
}

MathsSum _integers(Random random) {
  final a = random.nextInt(13) - 6;
  final b = 1 + random.nextInt(9);
  if (random.nextBool()) {
    return _choices(random, '$a + $b = ?', a + b, allowNegative: true);
  }
  return _choices(random, '$a − $b = ?', a - b, allowNegative: true);
}

MathsSum _addFractions(Random random) {
  const denominators = [2, 3, 4, 5, 6, 8];
  final bottom = denominators[random.nextInt(denominators.length)];
  final left = 1 + random.nextInt(bottom - 1);
  final right = 1 + random.nextInt(bottom - left);
  final top = left + right;
  final answer = '$top/$bottom';
  final wrongs = <String>{
    '${top + 1}/$bottom',
    '${left}/$bottom',
    '$top/${bottom * 2}',
    '${top - 1}/$bottom',
    '$left/$right',
  }..remove(answer);
  return _labels(random, '$left/$bottom + $right/$bottom = ?', answer, wrongs);
}

MathsSum _percentChange(Random random) {
  const rates = [10, 20, 25, 50];
  final rate = rates[random.nextInt(rates.length)];
  final step = rate == 25 ? 4 : (100 ~/ rate);
  final base = step * (4 + random.nextInt(12));
  final delta = base * rate ~/ 100;
  final up = random.nextBool();
  return _choices(
    random,
    'A price of ₦$base ${up ? 'increases' : 'decreases'} by $rate%. '
    'What is the new price?',
    up ? base + delta : base - delta,
  );
}

MathsSum _mean(Random random) {
  final mean = 4 + random.nextInt(12);
  final spread = 1 + random.nextInt(4);
  final values = random.nextBool()
      ? [mean - spread, mean, mean + spread]
      : [mean - spread, mean - 1, mean + 1, mean + spread];
  values.shuffle(random);
  final shown = values.join(', ');
  return _choices(random, 'What is the mean of $shown?', mean);
}

MathsSum _money(Random random) {
  const notes = [200, 500, 1000, 2000];
  if (random.nextBool()) {
    final paid = notes[random.nextInt(notes.length)];
    final cost = 20 + random.nextInt((paid ~/ 10) - 2) * 10;
    return _choices(
      random,
      'You pay ₦$paid for something that costs ₦$cost. How much change?',
      paid - cost,
    );
  }
  final each = 50 + random.nextInt(16) * 25;
  final people = 2 + random.nextInt(4);
  return _choices(
    random,
    '$people people share ₦${each * people} equally. How much does each get?',
    each,
  );
}

MathsSum _clock(Random random) {
  final hour = 1 + random.nextInt(10);
  const minutes = [0, 10, 15, 20, 25, 30, 40, 45];
  const adds = [15, 20, 25, 30, 35, 40, 45, 50];
  final minute = minutes[random.nextInt(minutes.length)];
  final add = adds[random.nextInt(adds.length)];
  final total = hour * 60 + minute + add;
  final answer = _clockLabel(total ~/ 60, total % 60);
  final wrongs = <String>{
    _clockLabel(hour, (minute + add) % 60),
    _clockLabel(total ~/ 60, (total % 60 + 10) % 60),
    _clockLabel((total ~/ 60) % 12 + 1, total % 60),
    _clockLabel(hour + 1, minute),
  }..remove(answer);
  return _labels(
    random,
    'It is ${_clockLabel(hour, minute)}. What time is it $add minutes later?',
    answer,
    wrongs,
  );
}

String _clockLabel(int hour, int minute) =>
    '$hour:${minute.toString().padLeft(2, '0')}';

MathsSum _rectangle(Random random) {
  final width = 3 + random.nextInt(9);
  final height = 3 + random.nextInt(8);
  if (random.nextBool()) {
    return _choices(
      random,
      'A rectangle is ${width} cm by ${height} cm. What is its area in cm²?',
      width * height,
    );
  }
  return _choices(
    random,
    'A rectangle is ${width} cm by ${height} cm. What is its perimeter in cm?',
    2 * (width + height),
  );
}

MathsSum _equation(Random random) {
  final value = 2 + random.nextInt(18);
  switch (random.nextInt(3)) {
    case 0:
      final add = 2 + random.nextInt(12);
      return _choices(random, 'n + $add = ${value + add}. What is n?', value);
    case 1:
      final sub = 2 + random.nextInt(9);
      return _choices(random, 'n − $sub = $value. What is n?', value + sub);
    default:
      final times = 2 + random.nextInt(8);
      return _choices(
        random,
        '$times × n = ${value * times}. What is n?',
        value,
      );
  }
}

MathsSum _speed(Random random) {
  const speeds = [4, 5, 6, 8, 10, 12];
  final speed = speeds[random.nextInt(speeds.length)];
  final hours = 2 + random.nextInt(4);
  final distance = speed * hours;
  return switch (random.nextInt(3)) {
    0 => _choices(
      random,
      'A bus travels at $speed km/h for $hours hours. How far does it go?',
      distance,
    ),
    1 => _choices(
      random,
      'A bus travels $distance km in $hours hours. What is its speed in km/h?',
      speed,
    ),
    _ => _choices(
      random,
      'A bus travels $distance km at $speed km/h. How many hours does it take?',
      hours,
    ),
  };
}

MathsSum _labels(
  Random random,
  String prompt,
  String answer,
  Set<String> wrongs,
) {
  final options = <String>{answer};
  for (final wrong in wrongs) {
    if (wrong != answer && wrong.isNotEmpty) options.add(wrong);
    if (options.length == 4) break;
  }
  var extra = 1;
  while (options.length < 4 && extra < 12) {
    options.add('$answer+$extra');
    extra++;
  }
  final labels = options.toList()..shuffle(random);
  return MathsSum(prompt: prompt, answer: answer, options: labels);
}

MathsSum _choices(
  Random random,
  String prompt,
  int answer, {
  bool allowNegative = false,
}) {
  final options = <int>{answer};
  var guard = 0;
  while (options.length < 4 && guard < 40) {
    guard++;
    final delta = 1 + random.nextInt(12);
    final candidate = random.nextBool() ? answer + delta : answer - delta;
    if (candidate != answer && (allowNegative || candidate >= 0)) {
      options.add(candidate);
    }
  }
  if (options.length < 4) {
    options.add(answer + options.length + 3);
  }
  final labels = options.map((value) => '$value').toList()..shuffle(random);
  return MathsSum(prompt: prompt, answer: '$answer', options: labels);
}
