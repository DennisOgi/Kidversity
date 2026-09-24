import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_handler.dart' as app_errors;
import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/past_questions_models.dart';
import '../../models/rope_pull_models.dart';
import '../../router/navigation.dart';
import '../../services/mandarin_audio_service.dart';
import '../../services/rope_pull_questions.dart';
import '../../services/sdash_api_service.dart';
import 'past_questions_hub_screen.dart';
import '../../services/rope_pull_cue_service.dart';
import '../../services/rope_pull_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/rope_arena.dart';
import '../../widgets/rope_pull_arena.dart';
import '../../widgets/rope_pull_stage.dart';
import '../../widgets/rope_pull_visual_adapter.dart';
import 'maths_bank.dart';
import 'project_board.dart';

final ropePullRoomProvider = StreamProvider.autoDispose
    .family<RopePullSnapshot?, String>((ref, roomId) {
      return RopePullService.instance.watchRoom(roomId);
    });

class RopePullHubScreen extends ConsumerStatefulWidget {
  final bool hostPlays;
  final bool boardByDefault;

  const RopePullHubScreen({
    super.key,
    this.hostPlays = true,
    this.boardByDefault = false,
  });

  @override
  ConsumerState<RopePullHubScreen> createState() => _RopePullHubScreenState();
}

class _RopePullHubScreenState extends ConsumerState<RopePullHubScreen> {
  final _code = TextEditingController();
  final _university = TextEditingController();
  bool _busy = false;
  bool _examMatch = false;
  bool _mathsMatch = false;
  bool _examDefaultsApplied = false;
  int _deckLimit = 10;
  RopePullBank _bank = RopePullBank.lessons15;
  PastExamType? _exam;
  PastSubject? _subject;

  static const _mandarinBanks = [
    RopePullBank.lessons15,
    RopePullBank.module1,
    RopePullBank.dailyReview,
  ];

