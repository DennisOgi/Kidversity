import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/models.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/motion.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _avatars = ['🦊', '🦁', '🐼', '🐯', '🐨', '🐸', '🦄', '🐙'];

  final _name = TextEditingController();
  int _step = 0;
  String _emoji = '🦊';
  UserRole? _role;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    if (auth.displayName.isNotEmpty) _name.text = auth.displayName;
    if (auth.avatarEmoji.isNotEmpty) _emoji = auth.avatarEmoji;
    _role = auth.role;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final redirect = GoRouter.maybeOf(
        context,
      )?.state.uri.queryParameters['redirect'];
      final preset = roleFromPath(redirect);
      final provisionedRole = ref.read(authControllerProvider).role;
      if (preset != null &&
          (preset != UserRole.reviewer ||
              provisionedRole == UserRole.reviewer)) {
        setState(() => _role = preset);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _redirect =>
      GoRouter.maybeOf(context)?.state.uri.queryParameters['redirect'];

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _name.text.trim().isNotEmpty;
      case 1:
        return _emoji.isNotEmpty;
      case 2:
        return _role != null;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _next() {
    if (!_canContinue) return;
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    _finish();
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  Future<void> _finish() async {
    if (_role == null || _busy) return;
    if (_role == UserRole.reviewer &&
        ref.read(authControllerProvider).role != UserRole.reviewer) {
      context.showErrorSnackbar('Reviewer access is available by invitation.');
      setState(() => _role = null);
      return;
    }

    setState(() => _busy = true);

    try {
      final name = _name.text.trim();
      final redirect = _redirect;
      final role = _role ?? roleFromPath(redirect);

      await ref
          .read(authControllerProvider)
          .completeOnboarding(name: name, emoji: _emoji, selectedRole: role);

      if (role != null) {
        ref.read(roleProvider.notifier).state = role;
      }

      if (!mounted) return;

      final destination =
          redirect ??
          (role == UserRole.teacher
              ? AppRoutes.teacherHome
              : role == UserRole.reviewer
              ? AppRoutes.reviewerHome
              : role == UserRole.student
              ? AppRoutes.studentPath
              : AppRoutes.home);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(destination);
      });
    } catch (_) {
      if (mounted) {
        context.showErrorSnackbar(
          'We could not save your choices. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width > 900;
    final stepTitles = [
      ('Welcome to the path', 'What should your Mandarin guide call you?'),
      (
        'Choose your companion',
        'Pick the character that will travel with you.',
      ),
      ('Choose your space', 'Your role shapes the experience you see next.'),
      (
        'How a lesson works',
        'You will see this same pattern in every Foundation lesson.',
      ),
    ];

    final setupCard = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 570),
      child: GlassCard(
        color: AppColors.surface.withValues(alpha: 0.96),
        padding: EdgeInsets.fromLTRB(wide ? 32 : 22, 26, wide ? 32 : 22, 28),
        shadow: AppTheme.softShadow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cinnabar,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Text(
                    '学',
                    style: TextStyle(
                      color: AppColors.paper,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MANDARIN FOUNDATION',
                        style: TextStyle(
                          color: AppColors.cinnabar,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Set up your journey',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_step + 1} / 4',
                  style: text.labelLarge?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              stepTitles[_step].$1,
              style: text.headlineSmall?.copyWith(fontSize: wide ? 30 : 26),
            ),
            const SizedBox(height: 6),
            Text(stepTitles[_step].$2, style: text.bodyMedium),
            const SizedBox(height: 22),
            _StepDots(step: _step),
            const SizedBox(height: 26),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: switch (_step) {
                0 => _NameStep(
                  key: const ValueKey('name'),
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                ),
                1 => _AvatarStep(
                  key: const ValueKey('avatar'),
                  selected: _emoji,
                  options: _avatars,
                  onSelect: (emoji) => setState(() => _emoji = emoji),
                ),
                2 => _RoleStep(
                  key: const ValueKey('role'),
                  selected: _role,
                  allowReviewer:
                      ref.watch(authControllerProvider).role ==
                      UserRole.reviewer,
                  onSelect: (role) => setState(() => _role = role),
                ),
                _ => _HowItWorksStep(
                  key: const ValueKey('howto'),
                  role: _role,
                ),
              },
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                if (_step > 0)
                  TextButton.icon(
                    onPressed: _busy ? null : _back,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  )
                else
                  const Spacer(),
                const Spacer(),
                GradientButton(
                  label: _busy
                      ? 'Saving…'
                      : (_step < 3 ? 'Continue' : 'Enter Kidversity'),
                  icon: _step < 3
                      ? Icons.arrow_forward_rounded
                      : Icons.auto_awesome_rounded,
                  onTap: (_busy || !_canContinue) ? null : _next,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: _OnboardingBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 58 : 20,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Center(
                  child: FadeInUp(
                    child: wide
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _OnboardingPreview(
                                  step: _step,
                                  avatar: _emoji,
                                  role: _role,
                                ),
                              ),
                              const SizedBox(width: 54),
                              Expanded(child: setupCard),
                            ],
                          )
                        : setupCard,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  final Widget child;

  const _OnboardingBackdrop({required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFAF3), AppColors.paper, Color(0xFFE8F0EB)],
          ),
        ),
      ),
      Positioned(
        left: -120,
        top: -100,
        child: Container(
          width: 360,
          height: 360,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cinnabar.withValues(alpha: 0.07),
          ),
        ),
      ),
      Positioned(
        right: -90,
        bottom: -120,
        child: Container(
          width: 330,
          height: 330,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.jade.withValues(alpha: 0.08),
          ),
        ),
      ),
      child,
    ],
  );
}

