import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class DashboardGuideStep {
  final IconData icon;
  final String title;
  final String body;

  const DashboardGuideStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// Compact, dismissible map of the main tabs. Shown once per role until closed.
class DashboardGuide extends StatefulWidget {
  final String storageKey;
  final String title;
  final String subtitle;
  final List<DashboardGuideStep> steps;
  final String? footer;

  const DashboardGuide._({
    super.key,
    required this.storageKey,
    required this.title,
    required this.subtitle,
    required this.steps,
    this.footer,
  });

  factory DashboardGuide.teacher({Key? key}) {
    return DashboardGuide._(
      key: key,
      storageKey: 'dashboard_guide_teacher_v1',
      title: 'How this dashboard works',
      subtitle: 'Four places. One class at a time.',
      footer:
          'Tip: create a class on Class, copy the code, and ask students to join from Me. On a phone, use Add to Home Screen to install Kidversity.',
      steps: const [
        DashboardGuideStep(
          icon: Icons.groups_rounded,
          title: 'Class',
          body:
              'Create your class, share the join code, and see who connected.',
        ),
        DashboardGuideStep(
          icon: Icons.insights_rounded,
          title: 'Progress',
          body: 'Watch Mandarin movement and who needs a check-in.',
        ),
        DashboardGuideStep(
          icon: Icons.assignment_rounded,
          title: 'Assign',
          body: 'Set work for the class and see who finished.',
        ),
        DashboardGuideStep(
          icon: Icons.bolt_rounded,
          title: 'Live',
          body: 'Run a short timed quiz while everyone is in the room.',
        ),
      ],
    );
  }

  factory DashboardGuide.student({Key? key}) {
    return DashboardGuide._(
      key: key,
      storageKey: 'dashboard_guide_student_v1',
      title: 'How Kidversity works for you',
      subtitle: 'Learn, practise, play, then join your class.',
      footer:
          'Tip: ask your teacher for the class code, then open Me → Join your class. On a phone, use Add to Home Screen to install Kidversity.',
      steps: const [
        DashboardGuideStep(
          icon: Icons.route_rounded,
          title: 'Home',
          body: 'Continue Mandarin and open the learning worlds.',
        ),
        DashboardGuideStep(
          icon: Icons.school_rounded,
          title: 'Practice',
          body: 'Review words, past questions, and mental maths.',
        ),
        DashboardGuideStep(
          icon: Icons.sports_esports_rounded,
          title: 'Play',
          body: 'Challenge classmates in Rope Pull.',
        ),
        DashboardGuideStep(
          icon: Icons.person_rounded,
          title: 'Me',
          body: 'Join your teacher’s class and manage your profile.',
        ),
      ],
    );
  }

  @override
  State<DashboardGuide> createState() => _DashboardGuideState();
}

class _DashboardGuideState extends State<DashboardGuide> {
  bool? _visible;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _visible = !(prefs.getBool(widget.storageKey) ?? false));
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.storageKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: _dismiss,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final step in widget.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SoftIcon(icon: step.icon, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title, style: text.titleSmall),
                          Text(
                            step.body,
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.inkSoft,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.footer != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.footer!,
                style: text.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                onPressed: _dismiss,
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
