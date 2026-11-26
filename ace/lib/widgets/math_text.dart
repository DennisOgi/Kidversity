import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Text with inline LaTeX between single dollar signs, e.g.
/// "Solve $x^2-6x+8=0$." Falls back to the raw source if a formula fails to
/// parse, so a typo never blanks the page.
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const MathText(this.text, {super.key, this.style});

  static final _pattern = RegExp(r'\$([^$]+)\$');

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final tex = m.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            tex,
            textStyle: base,
            mathStyle: MathStyle.text,
            onErrorFallback: (_) => Text('\$$tex\$', style: base),
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// A single formula on its own line, e.g. a learner's typed working.
class MathBlock extends StatelessWidget {
  final String tex;
  final TextStyle? style;

  const MathBlock(this.tex, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        tex,
        textStyle: style ?? DefaultTextStyle.of(context).style,
        onErrorFallback: (e) => Text(
          tex,
          style: (style ?? const TextStyle()).copyWith(color: Colors.black54),
        ),
      ),
    );
  }
}