class _OnboardingPreview extends StatelessWidget {
  final int step;
  final String avatar;
  final UserRole? role;

  const _OnboardingPreview({
    required this.step,
    required this.avatar,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (role) {
      UserRole.student => 'Learner path',
      UserRole.teacher => 'Class coach',
      UserRole.reviewer => 'Language reviewer',
      null => 'Choose your role',
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '你好，WELCOME',
            style: TextStyle(
              color: AppColors.cinnabar,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your first Mandarin\njourney starts here.',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: AppColors.ink,
              fontSize: 44,
              height: 1.03,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'A focused 30-lesson course with clear audio, playful practice, '
            'and carefully reviewed Mandarin.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.inkSoft,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.mandarinGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: EmojiText(
                      avatar,
                      key: ValueKey(avatar),
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roleLabel,
                        style: const TextStyle(
                          color: AppColors.paper,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        step == 0
                            ? 'Tell us who is joining.'
                            : step == 1
                            ? 'Your companion is ready.'
                            : step == 2
                            ? 'We’ll open the right workspace.'
                            : 'Then the Path shows one lesson at a time.',
                        style: TextStyle(
                          color: AppColors.paper.withValues(alpha: 0.76),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.gold),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Pill(
                label: 'Approved Mandarin',
                icon: Icons.verified_rounded,
                color: AppColors.jade,
              ),
              Pill(
                label: '30 lessons',
                icon: Icons.route_rounded,
                color: AppColors.cinnabar,
              ),
              Pill(
                label: 'Audio + quests',
                icon: Icons.volume_up_rounded,
                color: AppColors.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int step;
  const _StepDots({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 4; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == step ? 28 : 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: i <= step ? AppColors.brandGradient : null,
              color: i <= step ? null : AppColors.line,
            ),
          ),
          if (i != 3) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NameStep({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What should we call you?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
          decoration: const InputDecoration(
            hintText: 'Your name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
      ],
    );
  }
}

class _AvatarStep extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelect;

  const _AvatarStep({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your avatar',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final emoji in options)
              GestureDetector(
                onTap: () => onSelect(emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected == emoji
                        ? AppColors.primarySoft
                        : AppColors.surface,
                    border: Border.all(
                      color: selected == emoji
                          ? AppColors.primary
                          : AppColors.line,
                      width: selected == emoji ? 2.5 : 1,
                    ),
                    boxShadow: selected == emoji ? AppTheme.cardShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: EmojiText(emoji, size: 30),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final UserRole? role;

  const _HowItWorksStep({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final student = role != UserRole.teacher && role != UserRole.reviewer;
    final items = student
        ? const [
            (
              Icons.volume_up_rounded,
              '1. Look, listen, repeat',
              'Each lesson starts with a few words. Tap Listen, say the word out loud, then go to the next word.',
            ),
            (
              Icons.menu_book_rounded,
              '2. The idea, then practice',
              'A short explanation comes next, then a conversation and a few practice questions.',
            ),
            (
              Icons.flag_rounded,
              '3. Quest, then unlock',
              'Finish five quest questions to complete the lesson. The next Path lesson opens after that.',
            ),
          ]
        : const [
            (
              Icons.groups_rounded,
              'Class',
              'Share a class code so learners can join you.',
            ),
            (
              Icons.route_rounded,
              'Progress',
              'See which Foundation lessons each learner has finished.',
            ),
            (
              Icons.bolt_rounded,
              'Live',
              'Start a short timed quiz when the class is together.',
            ),
          ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(items[i].$1, color: AppColors.cinnabar),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$3,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RoleStep extends StatelessWidget {
  final UserRole? selected;
  final bool allowReviewer;
  final ValueChanged<UserRole> onSelect;

  const _RoleStep({
    super.key,
    required this.selected,
    required this.allowReviewer,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How will you use Kidversity?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        _RoleCard(
          emoji: '🧒',
          title: "I'm a Student",
          subtitle: 'Follow the Mandarin path, practise & earn badges',
          gradient: AppColors.brandGradient,
          selected: selected == UserRole.student,
          onTap: () => onSelect(UserRole.student),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          emoji: '🧑‍🏫',
          title: "I'm a Teacher or Parent",
          subtitle: 'Coach a class and follow Foundation progress',
          gradient: AppColors.sunsetGradient,
          selected: selected == UserRole.teacher,
          onTap: () => onSelect(UserRole.teacher),
        ),
        if (allowReviewer) ...[
          const SizedBox(height: 12),
          _RoleCard(
            emoji: '校',
            title: "I'm a Reviewer",
            subtitle: 'Review Mandarin lessons before they are published',
            gradient: AppColors.mandarinGradient,
            selected: selected == UserRole.reviewer,
            onTap: () => onSelect(UserRole.reviewer),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final Gradient gradient;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.018 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: GlassCard(
        onTap: onTap,
        gradient: gradient,
        padding: const EdgeInsets.all(16),
        border: selected ? Border.all(color: Colors.white, width: 2.5) : null,
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
