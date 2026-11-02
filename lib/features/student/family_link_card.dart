import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../services/family_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

/// Me → Family: a learner links to their parent with the parent's code.
class FamilyLinkCard extends ConsumerStatefulWidget {
  const FamilyLinkCard({super.key});

  @override
  ConsumerState<FamilyLinkCard> createState() => _FamilyLinkCardState();
}

class _FamilyLinkCardState extends ConsumerState<FamilyLinkCard> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await FamilyService.instance.join(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure) {
      setState(() => _error = result.error);
      return;
    }
    _code.clear();
    ref.invalidate(paymentAccessProvider);
    context.showSuccessSnackbar('You are linked to ${result.data}.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final access = ref
        .watch(paymentAccessProvider)
        .whenOrNull(data: (value) => value);
    final linked = access?.hasGuardian ?? false;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SoftIcon(
                icon: Icons.family_restroom_rounded,
                color: AppColors.success,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Family', style: text.titleMedium),
                    Text(
                      linked
                          ? 'Your parent can see your progress.'
                          : 'Ask your parent for their family code so they can follow your progress.',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (linked) const Pill(label: 'Linked', color: AppColors.success),
            ],
          ),
          if (!linked) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _join(),
                    decoration: InputDecoration(
                      hintText: 'FAM-XXXXX',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.password_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy ? null : _join,
                  child: Text(_busy ? 'Linking…' : 'Link'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
