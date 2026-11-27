import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/results_models.dart';
import '../../services/results_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/kv_ui.dart';

String _date(DateTime? d) {
  if (d == null) return '';
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${m[d.month - 1]}';
}

/// Support actions on a pupil profile: what will be done, by whom, by when,
/// and how it went. Staff add and update them; the pupil and family see the
/// ones shared with them.
class SupportSection extends ConsumerWidget {
  final PupilProfile profile;

  const SupportSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(supportActionsProvider(profile.studentId));
    final list = actions.value ?? const <SupportAction>[];
    final open = list.where((a) => a.isOpen).toList();
    final closed = list.where((a) => !a.isOpen).toList();
    final canEdit = profile.canEdit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KvSectionTitle(
          title: 'Support actions',
          subtitle: canEdit
              ? 'Plan the next steps for ${firstName(profile.displayName)} and track how they went.'
              : 'What the school is doing to help, and how it is going.',
          action: canEdit
              ? FilledButton.icon(
                  onPressed: () => showSupportDialog(context, ref, profile),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add action'),
                )
              : null,
        ),
        if (actions.isLoading && list.isEmpty)
          const KvCard(child: Center(child: CircularProgressIndicator()))
        else if (actions.hasError)
          KvCard(
            child: Row(
              children: [
                const Expanded(
                  child: Text('Support actions could not be loaded.'),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(supportActionsProvider(profile.studentId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          )
        else if (list.isEmpty)
          KvCard(
            tint: AppTint.mint,
            child: Row(
              children: [
                const TintIcon(
                  tint: AppTint.mint,
                  icon: Icons.volunteer_activism_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    canEdit
                        ? 'No support actions yet. Add one when a pupil needs extra help, for example after a score below target.'
                        : 'No support actions at the moment.',
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final a in open) _ActionCard(action: a, profile: profile),
          if (closed.isNotEmpty)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  'Completed and cancelled (${closed.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
                children: [
                  for (final a in closed)
                    _ActionCard(action: a, profile: profile),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ActionCard extends ConsumerWidget {
  final SupportAction action;
  final PupilProfile profile;

  const _ActionCard({required this.action, required this.profile});

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    String? outcome;
    if (status == 'done') {
      final ctrl = TextEditingController();
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Mark as done'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'How did it go? (optional)',
              hintText: 'Scored 72% on the next fractions test.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Mark done'),
            ),
          ],
        ),
      );
      if (go != true) return;
      outcome = ctrl.text;
    }
    try {
      await ResultsService.instance.setSupportStatus(
        action.id,
        status,
        outcome: outcome,
      );
      ref.invalidate(supportActionsProvider(profile.studentId));
      ref.invalidate(classResultsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ResultsService.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = action;
    final (label, tint) = switch (a.status) {
      'done' => ('Done', AppTint.mint),
      'cancelled' => ('Cancelled', AppTint.slate),
      _ => a.isOverdue ? ('Overdue', StatusChip.alert) : ('Open', AppTint.sky),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KvCard(
        tint: a.isOpen ? tint : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TintIcon(
              tint: tint,
              icon: a.status == 'done'
                  ? Icons.check_circle_rounded
                  : a.status == 'cancelled'
                  ? Icons.block_rounded
                  : Icons.flag_circle_rounded,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.action,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      decoration: a.status == 'cancelled'
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(label: label, tint: tint),
                      if (a.subject != null)
                        StatusChip(label: a.subject!, tint: AppTint.violet),
                      if (a.owner != null)
                        Text(
                          'Who: ${a.owner}',
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                      if (a.dueOn != null)
                        Text(
                          'Due ${_date(a.dueOn)}',
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                      if (profile.canEdit && !a.shared)
                        const Text(
                          'Staff only',
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                  if ((a.outcome ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Outcome: ${a.outcome}',
                      style: const TextStyle(color: AppColors.ink, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            if (profile.canEdit)
              PopupMenuButton<String>(
                tooltip: 'Update',
                onSelected: (v) {
                  if (v == 'edit') {
                    showSupportDialog(context, ref, profile, existing: a);
                  } else {
                    _setStatus(context, ref, v);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (a.isOpen)
                    const PopupMenuItem(
                      value: 'done',
                      child: Text('Mark as done'),
                    ),
                  if (a.isOpen)
                    const PopupMenuItem(
                      value: 'cancelled',
                      child: Text('Cancel action'),
                    ),
                  if (!a.isOpen)
                    const PopupMenuItem(value: 'open', child: Text('Reopen')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit a support action.
Future<void> showSupportDialog(
  BuildContext context,
  WidgetRef ref,
  PupilProfile profile, {
  SupportAction? existing,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _SupportDialog(profile: profile, existing: existing),
  );
  if (saved == true) {
    ref.invalidate(supportActionsProvider(profile.studentId));
    ref.invalidate(classResultsProvider);
  }
}

class _SupportDialog extends StatefulWidget {
  final PupilProfile profile;
  final SupportAction? existing;

  const _SupportDialog({required this.profile, this.existing});

  @override
  State<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<_SupportDialog> {
  late final _action = TextEditingController(
    text: widget.existing?.action ?? '',
  );
  late final _owner = TextEditingController(text: widget.existing?.owner ?? '');
  late String? _subject = widget.existing?.subjectId;
  late DateTime? _due = widget.existing?.dueOn;
  late bool _shared = widget.existing?.shared ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _action.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_action.text.trim().length < 3) {
      setState(() => _error = 'Describe the action in a few words.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ResultsService.instance.saveSupportAction(
        studentId: widget.profile.studentId,
        id: widget.existing?.id,
        action: _action.text.trim(),
        subjectId: _subject,
        owner: _owner.text.trim(),
        dueOn: _due,
        shared: _shared,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = ResultsService.message(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = widget.profile.subjects;
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Support for ${firstName(widget.profile.displayName)}'
            : 'Edit support action',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _action,
                autofocus: true,
                maxLength: 500,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Action',
                  hintText:
                      'Extra fractions practice twice a week before the next test.',
                ),
              ),
              const SizedBox(height: 8),
              if (subjects.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: _subject,
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('General')),
                    for (final s in subjects)
                      DropdownMenuItem(value: s.subjectId, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _subject = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _owner,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Who does it (optional)',
                  hintText: 'Class teacher, parent, pupil…',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _due == null ? 'No due date' : 'Due ${_date(_due)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_due != null)
                    TextButton(
                      onPressed: () => setState(() => _due = null),
                      child: const Text('Clear'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _due ?? now.add(const Duration(days: 14)),
                        firstDate: now.subtract(const Duration(days: 30)),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _due = picked);
                    },
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: const Text('Due date'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shared,
                onChanged: (v) => setState(() => _shared = v),
                title: const Text('Share with the pupil and family'),
                subtitle: const Text('Turn off for staff-only notes.'),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Color(0xFFA61F2D))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
