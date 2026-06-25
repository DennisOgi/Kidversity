import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/motion.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tab = GoRouterState.of(context).uri.queryParameters['tab'];
      if (tab == 'signup') _tabs.animateTo(1);
    });
  }
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _tabs.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  String? get _redirect => GoRouterState.of(context).uri.queryParameters['redirect'];

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      if (mounted) context.showErrorSnackbar('Enter your email address first.');
      return;
    }
    final result = await SupabaseService.instance.resetPassword(email);
    if (!mounted) return;
    if (result.isSuccess) {
      context.showSuccessSnackbar('Password reset email sent — check your inbox.');
    } else {
      context.showErrorSnackbar(result.error ?? 'Could not send reset email.');
    }
  }

  Future<void> _submitSignIn() async {
    try {
      await ref.read(authControllerProvider).signInWithEmail(_email.text, _password.text);
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      if (auth.role != null) {
        ref.read(roleProvider.notifier).state = auth.role;
      }
      continueAfterAuth(context, ref, redirect: _redirect);
    } catch (e) {
      if (mounted) context.showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _submitSignUp() async {
    try {
      await ref.read(authControllerProvider).signUpWithEmail(_email.text, _password.text, _name.text);
      if (mounted) continueAfterAuth(context, ref, redirect: _redirect);
    } catch (e) {
      if (mounted) context.showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width > 880;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 56 : 22, 8, wide ? 56 : 22, 0),
                child: KidversityBrandMark(onTap: () => context.go(AppRoutes.home)),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 22, vertical: 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight - 80),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: _HeroPanel(text: text)),
                                  const SizedBox(width: 48),
                                  Expanded(
                                    child: _FormCard(
                                      tabs: _tabs,
                                      text: text,
                                      auth: auth,
                                      email: _email,
                                      password: _password,
                                      name: _name,
                                      obscure: _obscure,
                                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                                      onSignIn: _submitSignIn,
                                      onSignUp: _submitSignUp,
                                      onResetPassword: _resetPassword,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _HeroPanel(text: text, compact: true),
                                  const SizedBox(height: 20),
                                  _FormCard(
                                    tabs: _tabs,
                                    text: text,
                                    auth: auth,
                                    email: _email,
                                    password: _password,
                                    name: _name,
                                    obscure: _obscure,
                                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                                    onSignIn: _submitSignIn,
                                    onSignUp: _submitSignUp,
                                    onResetPassword: _resetPassword,
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final TextTheme text;
  final bool compact;
  const _HeroPanel({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Pill(label: 'Welcome back', icon: Icons.waving_hand_rounded, color: AppColors.secondary),
          SizedBox(height: compact ? 14 : 22),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [AppColors.primary, AppColors.accentPink, AppColors.secondary],
            ).createShader(r),
            child: Text(
              compact ? 'Sign in to\nKidversity' : 'Your classroom,\nreimagined.',
              style: text.displayMedium?.copyWith(color: Colors.white, fontSize: compact ? 34 : 44, height: 1.05),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Upload lessons or auto-generate with AI. Students learn with slides, audio and badges.',
            style: text.bodyLarge?.copyWith(fontSize: compact ? 15 : 16.5),
          ),
          if (!compact) ...[
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _MiniStat(emoji: '🎧', label: 'Slides + audio'),
                _MiniStat(emoji: '✨', label: 'AI lessons'),
                _MiniStat(emoji: '🏅', label: 'Streaks & XP'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String emoji, label;
  const _MiniStat({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final TabController tabs;
  final TextTheme text;
  final dynamic auth;
  final TextEditingController email, password, name;
  final bool obscure;
  final VoidCallback onToggleObscure, onSignIn, onSignUp, onResetPassword;

  const _FormCard({
    required this.tabs,
    required this.text,
    required this.auth,
    required this.email,
    required this.password,
    required this.name,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSignIn,
    required this.onSignUp,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delay: const Duration(milliseconds: 160),
      child: GlassCard(
        frosted: true,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        shadow: AppTheme.softShadow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.muted,
              labelStyle: text.labelLarge?.copyWith(fontSize: 14),
              tabs: const [
                Tab(text: 'Sign in'),
                Tab(text: 'Create account'),
              ],
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: tabs.index == 0
                  ? _Fields(
                      key: const ValueKey('signin'),
                      email: email,
                      password: password,
                      obscure: obscure,
                      onToggleObscure: onToggleObscure,
                      showName: false,
                    )
                  : _Fields(
                      key: const ValueKey('signup'),
                      email: email,
                      password: password,
                      name: name,
                      obscure: obscure,
                      onToggleObscure: onToggleObscure,
                      showName: true,
                    ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: auth.isLoading ? 'Please wait…' : (tabs.index == 0 ? 'Sign in' : 'Create account'),
              icon: Icons.arrow_forward_rounded,
              expand: true,
              onTap: auth.isLoading ? null : (tabs.index == 0 ? onSignIn : onSignUp),
            ),
            if (tabs.index == 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onResetPassword, child: const Text('Forgot password?')),
              ),
            ],
            if (auth.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.lastError!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppColors.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fields extends StatelessWidget {
  final TextEditingController email, password;
  final TextEditingController? name;
  final bool obscure, showName;
  final VoidCallback onToggleObscure;

  const _Fields({
    super.key,
    required this.email,
    required this.password,
    this.name,
    required this.obscure,
    required this.onToggleObscure,
    required this.showName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showName && name != null) ...[
          TextField(
            controller: name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Your name', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
      ],
    );
  }
}
