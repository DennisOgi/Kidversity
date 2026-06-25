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

class _FadeInUpState extends State<FadeInUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(
    begin: Offset(0, widget.offset / 100),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _scheduleForward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      Future.delayed(widget.delay, () {
        if (mounted) run();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Never leave content fully transparent — offstage tabs can miss the first animation tick.
    final opacity = _c.isCompleted ? 1.0 : _fade.value.clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity > 0 ? opacity : 1.0,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
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
List<Widget> staggerList(List<Widget> children,
    {Duration step = const Duration(milliseconds: 70), Duration initialDelay = Duration.zero}) {
  return [
    for (int i = 0; i < children.length; i++)
      FadeInUp(delay: initialDelay + step * i, child: children[i]),
  ];
}
