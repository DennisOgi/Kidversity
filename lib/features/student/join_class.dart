import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

/// Opens the "Join a class" dialog where a student enters a teacher's code.
Future<void> showJoinClassDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _JoinClassDialog(),
  ).then((_) => ref.invalidate(activeLiveTestProvider));
}

class _JoinClassDialog extends ConsumerStatefulWidget {
  const _JoinClassDialog();

  @override
  ConsumerState<_JoinClassDialog> createState() => _JoinClassDialogState();
}

class _JoinClassDialogState extends ConsumerState<_JoinClassDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code your teacher shared.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await SupabaseService.instance.joinClassWithCode(code);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isFailure) {
      setState(() => _error = result.error ?? 'Could not join the class.');
      return;
    }

    ref.invalidate(activeLiveTestProvider);
    Navigator.of(context).pop();
    context.showSuccessSnackbar('You joined ${result.data}! 🎉');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎟️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text('Join a class', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Ask your teacher for the class code, then enter it below.',
              style: text.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: text.headlineSmall?.copyWith(
                letterSpacing: 6,
                fontSize: 26,
              ),
              inputFormatters: [
                UpperCaseTextFormatter(),
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              ],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'ABC123',
                counterText: '',
                errorText: _error,
                hintStyle: text.headlineSmall?.copyWith(
                  letterSpacing: 6,
                  fontSize: 26,
                  color: AppColors.muted.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: _submitting ? 'Joining…' : 'Join',
                    expand: true,
                    onTap: _submitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable callout that prompts a student to join a class.
class JoinClassCard extends ConsumerWidget {
  const JoinClassCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      gradient: AppColors.brandGradient,
      onTap: () => showJoinClassDialog(context, ref),
      child: Row(
        children: [
          const Text('🎟️', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join your class',
                  style: text.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Enter the code from your teacher to join your class.',
                  style: text.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_circle_right_rounded,
            color: Colors.white,
            size: 30,
          ),
        ],
      ),
    );
  }
}

/// Forces text input to uppercase (class codes are case-insensitive but shown upper).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
