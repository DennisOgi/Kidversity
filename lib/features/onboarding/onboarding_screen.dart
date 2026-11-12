import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/features.dart';
import '../../core/error_handler.dart';
import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/models.dart';
import '../../router/navigation.dart';
import '../../services/family_service.dart';
import '../../services/school_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/role_style.dart';
import '../../widgets/kv_ui.dart';
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
  final _schoolName = TextEditingController();
  final _staffCode = TextEditingController();
  int _step = 0;
  String _emoji = '🦊';
  UserRole? _role;

  /// A school leader is a teacher account that creates the school and
  /// becomes its admin.
  bool _schoolLeader = false;
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
        setState(() {
          _role = preset;
          // "Set up my school" sends people here on their way to /school.
          _schoolLeader =
              query?['redirect']?.startsWith(AppRoutes.schoolHome) ?? false;
        });
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
      // Staff invite links: /join/staff/ABCD-2345, or ?staff=ABCD-2345.
      final staffCode =
          query?['staff'] ?? staffCodeFromPath(query?['redirect']);
      if (staffCode != null && staffCode.isNotEmpty) {
        setState(() {
          _staffCode.text = staffCode;
          _role = UserRole.teacher;
          _schoolLeader = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _classCode.dispose();
    _familyCode.dispose();
    _className.dispose();
    _schoolName.dispose();
    _staffCode.dispose();
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
        return !_schoolLeader || _schoolName.text.trim().length >= 2;
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

      final staffCode = _staffCode.text.trim();
      final joiningSchool =
          role == UserRole.teacher && !_schoolLeader && staffCode.isNotEmpty;

      await ref
          .read(authControllerProvider)
          .completeOnboarding(
            name: name,
            emoji: _emoji,
            selectedRole: role,
            className: role == UserRole.teacher ? _className.text : null,
            // A school leader makes the school first; a teacher with a staff
            // code gets their class inside the school instead.
            createSoloClass: !_schoolLeader && !joiningSchool,
          );

      if (role != null) {
        ref.read(roleProvider.notifier).state = role;
      }

      final notes = <String>[];
      String? destinationOverride;

      if (role == UserRole.teacher && _schoolLeader) {
        final created = await SchoolService.instance.createSchool(
          _schoolName.text,
        );
        if (created.isSuccess) {
          notes.add(
            '${created.data!.name} is ready. Invite your teachers next.',
          );
          destinationOverride = AppRoutes.schoolHome;
        } else {
          notes.add(
            'The school could not be created: ${created.error}. Try again from your class page.',
          );
          await SupabaseService.instance.ensureTeacherClass(
            className: '$name\'s Class',
          );
        }
      } else if (joiningSchool) {
        final joined = await SchoolService.instance.joinWithStaffCode(
          staffCode,
        );
        final className = _className.text.trim();
        if (joined.isSuccess) {
          notes.add('You joined ${joined.data}.');
          if (className.isNotEmpty) {
            await SchoolService.instance.createClass(className);
          }
        } else {
          notes.add(
            '${joined.error} You can enter it later on your class page.',
          );
          await SupabaseService.instance.ensureTeacherClass(
            className: className.isNotEmpty ? className : '$name\'s Class',
          );
        }
        destinationOverride = AppRoutes.teacherDashboard;
      }
      ref.invalidate(schoolOverviewProvider);
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

      // A staff invite link redirects back to itself; onboarding has already
      // used the code, so go home instead.
      final usableRedirect = staffCodeFromPath(redirect) == null
          ? redirect
          : null;
      final destination =
          destinationOverride ?? usableRedirect ?? homeForRole(role);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(destination);
      });
    } catch (error, stack) {
      await ErrorHandler.reportError(
        error,
        stack,
        context: 'onboarding.finish',
      );
      if (mounted) {
        final text = error.toString();
        // A rejected sign-in token (401 / PGRST30x) is not something trying
        // again fixes, so say what actually happened.
        final authProblem =
            text.contains('PGRST30') ||
            text.contains('JWT') ||
            text.contains('401');
        final offline =
            text.contains('SocketException') ||
            text.contains('Failed host lookup') ||
            text.contains('XMLHttpRequest');
        context.showErrorSnackbar(
          authProblem
              ? 'We could not confirm your sign-in. Sign out, sign in again, and finish setting up.'
              : offline
              ? 'You seem to be offline. Check your connection and try again.'
              : 'We could not save your choices. Please try again.',
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
          UserRole.teacher when _schoolLeader => (
            'Your name',
            'Teachers and parents see it on school pages.',
          ),
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
          UserRole.teacher when _schoolLeader => (
            'Name your school',
            'You become its admin. Next you invite teachers and create classes.',
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
          UserRole.teacher when _schoolLeader => (
            'Your school workspace',
            'Three steps get every class running.',
          ),
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
      case UserRole.teacher when _schoolLeader:
        return _SchoolLeaderSetupStep(
          key: const ValueKey('leader-setup'),
          schoolName: _schoolName,
          onChanged: () => setState(() {}),
        );
      case UserRole.teacher:
        return _TeacherSetupStep(
          key: const ValueKey('teacher-setup'),
          className: _className,
          staffCode: _staffCode,
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
        color: AppColors.surface,
        padding: EdgeInsets.fromLTRB(wide ? 32 : 22, 26, wide ? 32 : 22, 28),
        shadow: AppTheme.softShadow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTint.violet.soft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const KidversityMark(size: 26),
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
                  'Step ${_step + 1} of $_stepCount',
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
                  schoolLeader: _schoolLeader,
                  allowReviewer:
                      ref.watch(authControllerProvider).role ==
                      UserRole.reviewer,
                  onSelect: (role, {leader = false}) => setState(() {
                    _role = role;
                    _schoolLeader = leader;
                  }),
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
                _ => _HowItWorksStep(
                  key: const ValueKey('howto'),
                  role: _role,
                  schoolLeader: _schoolLeader,
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
                                  schoolLeader: _schoolLeader,
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

class _SchoolLeaderSetupStep extends StatelessWidget {
  final TextEditingController schoolName;
  final VoidCallback onChanged;

  const _SchoolLeaderSetupStep({
    super.key,
    required this.schoolName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: schoolName,
          onChanged: (_) => onChanged(),
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'School name',
            hintText: 'e.g. Pearls Garden School',
            prefixIcon: Icon(Icons.apartment_rounded),
          ),
        ),
        const SizedBox(height: 6),
        const _TipRow(
          icon: Icons.key_rounded,
          text:
              'Your school gets a staff code. Teachers type it when they sign up, and they join your school.',
        ),
        const SizedBox(height: 8),
        const _TipRow(
          icon: Icons.mail_outline_rounded,
          text:
              'Or invite teachers by email. They join your school as soon as they sign up with that email.',
        ),
      ],
    );
  }
}

class _TeacherSetupStep extends StatelessWidget {
  final TextEditingController className;
  final TextEditingController staffCode;
  final VoidCallback onChanged;

  const _TeacherSetupStep({
    super.key,
    required this.className,
    required this.staffCode,
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
            labelText: 'Class name',
            hintText: 'e.g. JSS 1 Gold',
            prefixIcon: Icon(Icons.class_rounded),
          ),
        ),
        const SizedBox(height: 16),
        Text('School staff code (optional)', style: text.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: staffCode,
          onChanged: (_) => onChanged(),
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'e.g. ABCD-2345 from your school admin',
            prefixIcon: Icon(Icons.apartment_rounded),
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
              'No staff code? You can still teach on your own, and join your school later from your class page.',
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

/// Violet gradient with the brand's playful shapes, behind the setup card.
class _OnboardingBackdrop extends StatelessWidget {
  final Widget child;

  const _OnboardingBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    Widget blob(double size, Color color, {double radius = 999}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1F8F), Color(0xFF4433CC), Color(0xFF7B4FE8)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: Stack(
              children: [
                Positioned(
                  right: compact ? -90 : -140,
                  top: compact ? -110 : -160,
                  child: blob(compact ? 240 : 420, const Color(0xFFFFC845)),
                ),
                Positioned(
                  left: -100,
                  bottom: -120,
                  child: blob(compact ? 220 : 320, const Color(0x99FF6B5B)),
                ),
                Positioned(
                  left: compact ? 24 : 80,
                  top: compact ? 80 : 120,
                  child: blob(18, const Color(0xFF7CC4FF)),
                ),
                Positioned(
                  right: compact ? 30 : 120,
                  bottom: compact ? 60 : 110,
                  child: Transform.rotate(
                    angle: 0.4,
                    child: blob(
                      compact ? 36 : 60,
                      const Color(0xFF22B07D),
                      radius: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Left panel on wide screens: a welcome, the learner's chosen avatar and
/// role, and the learning worlds waiting for them.
class _OnboardingPreview extends StatelessWidget {
  final int step;
  final String avatar;
  final UserRole? role;
  final bool schoolLeader;

  const _OnboardingPreview({
    required this.step,
    required this.avatar,
    required this.role,
    this.schoolLeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (role) {
      UserRole.student => 'Learner',
      UserRole.teacher when schoolLeader => 'School leader',
      UserRole.teacher => 'Teacher',
      UserRole.parent => 'Parent',
      UserRole.reviewer => 'Language reviewer',
      UserRole.platformAdmin => 'Platform admin',
      null => 'Choose your role',
    };
    final roleTint = switch (role) {
      UserRole.student => AppTint.violet,
      UserRole.teacher when schoolLeader => AppTint.sky,
      UserRole.teacher => AppTint.mint,
      UserRole.parent => AppTint.coral,
      _ => AppTint.sun,
    };
    final caption = step == 0
        ? 'Tell us who is joining.'
        : step == 1
        ? 'Nice to meet you.'
        : step == 2
        ? 'Looking good.'
        : switch (role) {
            UserRole.teacher when schoolLeader =>
              'Your school, your staff, and every class.',
            UserRole.teacher =>
              'Your class, assignments, live quizzes, and progress.',
            UserRole.parent => 'Your children and their learning week.',
            UserRole.reviewer => 'The review queue is ready.',
            UserRole.platformAdmin => 'Schools, users, and platform analytics.',
            _ => 'Lessons, practice, labs, maths and Rope Pull.',
          };
    const worlds = [
      (AppTint.coral, Icons.translate_rounded, 'Mandarin'),
      (AppTint.sky, Icons.menu_book_rounded, 'Past questions'),
      (AppTint.mint, Icons.calculate_rounded, 'Mental maths'),
      (AppTint.sun, Icons.science_rounded, 'Labs'),
      (AppTint.pink, Icons.sports_esports_rounded, 'Rope Pull'),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KidversityBrandMark(reversed: true),
          const SizedBox(height: 40),
          Text(
            'Many paths.\nOne curious home.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'A minute of setup, then a home built around you: lessons, '
            'practice and play for learners, and clear dashboards for '
            'teachers, schools and parents.',
            style: TextStyle(
              color: Color(0xFFEDEAFF),
              fontSize: 17,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14085A).withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: roleTint.soft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: EmojiText(avatar, key: ValueKey(avatar), size: 36),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(label: roleLabel, tint: roleTint),
                      const SizedBox(height: 6),
                      Text(
                        caption,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final w in worlds)
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TintIcon(tint: w.$1, icon: w.$2, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        w.$3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One coloured segment per step; done and current steps fill in.
class _StepDots extends StatelessWidget {
  final int step;
  final int count;
  const _StepDots({required this.step, required this.count});

  static const _tints = [
    AppTint.violet,
    AppTint.coral,
    AppTint.sun,
    AppTint.mint,
    AppTint.sky,
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of $count',
      child: Row(
        children: [
          for (int i = 0; i < count; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: i <= step
                      ? _tints[i % _tints.length].strong
                      : const Color(0xFFECEAF5),
                ),
              ),
            ),
            if (i != count - 1) const SizedBox(width: 6),
          ],
        ],
      ),
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
  final bool schoolLeader;

  const _HowItWorksStep({
    super.key,
    required this.role,
    this.schoolLeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = switch (role) {
      UserRole.teacher when schoolLeader => const [
        (
          Icons.person_add_alt_1_rounded,
          'Invite your teachers',
          'Share the staff code or invite link, or add teachers by email.',
        ),
        (
          Icons.groups_rounded,
          'Create classes',
          'Give each class a teacher. Every class gets its own join code for students.',
        ),
        (
          Icons.insights_rounded,
          'Follow the school',
          'See which classes are active, place students who joined without a class, and keep setup on track.',
        ),
      ],
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
  final bool schoolLeader;
  final bool allowReviewer;
  final void Function(UserRole role, {bool leader}) onSelect;

  const _RoleStep({
    super.key,
    required this.selected,
    required this.schoolLeader,
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
          icon: Icons.backpack_rounded,
          title: "I'm a Student",
          subtitle: 'Mandarin, exams, labs, maths, and Rope Pull',
          tint: AppTint.violet,
          selected: selected == UserRole.student,
          onTap: () => onSelect(UserRole.student),
        ),
        const SizedBox(height: 10),
        _RoleCard(
          icon: Icons.co_present_rounded,
          title: "I'm a Teacher",
          subtitle: 'Set work, follow the class, and run a live quiz',
          tint: AppTint.mint,
          selected: selected == UserRole.teacher && !schoolLeader,
          onTap: () => onSelect(UserRole.teacher),
        ),
        const SizedBox(height: 10),
        _RoleCard(
          icon: Icons.apartment_rounded,
          title: 'I run a school',
          subtitle: 'Set up your school, invite teachers, and create classes',
          tint: AppTint.sky,
          selected: selected == UserRole.teacher && schoolLeader,
          onTap: () => onSelect(UserRole.teacher, leader: true),
        ),
        const SizedBox(height: 10),
        _RoleCard(
          icon: Icons.family_restroom_rounded,
          title: "I'm a Parent",
          subtitle: Features.payments
              ? 'Follow your child and unlock lesson packs'
              : 'Follow your child and see their learning week',
          tint: AppTint.coral,
          selected: selected == UserRole.parent,
          onTap: () => onSelect(UserRole.parent),
        ),
        if (allowReviewer) ...[
          const SizedBox(height: 10),
          _RoleCard(
            icon: Icons.fact_check_rounded,
            title: "I'm a Reviewer",
            subtitle: 'Review Mandarin lessons before they are published',
            tint: AppTint.sun,
            selected: selected == UserRole.reviewer,
            onTap: () => onSelect(UserRole.reviewer),
          ),
        ],
      ],
    );
  }
}

/// A role choice: tinted when idle, filled with its colour when chosen.
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final AppTint tint;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onFill = tint == AppTint.sun ? AppColors.ink : Colors.white;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? tint.strong : tint.soft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? tint.ink
                : Color.alphaBlend(
                    tint.strong.withValues(alpha: 0.25),
                    tint.soft,
                  ),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tint.strong.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : tint.strong,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: selected
                          ? tint.ink
                          : (tint == AppTint.sun
                                ? AppColors.ink
                                : Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: selected ? onFill : AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: selected
                                ? onFill.withValues(alpha: 0.92)
                                : tint.ink,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? onFill : tint.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
