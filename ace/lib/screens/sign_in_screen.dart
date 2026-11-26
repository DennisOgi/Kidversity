import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _create = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 8) {
      setState(
        () => _error =
            'Enter your email and a password of at least 8 characters.',
      );
      return;
    }
    if (_create && _name.text.trim().length < 2) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_create) {
        final res = await auth.signUp(
          email: email,
          password: password,
          data: {'display_name': _name.text.trim()},
        );
        if (res.session == null && mounted) {
          setState(
            () => _notice =
                'Check your email to confirm your account, then sign in.',
          );
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach ACE. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!wide) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AceWordmark(),
                ),
                const SizedBox(height: 28),
              ],
              Text(
                _create ? 'Create your ACE account' : 'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _create
                    ? 'Your school gives you a code to join after you sign up.'
                    : 'Sign in to continue your AS and A2 study.',
                style: const TextStyle(color: Ace.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (_create) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Ace.bad)),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Text(_notice!, style: const TextStyle(color: Ace.good)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Please wait…'
                      : _create
                      ? 'Create account'
                      : 'Sign in',
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _create = !_create;
                        _error = null;
                        _notice = null;
                      }),
                child: Text(
                  _create
                      ? 'I already have an account'
                      : 'New to ACE? Create an account',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!wide) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: form),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(child: _Hero()),
          Expanded(child: form),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Ace.navy, Ace.navySoft],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AceWordmark(onDark: true),
          const Spacer(),
          Text(
            'Advance.\nConquer.\nExcel.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 56,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cambridge AS and A2 Mathematics and Physics. Study a topic, write '
            'out your working, check your answer and learn from a worked solution.',
            style: TextStyle(
              color: Color(0xFFC9D3E6),
              fontSize: 16,
              height: 1.55,
            ),
          ),
          const Spacer(),
          const Row(
            children: [
              _Pill('AS Mathematics'),
              SizedBox(width: 8),
              _Pill('A2 Mathematics'),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _Pill('AS Physics'),
              SizedBox(width: 8),
              _Pill('A2 Physics'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
