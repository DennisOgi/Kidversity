import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/models.dart';
import '../../services/narration_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/common.dart';

enum _Phase { slides, checkpoints, complete }

class LessonPlayer extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonPlayer({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends ConsumerState<LessonPlayer> {
  Lesson? lesson;
  bool _loadingLesson = true;
  String? _loadError;
  _Phase _phase = _Phase.slides;
  int _slideIndex = 0;

  // Audio playback state (driven by NarrationService).
  Timer? _timer;
  double _position = 0; // seconds into current slide audio
  bool _playing = false;
  bool _showCaption = true;
  double _rate = 0.9; // narration speed

  // Checkpoint state.
  int _cpIndex = 0;
  String? _selectedOptionId;
  bool _answered = false;
  int _correctCount = 0;
  bool _completionSaved = false;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    final catalog = ref.read(lessonsProvider);
    for (final item in catalog) {
      if (item.id == widget.lessonId) {
        if (mounted) setState(() {
          lesson = item;
          _loadingLesson = false;
        });
        return;
      }
    }

    if (SupabaseService.instance.isInitialized) {
      final result = await SupabaseService.instance.fetchLessonById(widget.lessonId);
      if (!mounted) return;
      setState(() {
        lesson = result.data;
        _loadError = result.isFailure ? result.error : null;
        _loadingLesson = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      lesson = catalog.isNotEmpty ? catalog.first : null;
      _loadError = catalog.isEmpty ? 'Lesson not found' : null;
      _loadingLesson = false;
    });
  }

  Lesson get _lesson {
    final current = lesson;
    if (current == null) {
      throw StateError('Lesson not loaded');
    }
    return current;
  }

  @override
  void dispose() {
    _timer?.cancel();
    NarrationService.instance.stop();
    super.dispose();
  }

  LessonSlide get _slide => _lesson.slides[_slideIndex];

  /// Visual scrubber length, paced to how long the narration actually takes.
  double get _slideDuration =>
      NarrationService.instance.estimateDuration(_slide.narration).inMilliseconds / 1000.0;

  void _togglePlay() {
    if (_playing) {
      _pause();
    } else {
      _play();
    }
  }

  void _play() {
    setState(() => _playing = true);
    if (_position >= _slideDuration) _position = 0;
    NarrationService.instance.speak(
      _slide.narration,
      lang: _slide.speechLang,
      rate: _rate,
      onComplete: () {
        if (!mounted) return;
        _timer?.cancel();
        setState(() {
          _position = _slideDuration;
          _playing = false;
        });
      },
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      setState(() {
        _position += 0.08;
        if (_position >= _slideDuration) {
          _position = _slideDuration;
          t.cancel();
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    NarrationService.instance.stop();
    setState(() => _playing = false);
  }

  void _cycleRate() {
    const rates = [0.6, 0.9, 1.0];
    final next = rates[(rates.indexOf(_rate) + 1) % rates.length];
    setState(() => _rate = next);
    if (_playing) _play();
  }

  void _replay() {
    _timer?.cancel();
    NarrationService.instance.stop();
    setState(() {
      _position = 0;
      _playing = false;
    });
    _play();
  }

  void _goToSlide(int index) {
    _timer?.cancel();
    NarrationService.instance.stop();
    setState(() {
      _slideIndex = index.clamp(0, _lesson.slides.length - 1);
      _position = 0;
      _playing = false;
    });
    _saveSlideProgress();
  }

  void _saveSlideProgress() {
    if (!SupabaseService.instance.isInitialized || SupabaseService.instance.currentUser == null) return;
    final progress = (_slideIndex + 1) / _lesson.slides.length;
    SupabaseService.instance.saveSlideProgress(
      _lesson.id,
      progress.clamp(0, 0.99),
      slideIndex: _slideIndex,
      totalSlides: _lesson.slides.length,
    );
  }

  void _next() {
    if (_slideIndex < _lesson.slides.length - 1) {
      _goToSlide(_slideIndex + 1);
    } else {
      _timer?.cancel();
      NarrationService.instance.stop();
      setState(() {
        _playing = false;
        _phase = _lesson.checkpoints.isEmpty ? _Phase.complete : _Phase.checkpoints;
      });
      if (_lesson.checkpoints.isEmpty) _persistCompletion();
    }
  }

  Future<void> _persistCompletion() async {
    if (_completionSaved) return;
    _completionSaved = true;

    if (!SupabaseService.instance.isInitialized || SupabaseService.instance.currentUser == null) {
      return;
    }

    final service = SupabaseService.instance;
    await service.completeLesson(
      lessonId: _lesson.id,
      xpReward: _lesson.xpReward,
      checkpointsCorrect: _correctCount,
      checkpointsTotal: _lesson.checkpoints.isEmpty ? 0 : _lesson.checkpoints.length,
      estimatedMinutes: _lesson.estimatedTime.inMinutes.clamp(1, 60),
    );

    await ref.read(authControllerProvider).reloadProfile();
    await ref.read(catalogProvider).refreshAfterLessonComplete();
  }

  void _submitAnswer(Checkpoint cp, QuizOption option) {
    if (_answered) return;
    setState(() {
      _selectedOptionId = option.id;
      _answered = true;
      if (option.isCorrect) _correctCount++;
    });
  }

  void _nextCheckpoint() {
    if (_cpIndex < _lesson.checkpoints.length - 1) {
      setState(() {
        _cpIndex++;
        _selectedOptionId = null;
        _answered = false;
      });
    } else {
      setState(() => _phase = _Phase.complete);
      _persistCompletion();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLesson) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (lesson == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadError ?? 'Lesson not found'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AuroraBackground(
            orbColors: [_lesson.color, AppColors.accentTeal, AppColors.accentBlue, _lesson.color],
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: switch (_phase) {
              _Phase.slides => _buildSlides(context),
              _Phase.checkpoints => _buildCheckpoint(context),
              _Phase.complete => _buildComplete(context),
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Slides
  Widget _buildSlides(BuildContext context) {
    final progress = (_slideIndex + (_position / _slideDuration)) / _lesson.slides.length;
    return Column(
      children: [
        _PlayerHeader(
          title: _lesson.title,
          subtitle: 'Slide ${_slideIndex + 1} of ${_lesson.slides.length}',
          progress: progress,
          color: _lesson.color,
          onClose: () => context.go('/student/home'),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: _SlideView(
                key: ValueKey(_slide.id),
                slide: _slide,
                color: _lesson.color,
                showCaption: _showCaption,
              ),
            ),
          ),
        ),
        _AudioBar(
          position: _position,
          duration: _slideDuration,
          playing: _playing,
          aiVoice: _slide.aiVoice,
          showCaption: _showCaption,
          rateLabel: _rate <= 0.6 ? '0.5×' : (_rate >= 1.0 ? '1.5×' : '1×'),
          color: _lesson.color,
          onPlayPause: _togglePlay,
          onReplay: _replay,
          onSpeed: _cycleRate,
          onSeek: (v) => setState(() => _position = v * _slideDuration),
          onToggleCaption: () => setState(() => _showCaption = !_showCaption),
        ),
        _SlideControls(
          canPrev: _slideIndex > 0,
          isLast: _slideIndex == _lesson.slides.length - 1,
          color: _lesson.color,
          onPrev: () => _goToSlide(_slideIndex - 1),
          onNext: _next,
        ),
      ],
    );
  }

  // ----------------------------------------------------------- Checkpoints
  Widget _buildCheckpoint(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cp = _lesson.checkpoints[_cpIndex];
    return Column(
      children: [
        _PlayerHeader(
          title: 'Quick checkpoint',
          subtitle: 'Question ${_cpIndex + 1} of ${_lesson.checkpoints.length}',
          progress: (_cpIndex + (_answered ? 1 : 0)) / _lesson.checkpoints.length,
          color: AppColors.accentTeal,
          onClose: () => context.go('/student/home'),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pill(label: _cpTypeLabel(cp.type), icon: _cpTypeIcon(cp.type), color: AppColors.accentTeal),
                const SizedBox(height: 16),
                Text(cp.prompt, style: text.headlineSmall),
                if (cp.audioPrompt != null) ...[
                  const SizedBox(height: 16),
                  _AudioPromptChip(text: cp.audioPrompt!, lang: cp.audioLang),
                ],
                if (cp.hint != null && !_answered) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(child: Text(cp.hint!, style: text.bodyMedium?.copyWith(color: AppColors.warning))),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                for (final opt in cp.options) ...[
                  _OptionTile(
                    option: opt,
                    selected: _selectedOptionId == opt.id,
                    answered: _answered,
                    onTap: () => _submitAnswer(cp, opt),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        if (_answered) _CheckpointFeedback(
          correct: cp.options.firstWhere((o) => o.id == _selectedOptionId).isCorrect,
          isLast: _cpIndex == _lesson.checkpoints.length - 1,
          onContinue: _nextCheckpoint,
        ),
      ],
    );
  }

  // -------------------------------------------------------------- Complete
  Widget _buildComplete(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = _lesson.checkpoints.length;
    final score = total == 0 ? 1.0 : _correctCount / total;
    return BlobBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: const BoxDecoration(gradient: AppColors.goldGradient, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('🎉', style: TextStyle(fontSize: 64)),
                ),
              ),
              const SizedBox(height: 24),
              Text('Lesson complete!', style: text.displayMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                total == 0
                    ? 'Great listening, ${ref.read(learnerProvider).name}!'
                    : 'You got $_correctCount of $total checkpoints right.',
                style: text.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RewardStat(emoji: '⚡', value: '+${_lesson.xpReward}', label: 'XP earned'),
                    Container(width: 1, height: 40, color: AppColors.line),
                    _RewardStat(emoji: '🎯', value: '${(score * 100).round()}%', label: 'Accuracy'),
                    Container(width: 1, height: 40, color: AppColors.line),
                    _RewardStat(emoji: '🔥', value: '+1', label: 'Streak day'),
                  ],
                ),
              ),
              if (score >= 0.8) ...[
                const SizedBox(height: 16),
                GlassCard(
                  gradient: AppColors.tealGradient,
                  child: Row(
                    children: [
                      const Text('🧠', style: TextStyle(fontSize: 30)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('New badge unlocked: Quiz Whiz!',
                            style: text.titleMedium?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GradientButton(
                label: 'Back to lessons',
                icon: Icons.home_rounded,
                expand: true,
                gradient: AppColors.brandGradient,
                onTap: () => context.go('/student/home'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  _phase = _Phase.slides;
                  _slideIndex = 0;
                  _cpIndex = 0;
                  _correctCount = 0;
                  _answered = false;
                  _selectedOptionId = null;
                  _position = 0;
                }),
                child: const Text('Review lesson again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cpTypeLabel(CheckpointType t) => switch (t) {
        CheckpointType.multipleChoice => 'Multiple choice',
        CheckpointType.matching => 'Matching',
        CheckpointType.pronunciation => 'Listen & tap',
        CheckpointType.typed => 'Type the answer',
      };

  IconData _cpTypeIcon(CheckpointType t) => switch (t) {
        CheckpointType.multipleChoice => Icons.checklist_rounded,
        CheckpointType.matching => Icons.compare_arrows_rounded,
        CheckpointType.pronunciation => Icons.hearing_rounded,
        CheckpointType.typed => Icons.keyboard_rounded,
      };
}

// =============================================================== Sub-widgets

class _PlayerHeader extends StatelessWidget {
  final String title, subtitle;
  final double progress;
  final Color color;
  final VoidCallback onClose;
  const _PlayerHeader({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleLarge?.copyWith(fontSize: 17)),
                    Text(subtitle, style: text.bodyMedium?.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 300),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppColors.line,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final LessonSlide slide;
  final Color color;
  final bool showCaption;
  const _SlideView({super.key, required this.slide, required this.color, required this.showCaption});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Center(
              child: Text(slide.imageEmoji ?? '📘', style: const TextStyle(fontSize: 96)),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(slide.title, style: text.displayMedium?.copyWith(fontSize: 30)),
        const SizedBox(height: 12),
        Text(slide.body, style: text.bodyLarge?.copyWith(fontSize: 17)),
        if (showCaption && slide.caption != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.closed_caption_rounded, size: 18, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('"${slide.caption!}"',
                      style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AudioBar extends StatelessWidget {
  final double position, duration;
  final bool playing, aiVoice, showCaption;
  final String rateLabel;
  final Color color;
  final VoidCallback onPlayPause, onReplay, onToggleCaption, onSpeed;
  final ValueChanged<double> onSeek;
  const _AudioBar({
    required this.position,
    required this.duration,
    required this.playing,
    required this.aiVoice,
    required this.showCaption,
    required this.rateLabel,
    required this.color,
    required this.onPlayPause,
    required this.onReplay,
    required this.onToggleCaption,
    required this.onSpeed,
    required this.onSeek,
  });

  String _fmt(double s) {
    final d = Duration(seconds: s.round());
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(aiVoice ? Icons.auto_awesome_rounded : Icons.mic_rounded, size: 15, color: color),
              const SizedBox(width: 6),
              Text(aiVoice ? 'AI narration' : 'Teacher narration',
                  style: text.bodyMedium?.copyWith(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: onToggleCaption,
                child: Icon(
                  showCaption ? Icons.closed_caption_rounded : Icons.closed_caption_off_rounded,
                  size: 20,
                  color: showCaption ? color : AppColors.muted,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: color,
              inactiveTrackColor: AppColors.line,
              thumbColor: color,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: duration == 0 ? 0 : (position / duration).clamp(0, 1),
              onChanged: onSeek,
            ),
          ),
          Row(
            children: [
              Text(_fmt(position), style: text.bodyMedium?.copyWith(fontSize: 12)),
              const Spacer(),
              IconButton(onPressed: onReplay, icon: const Icon(Icons.replay_rounded)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onSpeed,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: color,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 18),
                    const SizedBox(width: 2),
                    Text(rateLabel, style: text.bodyMedium?.copyWith(fontSize: 12, color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Spacer(),
              Text(_fmt(duration), style: text.bodyMedium?.copyWith(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlideControls extends StatelessWidget {
  final bool canPrev, isLast;
  final Color color;
  final VoidCallback onPrev, onNext;
  const _SlideControls({
    required this.canPrev,
    required this.isLast,
    required this.color,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          if (canPrev)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrev,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Previous'),
              ),
            ),
          if (canPrev) const SizedBox(width: 12),
          Expanded(
            flex: canPrev ? 1 : 2,
            child: GradientButton(
              label: isLast ? 'Start checkpoints' : 'Next slide',
              icon: isLast ? Icons.quiz_rounded : Icons.arrow_forward_rounded,
              expand: true,
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioPromptChip extends StatefulWidget {
  final String text;
  final String lang;
  const _AudioPromptChip({required this.text, required this.lang});

  @override
  State<_AudioPromptChip> createState() => _AudioPromptChipState();
}

class _AudioPromptChipState extends State<_AudioPromptChip> {
  bool _speaking = false;

  Future<void> _play() async {
    setState(() => _speaking = true);
    await NarrationService.instance.speak(
      widget.text,
      lang: widget.lang,
      rate: 0.75,
      onComplete: () {
        if (mounted) setState(() => _speaking = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: _play,
      color: AppColors.accentTeal.withValues(alpha: 0.1),
      shadow: const [],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AnimatedScale(
            scale: _speaking ? 1.12 : 1,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(gradient: AppColors.tealGradient, shape: BoxShape.circle),
              child: Icon(_speaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(_speaking ? 'Playing…' : 'Tap to hear the word',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final QuizOption option;
  final bool selected, answered;
  final VoidCallback onTap;
  const _OptionTile({required this.option, required this.selected, required this.answered, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.line;
    Color bg = AppColors.surface;
    Widget? trailing;
    if (answered) {
      if (option.isCorrect) {
        border = AppColors.success;
        bg = AppColors.successSoft;
        trailing = const Icon(Icons.check_circle_rounded, color: AppColors.success);
      } else if (selected) {
        border = AppColors.danger;
        bg = AppColors.dangerSoft;
        trailing = const Icon(Icons.cancel_rounded, color: AppColors.danger);
      }
    } else if (selected) {
      border = AppColors.primary;
      bg = AppColors.primarySoft;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(option.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _CheckpointFeedback extends StatelessWidget {
  final bool correct, isLast;
  final VoidCallback onContinue;
  const _CheckpointFeedback({required this.correct, required this.isLast, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = correct ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: (correct ? AppColors.successSoft : AppColors.dangerSoft),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(correct ? '🎉' : '💪', style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(correct ? 'Nice work — that’s correct!' : 'Good try — keep practising!',
                    style: text.titleLarge?.copyWith(color: color, fontSize: 17)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: isLast ? 'Finish lesson' : 'Continue',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            gradient: correct ? AppColors.tealGradient : AppColors.sunsetGradient,
            onTap: onContinue,
          ),
        ],
      ),
    );
  }
}

class _RewardStat extends StatelessWidget {
  final String emoji, value, label;
  const _RewardStat({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(value, style: text.titleLarge?.copyWith(fontSize: 18)),
        Text(label, style: text.bodyMedium?.copyWith(fontSize: 11.5)),
      ],
    );
  }
}