  @override
  void dispose() {
    _code.dispose();
    _university.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_examMatch) {
      await _createExamMatch();
      return;
    }
    if (_mathsMatch) {
      await _createMathsMatch();
      return;
    }
    final course = ref.read(mandarinCourseProvider).whenOrNull(data: (c) => c);
    final completed =
        ref
            .read(foundationCompletedLessonIdsProvider)
            .whenOrNull(data: (ids) => ids) ??
        const <String>{};
    if (course == null) {
      context.showErrorSnackbar('Load the path first, then try again.');
      return;
    }
    final words = vocabForRopeBank(
      course: course,
      bank: _bank,
      completedLessonIds: completed,
    );
    final questions = buildRopePullQuestions(words);
    if (questions.length < 4) {
      context.showErrorSnackbar('Need a few more unlocked words first.');
      return;
    }
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider);
    final result = await RopePullService.instance.createRoom(
      bank: _bank,
      questions: questions,
      hostPlays: widget.hostPlays,
      displayName: auth.displayName.isEmpty ? 'Host' : auth.displayName,
      avatar: auth.avatarEmoji.isEmpty ? '🦊' : auth.avatarEmoji,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure || result.data == null) {
      context.showErrorSnackbar(result.error ?? 'Could not open a room.');
      return;
    }
    final id = result.data!.room.id;
    context.go(
      widget.boardByDefault
          ? AppRoutes.teacherRope(id)
          : AppRoutes.studentRope(id),
    );
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      context.showErrorSnackbar('Enter the 4-letter code.');
      return;
    }
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider);
    final result = await RopePullService.instance.joinRoom(
      code: code,
      displayName: auth.displayName.isEmpty ? 'Learner' : auth.displayName,
      avatar: auth.avatarEmoji.isEmpty ? '🦊' : auth.avatarEmoji,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure || result.data == null) {
      context.showErrorSnackbar(result.error ?? 'Could not join.');
      return;
    }
    context.go(AppRoutes.studentRope(result.data!.room.id));
  }

  Future<void> _createMathsMatch() async {
    setState(() => _busy = true);
    final questions = buildMathsRopeDeck(count: _deckLimit);
    debugPrint('[Kidversity] Rope Pull maths deck ${questions.length}');
    if (questions.length < 4) {
      setState(() => _busy = false);
      context.showErrorSnackbar('Could not build a maths match.');
      return;
    }
    final auth = ref.read(authControllerProvider);
    final result = await _openRoom(
      bank: RopePullBank.maths,
      questions: questions,
      displayName: auth.displayName.isEmpty ? 'Host' : auth.displayName,
      avatar: auth.avatarEmoji.isEmpty ? '🦊' : auth.avatarEmoji,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure || result.data == null) {
      context.showErrorSnackbar(_roomError(result.error));
      return;
    }
    final id = result.data!.room.id;
    context.go(
      widget.boardByDefault
          ? AppRoutes.teacherRope(id)
          : AppRoutes.studentRope(id),
    );
  }

  Future<app_errors.Result<RopePullSnapshot>> _openRoom({
    required RopePullBank bank,
    required List<RopePullQuestion> questions,
    required String displayName,
    required String avatar,
  }) async {
    var useBank = bank;
    var deck = questions;
    app_errors.Result<RopePullSnapshot>? result;
    for (var attempt = 0; attempt < 3; attempt++) {
      result = await RopePullService.instance.createRoom(
        bank: useBank,
        questions: deck,
        hostPlays: widget.hostPlays,
        displayName: displayName,
        avatar: avatar,
      );
      final error = result.error ?? '';
      if (result.isSuccess) return result;
      // A rejection means the class-board migration is missing. That server
      // grades every answer against one shared question per round.
      if (error == 'INVALID_BANK' && useBank != RopePullBank.lessons15) {
        debugPrint('[Kidversity] Rope Pull bank ${useBank.wire} rejected');
        useBank = RopePullBank.lessons15;
        deck = sharedRopeDeck(deck);
        continue;
      }
      if (error == 'INVALID_QUESTIONS' &&
          (deck.length > 10 || deck.first.split)) {
        debugPrint(
          '[Kidversity] Rope Pull deck ${deck.length} rejected; sharing 10',
        );
        deck = sharedRopeDeck(deck);
        continue;
      }
      return result;
    }
    return result!;
  }

  String _roomError(String? error) {
    if (error == 'INVALID_BANK' || error == 'INVALID_QUESTIONS') {
      return 'This match could not be opened. Try a shorter paper.';
    }
    return error ?? 'Could not open a room.';
  }

  PastSubject? _defaultSubject(List<PastSubject> subjects) {
    for (final slug in const [
      'biology',
      'chemistry',
      'physics',
      'government',
    ]) {
      for (final subject in subjects) {
        if (subject.slug == slug && !subject.isSandboxLocked) return subject;
      }
    }
    for (final subject in subjects) {
      if (!subject.isSandboxLocked) return subject;
    }
    return subjects.isEmpty ? null : subjects.first;
  }

  void _ensureExamDefaults(PastQuestionsCatalog data) {
    if (_examDefaultsApplied || (_exam != null && _subject != null)) return;
    _examDefaultsApplied = true;
    final exam =
        _exam ??
        data.exams.cast<PastExamType?>().firstWhere(
          (item) => item?.slug == 'utme',
          orElse: () => data.exams.isEmpty ? null : data.exams.first,
        );
    if (exam == null) return;
    final subject =
        _subject ?? _defaultSubject(exam.subjectsFor(data.subjects));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _exam ??= exam;
        _subject ??= subject;
      });
    });
  }

  Future<void> _createExamMatch() async {
    final exam = _exam;
    final subject = _subject;
    if (exam == null || subject == null) {
      context.showErrorSnackbar('Pick an exam and a subject first.');
      return;
    }
    if (subject.isSandboxLocked) {
      context.showErrorSnackbar(
        '${subject.name} is unavailable on the current content plan.',
      );
      return;
    }
    setState(() => _busy = true);
    final fetched = await SdashApiService.instance.fetchQuestions(
      examSlug: exam.slug,
      subjectSlug: subject.slug,
      limit: 10,
      university: exam.isUniversityFamily ? _university.text : null,
    );
    if (!mounted) return;
    if (fetched.isFailure || fetched.data == null) {
      setState(() => _busy = false);
      context.showErrorSnackbar(fetched.error ?? 'Could not load questions.');
      return;
    }
    final questions = buildPastQuestionRopeDeck(
      fetched.data!,
      limit: _deckLimit,
    );
    debugPrint(
      '[Kidversity] Rope Pull exam deck ${questions.length} from ${fetched.data!.length} ${exam.slug}/${subject.slug}',
    );
    if (questions.length < 4) {
      setState(() => _busy = false);
      context.showErrorSnackbar(
        'This paper is too short for a match. Try another subject.',
      );
      return;
    }
    final auth = ref.read(authControllerProvider);
    final result = await _openRoom(
      bank: RopePullBank.pastQuestions,
      questions: questions,
      displayName: auth.displayName.isEmpty ? 'Host' : auth.displayName,
      avatar: auth.avatarEmoji.isEmpty ? '🦊' : auth.avatarEmoji,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure || result.data == null) {
      context.showErrorSnackbar(_roomError(result.error));
      return;
    }
    final id = result.data!.room.id;
    context.go(
      widget.boardByDefault
          ? AppRoutes.teacherRope(id)
          : AppRoutes.studentRope(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShellScrollView(
      children: [
        const RopePullHubBanner(),
        const SizedBox(height: 22),
        Text(
          'Join a friend',
          style: ropePullText(size: 18, weight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the four-letter courtyard code. Teams split on their own.',
          style: ropePullText(size: 14, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 4,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                  UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'CODE',
                ),
                style: const TextStyle(
                  letterSpacing: 8,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
                onSubmitted: (_) => _join(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: const Text('Join'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Or open a courtyard',
          style: ropePullText(size: 18, weight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MatchKindButton(
                label: 'Mandarin',
                selected: !_examMatch && !_mathsMatch,
                onTap: () => setState(() {
                  _examMatch = false;
                  _mathsMatch = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MatchKindButton(
                label: 'Exams',
                selected: _examMatch,
                onTap: () => setState(() {
                  _examMatch = true;
                  _mathsMatch = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MatchKindButton(
                label: 'Maths',
                selected: _mathsMatch,
                onTap: () => setState(() {
                  _mathsMatch = true;
                  _examMatch = false;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_examMatch || _mathsMatch) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final size in const [10, 20, 40])
                ChoiceChip(
                  label: Text('$size questions'),
                  selected: _deckLimit == size,
                  onSelected: (_) => setState(() => _deckLimit = size),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _deckLimit == size ? Colors.white : AppColors.ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Each team gets its own question. $_deckLimit questions is ${_deckLimit ~/ 2} rounds. A long match ends when the questions run out.',
            style: ropePullText(size: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
        ],
        if (!_examMatch && !_mathsMatch)
          for (final bank in _mandarinBanks) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: _bank == bank
                    ? AppColors.cinnabarSoft
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: InkWell(
                  onTap: () => setState(() => _bank = bank),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: _bank == bank
                            ? AppColors.cinnabar
                            : AppColors.line,
                        width: _bank == bank ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _bank == bank
                                ? AppColors.cinnabar
                                : AppColors.gold.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.sports_esports_rounded,
                            color: _bank == bank
                                ? Colors.white
                                : AppColors.cinnabar,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bank.title,
                                style: ropePullText(
                                  size: 16,
                                  weight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bank.subtitle,
                                style: ropePullText(
                                  size: 13,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]
        else if (_examMatch)
          _ExamMatchPicker(
            catalog: ref.watch(pastQuestionsCatalogProvider),
            exam: _exam,
            subject: _subject,
            university: _university,
            onEnsureDefaults: _ensureExamDefaults,
            onExam: (exam, subjects) {
              setState(() {
                _exam = exam;
                _subject = _defaultSubject(exam.subjectsFor(subjects));
              });
            },
            onSubject: (subject) => setState(() => _subject = subject),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Times tables, mixed sums, and one-step problems. No past-paper call. Phones answer. The board shows both sides.',
              style: ropePullText(size: 14, color: AppColors.inkSoft),
            ),
          ),
        GradientButton(
          label: _examMatch
              ? 'Create exam match'
              : _mathsMatch
              ? 'Create maths match'
              : (widget.hostPlays ? 'Create room' : 'Open class board'),
          icon: Icons.bolt_rounded,
          onTap: _busy ? null : _create,
          expand: true,
        ),
      ],
    );
  }
}

class _MatchKindButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MatchKindButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: ropePullText(
              size: 14,
              weight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExamMatchPicker extends StatelessWidget {
  final AsyncValue<PastQuestionsCatalog> catalog;
  final PastExamType? exam;
  final PastSubject? subject;
  final TextEditingController university;
  final void Function(PastQuestionsCatalog data) onEnsureDefaults;
  final void Function(PastExamType exam, List<PastSubject> subjects) onExam;
  final ValueChanged<PastSubject> onSubject;

  const _ExamMatchPicker({
    required this.catalog,
    required this.exam,
    required this.subject,
    required this.university,
    required this.onEnsureDefaults,
    required this.onExam,
    required this.onSubject,
  });

  @override
  Widget build(BuildContext context) {
    return catalog.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LinearProgressIndicator(minHeight: 3),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          'Exam practice is unavailable right now.',
          style: ropePullText(size: 14, color: AppColors.inkSoft),
        ),
      ),
      data: (data) {
        onEnsureDefaults(data);
        final subjects =
            exam?.subjectsFor(data.subjects) ?? const <PastSubject>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in data.exams)
                    ChoiceChip(
                      label: Text(item.shortLabel),
                      selected: exam?.slug == item.slug,
                      onSelected: (_) => onExam(item, data.subjects),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: exam?.slug == item.slug
                            ? Colors.white
                            : AppColors.ink,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: subjects.any((item) => item.slug == subject?.slug)
                    ? subject?.slug
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                items: [
                  for (final item in subjects)
                    DropdownMenuItem(
                      value: item.slug,
                      child: Text(
                        item.isSandboxLocked
                            ? '${item.name} · unavailable'
                            : item.name,
                      ),
                    ),
                ],
                onChanged: (slug) {
                  if (slug == null) return;
                  for (final item in subjects) {
                    if (item.slug == slug) {
                      onSubject(item);
                      return;
                    }
                  }
                },
              ),
              if (exam?.isUniversityFamily ?? false) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: university,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'University',
                    hintText: 'e.g. unilag',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Guests use the deck stored on the room. 25 seconds on an exam question, 15 on a sum.',
                style: ropePullText(size: 13, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class RopePullRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final bool boardMode;
  final String closeRoute;

  const RopePullRoomScreen({
    super.key,
    required this.roomId,
    this.boardMode = false,
    this.closeRoute = AppRoutes.studentPlay,
  });

  @override
  ConsumerState<RopePullRoomScreen> createState() => _RopePullRoomScreenState();
}

class _RopePullRoomScreenState extends ConsumerState<RopePullRoomScreen> {
  int _heardRound = -1;
  int _advanceRound = -1;
  bool _busy = false;
  bool _advancing = false;
  bool _submitting = false;
  int _submitRound = -1;
  Timer? _tick;
  DateTime _now = DateTime.now().toUtc();
  RopePullSnapshot? _lastSnap;
  late final RopeArenaController _arena;
  late final RopePullVisualAdapter _visual;
  late final RopePullCueService _cues;

  @override
  void initState() {
    super.initState();
    _cues = RopePullCueService();
    _arena = RopeArenaController(onCue: (name) => unawaited(_cues.play(name)));
    _visual = RopePullVisualAdapter(_arena);
    unawaited(
      _cues.load().then((_) {
        if (mounted) setState(() {});
      }),
    );
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    MandarinAudioService.instance.stop();
    _arena.dispose();
    unawaited(_cues.dispose());
    super.dispose();
  }

  int _remainingMs(RopePullSnapshot snap) {
    if (snap.room.status != RopePullStatus.playing) return 0;
    final started = snap.room.roundStartedAt;
    if (started == null) return 0;
    final limit = snap.room.roundSeconds * 1000;
    return (limit - _now.difference(started).inMilliseconds).clamp(0, limit);
  }

  void _bindVisual(RopePullSnapshot snap, {required bool reconnecting}) {
    _visual.applySnapshot(
      snap,
      reconnecting: reconnecting,
      remainingMs: _remainingMs(snap),
    );
  }

  void _syncSubmit(RopePullSnapshot snap, String? userId) {
    if (!_submitting) return;
    final confirmed =
        userId != null && snap.answerFor(userId, _submitRound) != null;
    final movedOn =
        snap.room.currentRound != _submitRound ||
        snap.room.status != RopePullStatus.playing;
    if (confirmed || movedOn) {
      _submitting = false;
    }
  }

  Future<void> _maybeAdvance(RopePullSnapshot snap, String? userId) async {
    if (snap.room.status != RopePullStatus.playing || _advancing) return;
    final started = snap.room.roundStartedAt;
    if (started == null) return;
    final elapsed = _now.difference(started).inMilliseconds / 1000;
    final allIn = snap.players.every(
      (player) => snap.answerFor(player.userId, snap.room.currentRound) != null,
    );
    final isHost = userId != null && userId == snap.room.hostId;
    final limit = snap.room.roundSeconds.toDouble();
    if (!(elapsed >= limit || (isHost && allIn && elapsed >= 1.2))) return;
    if (_advanceRound == snap.room.currentRound) return;
    _advanceRound = snap.room.currentRound;
    _advancing = true;
    await RopePullService.instance.advance(widget.roomId);
    _advancing = false;
  }

  void _maybeSpeak(RopePullSnapshot snap) {
    if (snap.room.status != RopePullStatus.playing) return;
    final question = snap.room.currentQuestion;
    if (question == null || question.isExamPrompt) return;
    if (_heardRound == snap.room.currentRound) return;
    _heardRound = snap.room.currentRound;
    MandarinAudioService.instance.play(
      text: question.simplified,
      audioUrl: question.audioUrl,
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    context.showErrorSnackbar(message);
  }

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.instance.currentUser?.id;
    final async = ref.watch(ropePullRoomProvider(widget.roomId));
    return async.when(
      loading: () {
        final cached = _lastSnap;
        if (cached != null) {
          return _roomScaffold(cached, userId: userId, reconnecting: true);
        }
        return const Scaffold(
          body: LoadingIndicator(message: 'Opening the rope…'),
        );
      },
      error: (error, _) {
        final cached = _lastSnap;
        if (cached != null) {
          return _roomScaffold(cached, userId: userId, reconnecting: true);
        }
        return Scaffold(
          body: ErrorDisplay(
            message: 'This room could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(ropePullRoomProvider(widget.roomId)),
          ),
        );
      },
      data: (snap) {
        if (snap == null) {
          final cached = _lastSnap;
          if (cached != null) {
            return _roomScaffold(cached, userId: userId, reconnecting: true);
          }
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Room not found.')),
          );
        }
        _lastSnap = snap;
        _maybeSpeak(snap);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final wasSubmitting = _submitting;
          _syncSubmit(snap, userId);
          _bindVisual(snap, reconnecting: false);
          _maybeAdvance(snap, userId);
          if (wasSubmitting != _submitting) setState(() {});
        });
        return _roomScaffold(snap, userId: userId, reconnecting: false);
      },
    );
  }

  Widget _roomScaffold(
    RopePullSnapshot snap, {
    required String? userId,
    required bool reconnecting,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bindVisual(snap, reconnecting: reconnecting);
    });
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEEBFF), AppColors.paper, Color(0xFFE8F3F3)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _RoomHeader(
                title: snap.room.roundLabel,
                soundOn: _cues.enabled,
                onToggleSound: () async {
                  await _cues.setEnabled(!_cues.enabled);
                  if (mounted) setState(() {});
                },
                onProject: widget.boardMode
                    ? null
                    : () => projectRopeBoard(
                        context,
                        AppRoutes.studentRopeBoard(widget.roomId),
                      ),
                onClose: () => context.go(widget.closeRoute),
              ),
              if (reconnecting) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: switch (snap.room.status) {
                  RopePullStatus.lobby => _Lobby(
                    snap: snap,
                    controller: _arena,
                    userId: userId,
                    boardMode: widget.boardMode,
                    busy: _busy,
                    onStart: () async {
                      setState(() => _busy = true);
                      final result = await RopePullService.instance.startRoom(
                        widget.roomId,
                      );
                      if (!mounted) return;
                      setState(() => _busy = false);
                      if (result.isFailure) {
                        _toast(result.error ?? 'Need two players to start.');
                      }
                    },
                  ),
                  RopePullStatus.playing => _Play(
                    snap: snap,
                    controller: _arena,
                    userId: userId,
                    now: _now,
                    boardMode: widget.boardMode,
                    submitting: _submitting,
                    onAnswer: (choice) {
                      if (_submitting) return;
                      HapticFeedback.selectionClick();
                      setState(() {
                        _submitting = true;
                        _submitRound = snap.room.currentRound;
                      });
                      unawaited(_submit(choice, snap.room.currentRound));
                    },
                  ),
                  RopePullStatus.finished => _Finish(
                    snap: snap,
                    controller: _arena,
                    userId: userId,
                    boardMode: widget.boardMode,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(String choice, int round) async {
    final result = await RopePullService.instance.submitAnswer(
      roomId: widget.roomId,
      round: round,
      selected: choice,
    );
    if (!mounted) return;
    if (result.isFailure) {
      setState(() => _submitting = false);
      _toast(result.error ?? 'That answer could not be sent.');
    }
  }
}

class _RoomHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onProject;
  final bool soundOn;
  final VoidCallback? onToggleSound;

  const _RoomHeader({
    required this.title,
    required this.onClose,
    this.onProject,
    this.soundOn = false,
    this.onToggleSound,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClose),
          if (onProject != null)
            TextButton.icon(
              onPressed: onProject,
              icon: const Icon(Icons.cast_rounded),
              label: const Text('Project'),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rope Pull',
                  style: ropePullText(size: 20, weight: FontWeight.w800),
                ),
                Text(
                  title,
                  style: ropePullText(
                    size: 13,
                    color: AppColors.inkSoft,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onToggleSound != null)
            IconButton(
              tooltip: soundOn ? 'Mute courtyard sounds' : 'Unmute sounds',
              icon: Icon(
                soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              ),
              onPressed: onToggleSound,
            ),
        ],
      ),
    );
  }
}

class _Lobby extends StatelessWidget {
  final RopePullSnapshot snap;
  final RopeArenaController controller;
  final String? userId;
  final bool boardMode;
  final bool busy;
  final VoidCallback onStart;

  const _Lobby({
    required this.snap,
    required this.controller,
    required this.userId,
    required this.boardMode,
    required this.busy,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final isHost = userId != null && userId == snap.room.hostId;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Text(
          boardMode ? 'Class courtyard' : 'The courtyard is open',
          style: ropePullText(size: 22, weight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Share the code. Indigo and Teal fill on their own.',
          style: ropePullText(size: 14, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: snap.room.joinCode));
            if (context.mounted) {
              context.showSuccessSnackbar('Code copied');
            }
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            decoration: BoxDecoration(
              gradient: AppColors.mandarinGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  boardMode ? 'PROJECT THIS CODE' : 'COURTYARD CODE',
                  style: ropePullText(
                    size: 12,
                    weight: FontWeight.w800,
                    color: AppColors.gold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snap.room.joinCode,
                  style: ropePullText(
                    size: 48,
                    weight: FontWeight.w800,
                    color: AppColors.paper,
                    height: 1,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to copy',
                  style: ropePullText(
                    size: 13,
                    color: AppColors.paper.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        RopePullKitScene(controller: controller, maxHeight: 280),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _TeamLane(
                title: 'Indigo',
                color: kRopeIndigo,
                players: snap.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TeamLane(
                title: 'Teal',
                color: kRopeTeal,
                players: snap.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (isHost)
          GradientButton(
            label: snap.players.length < 2
                ? 'Waiting for a friend…'
                : 'Start the pull',
            icon: Icons.flag_rounded,
            onTap: busy || snap.players.length < 2 ? null : onStart,
            expand: true,
          )
        else
          Text(
            'Wait for the host to start the pull.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
      ],
    );
  }
}

class _TeamLane extends StatelessWidget {
  final String title;
  final Color color;
  final List<RopePullPlayer> players;

  const _TeamLane({
    required this.title,
    required this.color,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ropePullText(
              size: 14,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          if (players.isEmpty)
            Text('Waiting…', style: Theme.of(context).textTheme.bodyMedium)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final player in players)
                  Chip(
                    avatar: EmojiText(player.avatar, size: 16),
                    label: Text(player.displayName),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Play extends StatelessWidget {
  final RopePullSnapshot snap;
  final RopeArenaController controller;
  final String? userId;
  final DateTime now;
  final bool boardMode;
  final bool submitting;
  final ValueChanged<String> onAnswer;

  const _Play({
    required this.snap,
    required this.controller,
    required this.userId,
    required this.now,
    required this.boardMode,
    required this.submitting,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final team = userId == null
        ? 'blue'
        : (snap.playerFor(userId)?.team ?? 'blue');
    final question = snap.room.questionFor(team);
    if (question == null) return const SizedBox.shrink();
    final started = snap.room.roundStartedAt ?? now;
    final seconds = snap.room.roundSeconds.toDouble();
    final remaining = (seconds - now.difference(started).inMilliseconds / 1000)
        .clamp(0.0, seconds);
    final exam = question.isExamPrompt;
    final allAnswered =
        snap.players.isNotEmpty &&
        snap.players.every(
          (player) =>
              snap.answerFor(player.userId, snap.room.currentRound) != null,
        );
    if (boardMode) {
      return RopePullStage(
        snap: snap,
        controller: controller,
        remaining: remaining,
        seconds: seconds,
        reveal: remaining <= 0 || allAnswered,
        blueQuestion: snap.room.questionFor('blue'),
        redQuestion: snap.room.questionFor('red'),
      );
    }
    final mine = userId == null
        ? null
        : snap.answerFor(userId!, snap.room.currentRound);
    final showReveal = mine != null || remaining <= 0;
    final canAnswer =
        !boardMode && userId != null && snap.playerFor(userId) != null;
    final locked = mine != null || submitting;
    final optionKeys = <ShortcutActivator, VoidCallback>{};
    if (canAnswer && !locked) {
      const letters = [
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyD,
      ];
      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ];
      for (var i = 0; i < question.options.length && i < 4; i++) {
        final choice = question.options[i];
        optionKeys[SingleActivator(letters[i])] = () => onAnswer(choice);
        optionKeys[SingleActivator(digits[i])] = () => onAnswer(choice);
      }
    }
    return CallbackShortcuts(
      bindings: optionKeys,
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Round ${snap.room.currentRound + 1} of ${snap.room.roundCount}',
                    style: ropePullText(size: 15, weight: FontWeight.w800),
                  ),
                  const Spacer(),
                  _LanternTimer(
                    value: remaining / seconds,
                    label: remaining.ceil(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RopePullKitScene(
                controller: controller,
                maxHeight: exam
                    ? (MediaQuery.sizeOf(context).width >= 700 ? 220 : 180)
                    : (MediaQuery.sizeOf(context).width >= 700 ? 300 : 250),
              ),
              const SizedBox(height: 10),
              if (exam)
                Expanded(
                  flex: 2,
                  child: _ExamPrompt(
                    prompt: question.prompt!,
                    solution: showReveal ? question.solution : null,
                  ),
                )
              else
                _ListenBar(
                  onListen: () => MandarinAudioService.instance.play(
                    text: question.simplified,
                    audioUrl: question.audioUrl,
                  ),
                  simplified: showReveal ? question.simplified : null,
                  pinyin: showReveal ? question.pinyin : null,
                ),
              const SizedBox(height: 10),
              if (canAnswer && exam)
                Expanded(
                  flex: 3,
                  child: ListView(
                    children: [
                      for (final option in question.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TapTile(
                            label: option,
                            locked: locked,
                            selected: mine?.selected == option,
                            correct: showReveal && option == question.answer,
                            onTap: locked ? null : () => onAnswer(option),
                          ),
                        ),
                    ],
                  ),
                )
              else if (canAnswer)
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < question.options.length; i += 2)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TapTile(
                                    label: question.options[i],
                                    locked: locked,
                                    selected:
                                        mine?.selected == question.options[i],
                                    correct:
                                        showReveal &&
                                        question.options[i] == question.answer,
                                    onTap: locked
                                        ? null
                                        : () => onAnswer(question.options[i]),
                                  ),
                                ),
                                if (i + 1 < question.options.length) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _TapTile(
                                      label: question.options[i + 1],
                                      locked: locked,
                                      selected:
                                          mine?.selected ==
                                          question.options[i + 1],
                                      correct:
                                          showReveal &&
                                          question.options[i + 1] ==
                                              question.answer,
                                      onTap: locked
                                          ? null
                                          : () => onAnswer(
                                              question.options[i + 1],
                                            ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Text(
                  remaining > 0
                      ? 'Phones are answering…'
                      : 'Next round coming up',
                  style: ropePullText(size: 16, weight: FontWeight.w800),
                ),
              if (submitting && mine == null) ...[
                const SizedBox(height: 6),
                Text(
                  'Sending…',
                  style: ropePullText(size: 13, color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamPrompt extends StatelessWidget {
  final String prompt;
  final String? solution;

  const _ExamPrompt({required this.prompt, this.solution});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prompt,
              style: ropePullText(
                size: 16,
                weight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (solution != null && solution!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                solution!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: ropePullText(size: 13, color: AppColors.inkSoft),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListenBar extends StatelessWidget {
  final VoidCallback onListen;
  final String? simplified;
  final String? pinyin;

  const _ListenBar({required this.onListen, this.simplified, this.pinyin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.cinnabar,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onListen,
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(Icons.volume_up_rounded, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: simplified == null
                ? Text(
                    'Listen, then tap the meaning.',
                    style: ropePullText(size: 15, weight: FontWeight.w800),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        simplified!,
                        style: ropePullText(
                          size: 28,
                          weight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        pinyin ?? '',
                        style: ropePullText(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.cinnabar,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TapTile extends StatelessWidget {
  final String label;
  final bool locked;
  final bool selected;
  final bool correct;
  final VoidCallback? onTap;

  const _TapTile({
    required this.label,
    required this.locked,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.line;
    Color fill = AppColors.surface;
    if (correct) {
      border = AppColors.jade;
      fill = AppColors.successSoft;
    } else if (selected && locked) {
      border = AppColors.cinnabar;
      fill = AppColors.cinnabarSoft;
    }
    return AnimatedScale(
      scale: selected ? 1.03 : 1,
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        elevation: selected ? 2 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border, width: 1.8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: ropePullText(size: 16, weight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanternTimer extends StatelessWidget {
  final double value;
  final int label;

  const _LanternTimer({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final hot = value < 0.3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hot ? AppColors.cinnabar : AppColors.gold),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 3.4,
              color: hot ? AppColors.cinnabar : AppColors.jade,
              backgroundColor: AppColors.line,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '0:${label.toString().padLeft(2, '0')}',
            style: ropePullText(
              size: 14,
              weight: FontWeight.w800,
              color: hot ? AppColors.cinnabar : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Finish extends StatelessWidget {
  final RopePullSnapshot snap;
  final RopeArenaController controller;
  final String? userId;
  final bool boardMode;

  const _Finish({
    required this.snap,
    required this.controller,
    required this.userId,
    required this.boardMode,
  });

  @override
  Widget build(BuildContext context) {
    final outcome = snap.outcome;
    final color = switch (outcome) {
      RopePullOutcome.blue => kRopeIndigo,
      RopePullOutcome.red => kRopeTeal,
      RopePullOutcome.draw => AppColors.gold,
    };
    final title = switch (outcome) {
      RopePullOutcome.blue => 'Indigo wins!',
      RopePullOutcome.red => 'Teal wins!',
      RopePullOutcome.draw => 'It’s a draw',
    };
    final subtitle = switch (outcome) {
      RopePullOutcome.blue => 'Indigo pulled Teal across the line.',
      RopePullOutcome.red => 'Teal pulled Indigo across the line.',
      RopePullOutcome.draw => 'The rope never crossed the line.',
    };
    final me = snap.playerFor(userId);
    final myTeamWon =
        me != null &&
        ((outcome == RopePullOutcome.blue && me.isBlue) ||
            (outcome == RopePullOutcome.red && !me.isBlue));
    final missed = userId == null
        ? const <RopePullQuestion>[]
        : snap.missedBy(userId!);
    final mineCorrect = userId == null ? 0 : snap.correctCountFor(userId!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              EmojiText(
                outcome == RopePullOutcome.draw ? '🪢' : '🏆',
                size: 42,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ropePullText(
                  size: 28,
                  weight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: ropePullText(size: 15, color: AppColors.inkSoft),
              ),
              if (me != null) ...[
                const SizedBox(height: 10),
                Text(
                  myTeamWon
                      ? 'Your team took the courtyard'
                      : outcome == RopePullOutcome.draw
                      ? 'You held the line'
                      : 'So close — try another pull',
                  textAlign: TextAlign.center,
                  style: ropePullText(size: 16, weight: FontWeight.w800),
                ),
                Text(
                  'You got $mineCorrect of ${snap.room.roundCount}',
                  style: ropePullText(size: 14, color: AppColors.inkSoft),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ScorePill(
                      title: 'Indigo',
                      score: snap.blueTugs,
                      color: kRopeIndigo,
                      won: outcome == RopePullOutcome.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ScorePill(
                      title: 'Teal',
                      score: snap.redTugs,
                      color: kRopeTeal,
                      won: outcome == RopePullOutcome.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RopePullKitScene(controller: controller, maxHeight: 280),
        const SizedBox(height: 22),
        Text(
          missed.isEmpty
              ? (snap.room.isExamMatch
                    ? 'You caught every question.'
                    : 'You caught every word.')
              : (snap.room.isExamMatch
                    ? 'Questions to review'
                    : 'Words to hear again'),
          style: ropePullText(size: 18, weight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final word in missed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.isExamPrompt ? word.prompt! : word.simplified,
                          maxLines: word.isExamPrompt ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: ropePullText(
                            size: word.isExamPrompt ? 15 : 28,
                            weight: FontWeight.w800,
                          ),
                        ),
                        if (!word.isExamPrompt) ...[
                          Text(
                            word.pinyin,
                            style: ropePullText(
                              size: 14,
                              color: AppColors.cinnabar,
                            ),
                          ),
                          Text(
                            word.english,
                            style: ropePullText(
                              size: 14,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ] else
                          Text(
                            word.answer,
                            style: ropePullText(
                              size: 14,
                              color: AppColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!word.isExamPrompt)
                    IconButton.filled(
                      onPressed: () => MandarinAudioService.instance.play(
                        text: word.simplified,
                        audioUrl: word.audioUrl,
                      ),
                      icon: const Icon(Icons.volume_up_rounded),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        GradientButton(
          label: 'Play again',
          icon: Icons.replay_rounded,
          expand: true,
          onTap: () => context.go(
            boardMode ? AppRoutes.teacherPlay : AppRoutes.studentPlay,
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String title;
  final int score;
  final Color color;
  final bool won;

  const _ScorePill({
    required this.title,
    required this.score,
    required this.color,
    required this.won,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: won ? color : AppColors.line,
          width: won ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: ropePullText(
              size: 13,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            '$score',
            style: ropePullText(
              size: 28,
              weight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
