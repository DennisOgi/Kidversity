import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/features.dart';
import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/models.dart';
import '../../router/navigation.dart';
import '../../services/family_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/motion.dart';

/// Role first, then name, companion, a role-specific setup, and a short tour.
///
/// * Students can join their class and link a parent straight away.
/// * Teachers name their first class (learners join it with a code).
/// * Parents see the pathway and prices; their family code is on the next page.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _avatars = ['🦊', '🦁', '🐼', '🐯', '🐨', '🐸', '🦄', '🐙'];
  static const _adultAvatars = ['🦊', '🦉', '🌳', '📚', '🌟', '🧭', '🎓', '🌻'];
  static const _stepCount = 5;

  final _name = TextEditingController();
  final _classCode = TextEditingController();
  final _familyCode = TextEditingController();
  final _className = TextEditingController();
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
      final query = GoRouter.maybeOf(context)?.state.uri.queryParameters;
      final preset = roleFromPath(query?['redirect']);
      final provisionedRole = ref.read(authControllerProvider).role;
      if (preset != null &&
          (preset != UserRole.reviewer ||
              provisionedRole == UserRole.reviewer) &&
          (preset != UserRole.platformAdmin ||
              provisionedRole == UserRole.platformAdmin)) {
        setState(() => _role = preset);
      }
      // Invite links can carry codes: /onboarding?class=ABC123&family=FAM-XXXXX
      final classCode = query?['class'];
      final familyCode = query?['family'];
      if (classCode != null && classCode.isNotEmpty) {
        _classCode.text = classCode;
      }
      if (familyCode != null && familyCode.isNotEmpty) {
        _familyCode.text = familyCode;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _classCode.dispose();
    _familyCode.dispose();
    _className.dispose();
    super.dispose();
  }

  String? get _redirect =>
      GoRouter.maybeOf(context)?.state.uri.queryParameters['redirect'];

  bool get _isAdult =>
      _role == UserRole.teacher ||
      _role == UserRole.parent ||
      _role == UserRole.reviewer ||
      _role == UserRole.platformAdmin;

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _role != null;
      case 1:
        return _name.text.trim().isNotEmpty;
      case 2:
        return _emoji.isNotEmpty;
      case 3:
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _next() {
    if (!_canContinue) return;
    if (_step == 1 && _role == UserRole.teacher && _className.text.isEmpty) {
      final first = _name.text.trim();
      _className.text = '$first’s Class';
    }
    if (_step < _stepCount - 1) {
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
      setState(() {
        _role = null;
        _step = 0;
      });
      return;
    }
    if (_role == UserRole.platformAdmin &&
        ref.read(authControllerProvider).role != UserRole.platformAdmin) {
      context.showErrorSnackbar(
        'Platform admin access is available by invitation.',
      );
      setState(() {
        _role = null;
        _step = 0;
      });
      return;
    }

    setState(() => _busy = true);

    try {
      final name = _name.text.trim();
      final redirect = _redirect;
      final role = _role ?? roleFromPath(redirect);

      await ref
          .read(authControllerProvider)
          .completeOnboarding(
            name: name,
            emoji: _emoji,
            selectedRole: role,
            className: role == UserRole.teacher ? _className.text : null,
          );

      if (role != null) {
        ref.read(roleProvider.notifier).state = role;
      }

      final notes = <String>[];
      if (role == UserRole.student) {
        final classCode = _classCode.text.trim();
        if (classCode.isNotEmpty) {
          final joined = await SupabaseService.instance.joinClassWithCode(
            classCode,
          );
          notes.add(
            joined.isSuccess
                ? 'You joined ${joined.data}.'
                : 'Class code did not work — try again under Me.',
          );
        }
        final familyCode = _familyCode.text.trim();
        if (familyCode.isNotEmpty) {
          final linked = await FamilyService.instance.join(familyCode);
          notes.add(
            linked.isSuccess
                ? 'Linked to ${linked.data}.'
                : 'Family code did not work — try again under Me → Family.',
          );
        }
      }

      if (!mounted) return;
      if (notes.isNotEmpty) context.showSuccessSnackbar(notes.join(' '));

      final destination = redirect ?? homeForRole(role);

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

  (String, String) _stepTitle() {
    switch (_step) {
      case 0:
        return (
          'Welcome to Kidversity',
          'Tell us who is joining so we open the right space.',
        );
      case 1:
        return switch (_role) {
          UserRole.teacher => (
            'How should learners address you?',
            'This is how your name appears to your class.',
          ),
          UserRole.parent => (
            'Your name',
            'We use it on your family page and receipts.',
          ),
          UserRole.student => (
            'What should we call you?',
            'Your first name is enough. Classmates see it in games.',
          ),
          _ => ('Your name', 'How your colleagues will see you.'),
        };
      case 2:
        return _isAdult
            ? ('Pick a profile icon', 'It shows next to your name.')
            : (
                'Choose your companion',
                'Pick the character that will travel with you.',
              );
      case 3:
        return switch (_role) {
          UserRole.student => (
            'Join your class and family',
            'Both are optional — you can add them later under Me.',
          ),
          UserRole.teacher => (
            'Name your first class',
            'You will get a join code to share with learners.',
          ),
          UserRole.parent when Features.payments => (
            'How packs work',
            'You only pay when your child is ready for more.',
          ),
          UserRole.parent => (
            'Following your child',
            'Everything you will see on your family page.',
          ),
          _ => ('Almost there', 'Your workspace is ready.'),
        };
      default:
        return switch (_role) {
          UserRole.teacher => (
            'Your class workspace',
            'Invite learners, set the work, and run a quiz you write yourself.',
          ),
          UserRole.parent => (
            'Your family page',
            Features.payments
                ? 'Link your child, follow their pathway, and unlock packs.'
                : 'Link your child and follow their pathway.',
          ),
          UserRole.reviewer => (
            'How review works',
            'Lessons stay unpublished until you check the audio, the wording, and the quest.',
          ),
          UserRole.platformAdmin => (
            'How admin works',
            'Overview, schools, users, payments, and learner performance.',
          ),
          _ => (
            'How learning works here',
            'Mandarin lessons, exam topics, labs, mental maths, and Rope Pull.',
          ),
        };
    }
  }

  Widget _setupStep() {
    switch (_role) {
      case UserRole.student:
        return _StudentSetupStep(
          key: const ValueKey('student-setup'),
          classCode: _classCode,
          familyCode: _familyCode,
        );
      case UserRole.teacher:
        return _TeacherSetupStep(
          key: const ValueKey('teacher-setup'),
          className: _className,
          onChanged: () => setState(() {}),
        );
      case UserRole.parent:
        return const _ParentSetupStep(key: ValueKey('parent-setup'));
      default:
        return _HowItWorksStep(key: const ValueKey('setup'), role: _role);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width > 900;
    final title = _stepTitle();
    final last = _step == _stepCount - 1;

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
                    'KV',
                    style: TextStyle(
                      color: AppColors.paper,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KIDVERSITY',
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
                  '${_step + 1} / $_stepCount',
                  style: text.labelLarge?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              title.$1,
              style: text.headlineSmall?.copyWith(fontSize: wide ? 30 : 26),
            ),
            const SizedBox(height: 6),
            Text(title.$2, style: text.bodyMedium),
            const SizedBox(height: 22),
            _StepDots(step: _step, count: _stepCount),
            const SizedBox(height: 26),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: const Cubic(0.23, 1, 0.32, 1),
              switchOutCurve: const Cubic(0.23, 1, 0.32, 1),
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
                0 => _RoleStep(
                  key: const ValueKey('role'),
                  selected: _role,
                  allowReviewer:
                      ref.watch(authControllerProvider).role ==
                      UserRole.reviewer,
                  onSelect: (role) => setState(() => _role = role),
                ),
                1 => _NameStep(
                  key: const ValueKey('name'),
                  controller: _name,
                  hint: switch (_role) {
                    UserRole.teacher => 'e.g. Mrs Adeyemi',
                    UserRole.student => 'Your first name',
                    _ => 'Your name',
                  },
                  onChanged: (_) => setState(() {}),
                ),
                2 => _AvatarStep(
                  key: const ValueKey('avatar'),
                  selected: _emoji,
                  options: _isAdult ? _adultAvatars : _avatars,
                  onSelect: (emoji) => setState(() => _emoji = emoji),
                ),
                3 => _setupStep(),
                _ => _HowItWorksStep(key: const ValueKey('howto'), role: _role),
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
                      : (last ? 'Enter Kidversity' : 'Continue'),
                  icon: last
                      ? Icons.auto_awesome_rounded
                      : Icons.arrow_forward_rounded,
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

class _StudentSetupStep extends StatelessWidget {
  final TextEditingController classCode;
  final TextEditingController familyCode;

  const _StudentSetupStep({
    super.key,
    required this.classCode,
    required this.familyCode,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class code from your teacher', style: text.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: classCode,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'e.g. 7KQ2MD (optional)',
            prefixIcon: Icon(Icons.groups_rounded),
          ),
        ),
        const SizedBox(height: 18),
        Text('Family code from your parent', style: text.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: familyCode,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'FAM-XXXXX (optional)',
            prefixIcon: Icon(Icons.family_restroom_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your parent can follow your progress from their own account.',
          style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _TeacherSetupStep extends StatelessWidget {
  final TextEditingController className;
  final VoidCallback onChanged;

  const _TeacherSetupStep({
    super.key,
    required this.className,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: className,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            hintText: 'e.g. JSS 1 Gold',
            prefixIcon: Icon(Icons.class_rounded),
          ),
        ),
        const SizedBox(height: 14),
        const _TipRow(
          icon: Icons.qr_code_rounded,
          text:
              'Your class page shows a join code. Write it on the board — learners type it under Me.',
        ),
        const SizedBox(height: 8),
        const _TipRow(
          icon: Icons.apartment_rounded,
          text:
              'Part of a school? Your school admin can add you, and your class joins the school directory.',
        ),
        const SizedBox(height: 8),
        Text(
          'You can rename the class or add more classes later.',
          style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _ParentSetupStep extends StatelessWidget {
  const _ParentSetupStep({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Features.payments) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TipRow(
            icon: Icons.password_rounded,
            text:
                'You get a family code. Your child types it under Me → Family.',
          ),
          SizedBox(height: 10),
          _TipRow(
            icon: Icons.route_rounded,
            text:
                'See lessons finished, streaks, and where they are in Mandarin and maths.',
          ),
          SizedBox(height: 10),
          _TipRow(
            icon: Icons.family_restroom_rounded,
            text: 'Link more than one child to the same family.',
          ),
        ],
      );
    }
    final text = Theme.of(context).textTheme;
    const rows = [
      ('Lessons 1–2', 'Free in every subject', AppColors.success),
      ('One pack', '₦2,500 · the next 10 lessons', AppColors.primary),
      ('Bundle', '₦6,500 · 3 packs, any subject or child', AppColors.worldPlay),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: row.$3.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: row.$3.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(row.$1, style: text.titleSmall)),
                Text(row.$2, style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        const _TipRow(
          icon: Icons.all_inclusive_rounded,
          text:
              'No subscription. Packs never expire, so lessons stay open for revision.',
        ),
        const SizedBox(height: 8),
        const _TipRow(
          icon: Icons.notifications_active_rounded,
          text:
              'When your child reaches lesson 8 of a pack, we remind you the next one is coming.',
        ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.cinnabar),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  final Widget child;

  const _OnboardingBackdrop({required this.child});

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.paper, child: child);
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
      UserRole.parent => 'Family',
      UserRole.reviewer => 'Language reviewer',
      UserRole.platformAdmin => 'Platform admin',
      null => 'Choose your role',
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WELCOME',
            style: TextStyle(
              color: AppColors.cinnabar,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Many paths.\nOne curious home.',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: AppColors.ink,
              fontSize: 44,
              height: 1.03,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Students practise Mandarin, past questions, labs, and mental maths, '
            'and play Rope Pull. Teachers set the work and can run a live quiz they write themselves.',
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
                    child: EmojiText(avatar, key: ValueKey(avatar), size: 38),
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
                            ? 'Nice to meet you.'
                            : step == 2
                            ? 'Looking good.'
                            : switch (role) {
                                UserRole.teacher =>
                                  'Class, assignments, a quiz you write, and progress.',
                                UserRole.parent =>
                                  'Your children, their pathway, and packs.',
                                UserRole.reviewer =>
                                  'The review queue is ready.',
                                UserRole.platformAdmin =>
                                  'Schools, users, and platform analytics.',
                                _ =>
                                  'Path, Practice, Play, labs, and maths are open.',
                              },
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
                label: 'Mandarin path',
                icon: Icons.translate_rounded,
                color: AppColors.cinnabar,
              ),
              Pill(
                label: 'Exam practice',
                icon: Icons.menu_book_rounded,
                color: Color(0xFF1B7A4E),
              ),
              Pill(
                label: 'Labs',
                icon: Icons.science_rounded,
                color: Color(0xFF0F766E),
              ),
              Pill(
                label: 'Mental maths',
                icon: Icons.calculate_rounded,
                color: Color(0xFF6751B5),
              ),
              Pill(
                label: 'Rope Pull',
                icon: Icons.sports_esports_rounded,
                color: Color(0xFF916015),
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
  final int count;
  const _StepDots({required this.step, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++) ...[
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
          if (i != count - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _NameStep({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      maxLength: 40,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.person_outline_rounded),
        counterText: '',
      ),
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
    final items = switch (role) {
      UserRole.teacher => const [
        (
          Icons.groups_rounded,
          'Class',
          'Share your class code so learners can join you.',
        ),
        (
          Icons.assignment_rounded,
          'Assign',
          'Set a Mandarin lesson, an exam topic, or a mental-maths level.',
        ),
        (
          Icons.bolt_rounded,
          'Live quiz',
          'Write as many questions as you want. Students answer on their own screens, and you see each option fill in while the quiz is open.',
        ),
        (
          Icons.route_rounded,
          'Progress',
          'See who is moving through Mandarin, and who needs you next.',
        ),
      ],
      UserRole.parent => const [
        (
          Icons.password_rounded,
          'Your family code',
          'It is on your Family page. Your child types it under Me → Family.',
        ),
        (
          Icons.route_rounded,
          'Follow the pathway',
          'See lessons finished, streaks, and where each child is in Mandarin and maths.',
        ),
        (
          Icons.lock_open_rounded,
          'One lesson at a time',
          'Each lesson opens when the one before it is finished, so you always know what is next.',
        ),
      ],
      UserRole.reviewer => const [
        (
          Icons.fact_check_rounded,
          'Review queue',
          'New Mandarin lessons wait here before students can open them.',
        ),
        (
          Icons.volume_up_rounded,
          'Check the lesson',
          'Listen to the audio, read the wording, and try the quest.',
        ),
        (
          Icons.published_with_changes_rounded,
          'Approve or send it back',
          'Approved lessons join the path. Anything that needs a fix goes back to be corrected.',
        ),
      ],
      UserRole.platformAdmin => const [
        (
          Icons.dashboard_rounded,
          'Overview',
          'See schools, learners, and weekly learning activity at a glance.',
        ),
        (
          Icons.apartment_rounded,
          'Schools',
          'Create schools and assign school admins.',
        ),
        (
          Icons.people_rounded,
          'Users and performance',
          'Browse accounts and open per-learner Mandarin, exam, and maths stats.',
        ),
      ],
      _ => const [
        (
          Icons.translate_rounded,
          'Mandarin path',
          'Each lesson warms up words you already know, then you look, listen, and finish the quest to unlock the next one.',
        ),
        (
          Icons.menu_book_rounded,
          'Exam topics',
          'Work through Biology, Chemistry, Physics, and Government in short topics, and practise past questions when you want a full paper.',
        ),
        (
          Icons.science_rounded,
          'Labs and mental maths',
          'Labs are experiments you can change and watch. Mental maths is twenty levels, from number facts up to simple algebra.',
        ),
        (
          Icons.sports_esports_rounded,
          'Rope Pull and word review',
          'Play is its own place: Indigo and Teal pull on words, past questions, or maths. Practice keeps a short daily review of Mandarin words you have unlocked.',
        ),
      ],
    };

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
          subtitle: 'Mandarin, exams, labs, maths, and Rope Pull',
          gradient: AppColors.brandGradient,
          selected: selected == UserRole.student,
          onTap: () => onSelect(UserRole.student),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          emoji: '🧑‍🏫',
          title: "I'm a Teacher",
          subtitle: 'Set work, follow the class, and run a live quiz',
          gradient: AppColors.mandarinGradient,
          selected: selected == UserRole.teacher,
          onTap: () => onSelect(UserRole.teacher),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          emoji: '👪',
          title: "I'm a Parent",
          subtitle: 'Follow your child and unlock lesson packs',
          gradient: const LinearGradient(
            colors: [AppColors.success, Color(0xFF0E5536)],
          ),
          selected: selected == UserRole.parent,
          onTap: () => onSelect(UserRole.parent),
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
