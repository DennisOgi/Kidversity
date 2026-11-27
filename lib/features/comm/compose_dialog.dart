import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/comm_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';

/// A pupil the teacher can send a private update about.
typedef ComposePupil = ({String id, String name});

/// Write a class announcement or a private update to one pupil's guardians.
/// Returns true when sent.
Future<bool> showComposeDialog(
  BuildContext context,
  WidgetRef ref, {
  required String classId,
  required List<ComposePupil> pupils,
  String? pupilId,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _ComposeDialog(classId: classId, pupils: pupils, pupilId: pupilId),
  );
  if (sent == true) ref.invalidate(classMessagesProvider(classId));
  return sent == true;
}

class _ComposeDialog extends StatefulWidget {
  final String classId;
  final List<ComposePupil> pupils;
  final String? pupilId;

  const _ComposeDialog({
    required this.classId,
    required this.pupils,
    this.pupilId,
  });

  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  late bool _private = widget.pupilId != null;
  late String? _pupil =
      widget.pupilId ?? (widget.pupils.isEmpty ? null : widget.pupils.first.id);
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _needsAck = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_subject.text.trim().length < 2) {
      setState(() => _error = 'Add a short subject line.');
      return;
    }
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Write a message first.');
      return;
    }
    if (_private && _pupil == null) {
      setState(() => _error = 'Choose a pupil.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await CommService.instance.post(
        classId: widget.classId,
        private: _private,
        studentId: _private ? _pupil : null,
        subject: _subject.text.trim(),
        body: _body.text.trim(),
        needsAck: _needsAck,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _sending = false;
        _error = CommService.errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New message'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.campaign_rounded),
                    label: Text('Whole class'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.lock_rounded),
                    label: Text('One family'),
                  ),
                ],
                selected: {_private},
                onSelectionChanged: (v) => setState(() => _private = v.first),
              ),
              const SizedBox(height: 8),
              Text(
                _private
                    ? 'Only this pupil\'s linked parents or guardians will see it. They can reply.'
                    : 'Every linked parent or guardian in the class will see it.',
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
              const SizedBox(height: 14),
              if (_private)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _pupil,
                    decoration: const InputDecoration(labelText: 'About'),
                    items: [
                      for (final p in widget.pupils)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) => setState(() => _pupil = v),
                  ),
                ),
              TextField(
                controller: _subject,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Trip to the science museum',
                ),
              ),
              TextField(
                controller: _body,
                minLines: 5,
                maxLines: 12,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _needsAck,
                onChanged: (v) => setState(() => _needsAck = v),
                title: const Text('Ask parents to acknowledge'),
                subtitle: const Text(
                  'They confirm they have read it. You see who has and who has not.',
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Color(0xFFA61F2D))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          style: FilledButton.styleFrom(backgroundColor: AppTint.mint.ink),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(_sending ? 'Sending…' : 'Send'),
        ),
      ],
    );
  }
}
