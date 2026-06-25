import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/models.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';
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
      final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
      final preset = roleFromPath(redirect);
      if (preset != null) setState(() => _role = preset);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _redirect => GoRouterState.of(context).uri.queryParameters['redirect'];

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _name.text.trim().isNotEmpty;
      case 1:
        return _emoji.isNotEmpty;
      case 2:
        return _role != null;
      default:
        return false;
    }
  }

  void _next() {
    if (!_canContinue) return;
    if (_step < 2) {
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

    setState(() => _busy = true);

    try {
      final name = _name.text.trim();
      final redirect = _redirect;
      final role = _role ?? roleFromPath(redirect);

      await ref.read(authControllerProvider).completeOnboarding(
            name: name,
            emoji: _emoji,
            selectedRole: role,
          );

      if (role != null) {
        ref.read(roleProvider.notifier).state = role;
      }

      if (!mounted) return;

      final destination = redirect ??
          (role == UserRole.teacher
              ? AppRoutes.teacherHome
              : role == UserRole.student
                  ? AppRoutes.studentHome
                  : AppRoutes.home);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(destination);
      });
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width > 720;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 22, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: FadeInUp(
                        child: GlassCard(
                          frosted: true,
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                          shadow: AppTheme.softShadow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Pill(
                                label: 'Almost there',
                                icon: Icons.auto_awesome_rounded,
                                color: AppColors.accentTeal,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Set up your profile',
                                style: text.headlineSmall?.copyWith(fontSize: 28),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pick a name, avatar, and how you\'ll use Kidversity.',
                                style: text.bodyMedium,
                              ),
                              const SizedBox(height: 22),
                              _StepDots(step: _step),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
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
                                      onSelect: (e) => setState(() => _emoji = e),
                                    ),
                                  _ => _RoleStep(
                                      key: const ValueKey('role'),
                                      selected: _role,
                                      onSelect: (r) => setState(() => _role = r),
                                    ),
                                },
                              ),
                              const SizedBox(height: 28),
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
                                        : (_step < 2 ? 'Continue' : 'Start learning'),
                                    icon: Icons.arrow_forward_rounded,
                                    onTap: (_busy || !_canContinue) ? null : _next,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
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
        for (int i = 0; i < 3; i++) ...[
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
          if (i != 2) const SizedBox(width: 8),
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
        Text('What should we call you?', style: Theme.of(context).textTheme.titleMedium),
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
        Text('Choose your avatar', style: Theme.of(context).textTheme.titleMedium),
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
                    color: selected == emoji ? AppColors.primarySoft : AppColors.surface,
                    border: Border.all(
                      color: selected == emoji ? AppColors.primary : AppColors.line,
                      width: selected == emoji ? 2.5 : 1,
                    ),
                    boxShadow: selected == emoji ? AppTheme.cardShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 30)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RoleStep extends StatelessWidget {
  final UserRole? selected;
  final ValueChanged<UserRole> onSelect;

  const _RoleStep({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How will you use Kidversity?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        _RoleCard(
          emoji: '🧒',
          title: "I'm a Student",
          subtitle: 'Follow slides, listen along & earn badges',
          gradient: AppColors.brandGradient,
          selected: selected == UserRole.student,
          onTap: () => onSelect(UserRole.student),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          emoji: '🧑‍🏫',
          title: "I'm a Teacher or Parent",
          subtitle: 'Upload a lesson or auto-generate with AI',
          gradient: AppColors.sunsetGradient,
          selected: selected == UserRole.teacher,
          onTap: () => onSelect(UserRole.teacher),
        ),
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
    return GlassCard(
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
    );
  }
}
