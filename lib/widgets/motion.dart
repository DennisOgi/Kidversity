import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Plays a subtle fade + slide-up entrance the first time the widget mounts.
/// Use [delay] to stagger a list of items for a polished cascade.
class FadeInUp extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  const FadeInUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offset = 26,
  });

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween(
    begin: Offset(0, widget.offset / 100),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  Timer? _stallCheck;
  Timer? _delayed;

  @override
  void initState() {
    super.initState();
    // Web often misses animation ticks until the next click, which leaves
    // whole panels looking washed out. Show them sharp immediately.
    if (kIsWeb) {
      _c.value = 1;
      return;
    }
    final wait = widget.delay + widget.duration + const Duration(milliseconds: 120);
    _stallCheck = Timer(wait, () {
      if (!mounted || _c.isCompleted) return;
      debugPrint(
        '[Kidversity] FadeInUp stalled at ${_c.value.toStringAsFixed(2)}; snapping to full opacity',
      );
      _c.value = 1;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb || MediaQuery.disableAnimationsOf(context)) {
      if (_c.value < 1) _c.value = 1;
      return;
    }
    // Animations started while a tab was offstage stay at opacity 0 until retried.
    if (_c.value == 0 && !_c.isAnimating) {
      _scheduleForward();
    }
  }

  void _scheduleForward() {
    void run() {
      if (!mounted || _c.isAnimating || _c.isCompleted) return;
      _c.forward(from: 0);
    }

    if (widget.delay == Duration.zero) {
      run();
    } else {
      _delayed?.cancel();
      _delayed = Timer(widget.delay, run);
    }
  }

  @override
  void dispose() {
    _stallCheck?.cancel();
    _delayed?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _c.isCompleted || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    // A zero fade means the ticker has not started. Paint the child sharp
    // rather than a translucent layer that can stick until the next click.
    if (_fade.value <= 0) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Wraps a vertical list of children in staggered [FadeInUp] entrances.
class StaggerColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final Duration step;
  final Duration initialDelay;

  const StaggerColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.step = const Duration(milliseconds: 70),
    this.initialDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (int i = 0; i < children.length; i++)
          FadeInUp(delay: initialDelay + step * i, child: children[i]),
      ],
    );
  }
}

/// Builds staggered entrance children for use inside a sliver list.
List<Widget> staggerList(
  List<Widget> children, {
  Duration step = const Duration(milliseconds: 70),
  Duration initialDelay = Duration.zero,
}) {
  return [
    for (int i = 0; i < children.length; i++)
      FadeInUp(delay: initialDelay + step * i, child: children[i]),
  ];
}
