import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_state.dart';
import '../../data/auth_remember_me.dart';
import '../../data/auth_state.dart';
import '../../data/supabase_auth.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/kv_ui.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/motion.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final tab = GoRouter.maybeOf(context)?.state.uri.queryParameters['tab'];
      if (tab == 'signup') _tabs.animateTo(1);

      final saved = await AuthRememberMe.load();
      if (!mounted) return;
      setState(() {
        _rememberMe = saved.enabled;
        if (saved.email != null) _email.text = saved.email!;
      });
    });
  }

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _name = TextEditingController();
  final _age = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _rememberMe = true;
  String? _gender;

  @override
  void dispose() {
    _tabs.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  String? get _redirect =>
      GoRouterState.of(context).uri.queryParameters['redirect'];

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      if (mounted) context.showErrorSnackbar('Enter your email address first.');
      return;
    }
    final result = await SupabaseService.instance.resetPassword(email);
    if (!mounted) return;
    if (result.isSuccess) {
      context.showSuccessSnackbar(
        'Password reset email sent — check your inbox.',
      );
    } else {
      context.showErrorSnackbar(result.error ?? 'Could not send reset email.');
    }
  }

  Future<void> _submitSignIn() async {
    try {
      await ref
          .read(authControllerProvider)
          .signInWithEmail(_email.text, _password.text);
      await AuthRememberMe.save(enabled: _rememberMe, email: _email.text);
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      if (auth.role != null) {
        ref.read(roleProvider.notifier).state = auth.role;
      }
      continueAfterAuth(context, ref, redirect: _redirect);
    } catch (_) {
      if (mounted) {
        context.showErrorSnackbar(
          ref.read(authControllerProvider).lastError ??
              'We could not sign you in. Please try again.',
        );
      }
    }
  }

  Future<void> _submitSignUp() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirmPassword.text;
    final ageText = _age.text.trim();

    if (name.isEmpty) {
      context.showErrorSnackbar('Enter your name.');
      return;
    }
    if (email.isEmpty) {
      context.showErrorSnackbar('Enter your email.');
      return;
    }
    if (password.length < 8) {
      context.showErrorSnackbar('Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      context.showErrorSnackbar('Passwords do not match.');
      return;
    }
    if (_gender == null) {
      context.showErrorSnackbar('Select your gender.');
      return;
    }
    final age = int.tryParse(ageText);
    if (age == null || age < 5 || age > 99) {
      context.showErrorSnackbar('Enter a valid age (5 or older).');
      return;
    }

    try {
      await ref
          .read(authControllerProvider)
          .signUpWithEmail(email, password, name, gender: _gender, age: age);
      if (!mounted) return;
      final redirect = _redirect;
      context.go(
        redirect == null || redirect.isEmpty
            ? AppRoutes.onboarding
            : onboardingWithRedirect(redirect),
      );
    } catch (_) {
      if (mounted) {
        context.showErrorSnackbar(
          ref.read(authControllerProvider).lastError ??
              'We could not create your account. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final text = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width > 880;
    final signup = _tabs.index == 1;

    final form = _FormCard(
      tabs: _tabs,
      text: text,
      auth: auth,
      email: _email,
      password: _password,
      confirmPassword: _confirmPassword,
      name: _name,
      age: _age,
      gender: _gender,
      onGenderChanged: (g) => setState(() => _gender = g),
      obscure: _obscure,
      obscureConfirm: _obscureConfirm,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onToggleObscureConfirm: () =>
          setState(() => _obscureConfirm = !_obscureConfirm),
      onSignIn: _submitSignIn,
      onSignUp: _submitSignUp,
      onResetPassword: _resetPassword,
      rememberMe: _rememberMe,
      onRememberMeChanged: (v) => setState(() => _rememberMe = v),
    );

    if (wide) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFAFF),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: _HeroPanel(text: text, signup: signup),
            ),
            Expanded(
              flex: 6,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: form,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAFF),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroPanel(text: text, compact: true, signup: signup),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: form,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The colourful side of the auth screen: brand, a short promise, and what
/// learners get. Full height on wide screens, a header band on phones.
class _HeroPanel extends StatelessWidget {
  final TextTheme text;
  final bool compact;
  final bool signup;
  const _HeroPanel({
    required this.text,
    this.compact = false,
    this.signup = false,
  });

  @override
  Widget build(BuildContext context) {
    const features = [
      (
        AppTint.coral,
        Icons.translate_rounded,
        'Mandarin, maths and past questions',
      ),
      (
        AppTint.pink,
        Icons.sports_esports_rounded,
        'Live Rope Pull with classmates',
      ),
      (
        AppTint.mint,
        Icons.verified_rounded,
        'Lessons checked by real teachers',
      ),
      (AppTint.sun, Icons.cloud_done_rounded, 'Progress saved to your account'),
    ];
    final title = signup
        ? 'Join the fun.\nStart learning today.'
        : 'Welcome back.\nYour next step is ready.';
    final body = signup
        ? 'One account for learning, teaching, running a school, or following your child.'
        : 'Sign in to pick up your streak, your lessons, and your class.';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KidversityBrandMark(
          reversed: true,
          compact: compact,
          onTap: () => context.go(AppRoutes.home),
        ),
        SizedBox(height: compact ? 22 : 56),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: compact ? 28 : 44,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -1,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            body,
            style: TextStyle(
              fontSize: compact ? 15 : 17,
              height: 1.5,
              color: const Color(0xFFEDEAFF),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 36),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  TintIcon(tint: f.$1, icon: f.$2, size: 40),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      f.$3,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );

    final radius = compact
        ? const BorderRadius.vertical(bottom: Radius.circular(32))
        : BorderRadius.zero;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1F8F), Color(0xFF4433CC), Color(0xFF7B4FE8)],
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: compact ? -60 : -170,
              top: compact ? -70 : -190,
              child: _Blob(
                size: compact ? 180 : 320,
                color: const Color(0xFFFFC845),
              ),
            ),
            Positioned(
              left: -80,
              bottom: compact ? -110 : -90,
              child: _Blob(
                size: compact ? 160 : 260,
                color: const Color(0x99FF6B5B),
              ),
            ),
            if (!compact)
              Positioned(
                right: 60,
                bottom: 80,
                child: Transform.rotate(
                  angle: 0.4,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22B07D),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 56,
                  compact ? 14 : 36,
                  compact ? 20 : 56,
                  compact ? 56 : 40,
                ),
                child: compact
                    ? FadeInUp(child: content)
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: FadeInUp(child: content),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _FormCard extends StatelessWidget {
  final TabController tabs;
  final TextTheme text;
  final SupabaseAuthController auth;
  final TextEditingController email, password, confirmPassword, name, age;
  final String? gender;
  final ValueChanged<String?> onGenderChanged;
  final bool obscure, obscureConfirm;
  final VoidCallback onToggleObscure,
      onToggleObscureConfirm,
      onSignIn,
      onSignUp,
      onResetPassword;
  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;

  const _FormCard({
    required this.tabs,
    required this.text,
    required this.auth,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.name,
    required this.age,
    required this.gender,
    required this.onGenderChanged,
    required this.obscure,
    required this.obscureConfirm,
    required this.onToggleObscure,
    required this.onToggleObscureConfirm,
    required this.onSignIn,
    required this.onSignUp,
    required this.onResetPassword,
    required this.rememberMe,
    required this.onRememberMeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delay: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE9E6F5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A1F8F).withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EEFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: tabs,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.primary,
                labelStyle: text.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                tabs: const [
                  Tab(text: 'Sign in'),
                  Tab(text: 'Create account'),
                ],
              ),
            ),
            const SizedBox(height: 22),
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
                      confirmPassword: confirmPassword,
                      name: name,
                      age: age,
                      gender: gender,
                      onGenderChanged: onGenderChanged,
                      obscure: obscure,
                      obscureConfirm: obscureConfirm,
                      onToggleObscure: onToggleObscure,
                      onToggleObscureConfirm: onToggleObscureConfirm,
                      showName: true,
                    ),
            ),
            if (tabs.index == 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    height: 40,
                    child: Checkbox(
                      value: rememberMe,
                      activeColor: AppColors.primary,
                      onChanged: auth.isLoading
                          ? null
                          : (v) => onRememberMeChanged(v ?? false),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: auth.isLoading
                          ? null
                          : () => onRememberMeChanged(!rememberMe),
                      child: Text(
                        'Remember me',
                        style: text.bodyMedium?.copyWith(fontSize: 13.5),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onResetPassword,
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            GradientButton(
              label: auth.isLoading
                  ? 'Please wait…'
                  : (tabs.index == 0 ? 'Sign in' : 'Create account'),
              icon: Icons.arrow_forward_rounded,
              expand: true,
              onTap: auth.isLoading
                  ? null
                  : (tabs.index == 0 ? onSignIn : onSignUp),
            ),
            if (auth.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.lastError!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.danger,
                  fontSize: 13,
                ),
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
  final TextEditingController? confirmPassword, name, age;
  final String? gender;
  final ValueChanged<String?>? onGenderChanged;
  final bool obscure, obscureConfirm, showName;
  final VoidCallback onToggleObscure;
  final VoidCallback? onToggleObscureConfirm;

  static const _genderOptions = [('female', 'Female'), ('male', 'Male')];

  const _Fields({
    super.key,
    required this.email,
    required this.password,
    this.confirmPassword,
    this.name,
    this.age,
    this.gender,
    this.onGenderChanged,
    required this.obscure,
    this.obscureConfirm = true,
    required this.onToggleObscure,
    this.onToggleObscureConfirm,
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
            decoration: const InputDecoration(
              hintText: 'Your name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Email',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: obscure,
          textInputAction: showName
              ? TextInputAction.next
              : TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        if (showName && confirmPassword != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: confirmPassword,
            obscureText: obscureConfirm,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onToggleObscureConfirm,
                icon: Icon(
                  obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
        if (showName && onGenderChanged != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: gender,
            decoration: const InputDecoration(
              hintText: 'Gender',
              prefixIcon: Icon(Icons.wc_outlined),
            ),
            items: [
              for (final option in _genderOptions)
                DropdownMenuItem(value: option.$1, child: Text(option.$2)),
            ],
            onChanged: onGenderChanged,
          ),
        ],
        if (showName && age != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: age,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Age (5+)',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
          ),
        ],
      ],
    );
  }
}
