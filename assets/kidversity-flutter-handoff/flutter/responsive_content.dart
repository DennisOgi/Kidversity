import 'package:flutter/material.dart';
import 'kidversity_theme.dart';

/// Supply existing shell/body widgets. State belongs in the caller, outside branches.
/// This is a width boundary, not a router or replacement navigation architecture.
class KidversityResponsiveBody extends StatelessWidget {
  const KidversityResponsiveBody({
    super.key,
    required this.compactBuilder,
    required this.mediumBuilder,
    required this.expandedBuilder,
  });
  final WidgetBuilder compactBuilder;
  final WidgetBuilder mediumBuilder;
  final WidgetBuilder expandedBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < KvLayout.compactMax) return compactBuilder(context);
        if (constraints.maxWidth < KvLayout.expandedMin) return mediumBuilder(context);
        return expandedBuilder(context);
      });
}

/// Constrain the reading area inside the caller's scrolling widget.
class KidversityReadingColumn extends StatelessWidget {
  const KidversityReadingColumn({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: KvLayout.readingMax),
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      );
}
