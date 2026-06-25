import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/lesson_generator_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

enum _Mode { choose, upload, aiPrompt, generating, preview }

class CreateScreen extends ConsumerStatefulWidget {
  final String? lessonId;

  const CreateScreen({super.key, this.lessonId});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  _Mode _mode = _Mode.choose;
  final _promptController = TextEditingController(text: 'Beginner Mandarin lesson on numbers 1–10, with audio and a 5-question quiz');
  bool _useAiVoice = true;
  bool _includeQuiz = true;
  int _slideCount = 8;
  String _gradeBand = 'Grade 3';

  int _genStep = 0;
  Timer? _genTimer;
  String? _uploadFileName;
  bool _publishing = false;
  GeneratedLesson? _generatedLesson;
  Lesson? _editingLesson;
  bool _loadingEdit = false;
  String? _generationError;

  static const _genSteps = [
    'Understanding your topic…',
    'Drafting 8 clean slides…',
    'Writing native-style narration…',
    'Building a 5-question quiz…',
    'Polishing visuals…',
  ];

  @override
  void initState() {
    super.initState();
    final lessonId = widget.lessonId;
    if (lessonId != null && lessonId.isNotEmpty) {
      _loadLessonForEdit(lessonId);
    }
  }

  Future<void> _loadLessonForEdit(String lessonId) async {
    setState(() => _loadingEdit = true);
    final result = await SupabaseService.instance.fetchLessonById(lessonId);
    if (!mounted) return;
    if (result.isFailure || result.data == null) {
      setState(() => _loadingEdit = false);
      context.showErrorSnackbar(result.error ?? 'Could not load lesson');
      return;
    }
    final lesson = result.data!;
    setState(() {
      _editingLesson = lesson;
      _generatedLesson = GeneratedLesson.fromLesson(lesson);
      _mode = _Mode.preview;
      _loadingEdit = false;
    });
  }

  @override
  void dispose() {
    _genTimer?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  void _startGeneration() async {
    setState(() {
      _mode = _Mode.generating;
      _genStep = 0;
      _generationError = null;
      _generatedLesson = null;
    });

    _genTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (!mounted) return;
      if (_genStep < _genSteps.length - 1) {
        setState(() => _genStep++);
      }
    });

    final result = await LessonGeneratorService.instance.generate(
      prompt: _promptController.text,
      slideCount: _slideCount,
      includeQuiz: _includeQuiz,
      aiVoice: _useAiVoice,
      gradeBand: _gradeBand,
    );

    _genTimer?.cancel();
    if (!mounted) return;

    if (result.isFailure || result.data == null) {
      setState(() {
        _generationError = result.error ?? 'Generation failed';
        _mode = _Mode.aiPrompt;
      });
      return;
    }

    setState(() {
      _generatedLesson = result.data;
      _mode = _Mode.preview;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEdit) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_mode) {
        _Mode.choose => _buildChoose(context),
        _Mode.upload => _buildUpload(context),
        _Mode.aiPrompt => _buildAiPrompt(context),
        _Mode.generating => _buildGenerating(context),
        _Mode.preview => _buildPreview(context),
      },
    );
  }

  Widget _header(BuildContext context, String title, String subtitle, {bool back = false}) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        if (back)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => setState(() => _mode = _Mode.choose),
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(backgroundColor: AppColors.surface),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.headlineSmall),
              Text(subtitle, style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Choose
  Widget _buildChoose(BuildContext context) {
    return ListView(
      key: const ValueKey('choose'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        _header(context, 'Create content', 'Choose how you’d like to build this lesson'),
        const SizedBox(height: 20),
        _MethodCard(
          emoji: '📤',
          title: 'Upload your own',
          subtitle: 'Drag in a PowerPoint or PDF, then add your voice or AI narration per slide.',
          gradient: AppColors.sunsetGradient,
          bullets: const ['Keep your exact curriculum', 'Record or use AI voice', 'Add a quick quiz'],
          onTap: () => setState(() => _mode = _Mode.upload),
        ),
        const SizedBox(height: 16),
        _MethodCard(
          emoji: '✨',
          title: 'Auto-generate with AI',
          subtitle: 'Type a topic and Kidversity builds slides, audio and a quiz in minutes.',
          gradient: AppColors.brandGradient,
          bullets: const ['Lesson draft in ~2 min', 'Native-style narration', 'You review & tweak'],
          onTap: () => setState(() => _mode = _Mode.aiPrompt),
        ),
        const SizedBox(height: 20),
        GlassCard(
          color: AppColors.primarySoft,
          shadow: const [],
          child: Row(
            children: [
              const Text('🔀', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Do both! Upload a base lesson and let AI add practice questions or translations.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, color: AppColors.primaryDark)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Upload
  Widget _buildUpload(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const ValueKey('upload'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        _header(context, 'Upload your lesson', 'PowerPoint or PDF + optional audio', back: true),
        const SizedBox(height: 20),
        _DropZone(
          fileName: _uploadFileName,
          onBrowse: _pickUploadFile,
        ),
        const SizedBox(height: 18),
        Text('Detected slides', style: text.titleLarge),
        const SizedBox(height: 12),
        for (int i = 1; i <= 3; i++) ...[
          _UploadSlideRow(index: i, useAiVoice: _useAiVoice),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        _ToggleRow(
          icon: Icons.record_voice_over_rounded,
          label: 'Use AI voice for all slides',
          value: _useAiVoice,
          onChanged: (v) => setState(() => _useAiVoice = v),
        ),
        _ToggleRow(
          icon: Icons.quiz_rounded,
          label: 'Let AI add a quick quiz',
          value: _includeQuiz,
          onChanged: (v) => setState(() => _includeQuiz = v),
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: _publishing ? 'Publishing…' : 'Publish lesson',
          icon: Icons.check_rounded,
          expand: true,
          gradient: AppColors.sunsetGradient,
          onTap: _publishing ? null : () => _publishUploaded(context),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- AI Prompt
  Widget _buildAiPrompt(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const ValueKey('ai'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        _header(context, 'Auto-generate with AI', 'Describe the lesson you want', back: true),
        const SizedBox(height: 20),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Topic prompt', style: text.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: _promptController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'e.g. Introduction to Fractions for Grade 5'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ['Photosynthesis basics', 'Mandarin family words', 'Telling the time'])
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() => _promptController.text = s),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Options', style: text.titleLarge),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              _StepperRow(
                label: 'Number of slides',
                value: '$_slideCount',
                onMinus: () => setState(() => _slideCount = (_slideCount - 1).clamp(3, 20)),
                onPlus: () => setState(() => _slideCount = (_slideCount + 1).clamp(3, 20)),
              ),
              const Divider(height: 24),
              _PickerRow(
                label: 'Grade level',
                value: _gradeBand,
                options: const ['Grade 1', 'Grade 3', 'Grade 5', 'Grade 8', 'High school'],
                onChanged: (v) => setState(() => _gradeBand = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ToggleRow(
          icon: Icons.record_voice_over_rounded,
          label: 'Generate AI narration',
          value: _useAiVoice,
          onChanged: (v) => setState(() => _useAiVoice = v),
        ),
        _ToggleRow(
          icon: Icons.quiz_rounded,
          label: 'Include auto-graded quiz',
          value: _includeQuiz,
          onChanged: (v) => setState(() => _includeQuiz = v),
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Generate lesson',
          icon: Icons.auto_awesome_rounded,
          expand: true,
          onTap: _startGeneration,
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Generating
  Widget _buildGenerating(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      key: const ValueKey('gen'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingOrb(),
            const SizedBox(height: 28),
            Text('Building your lesson…', style: text.headlineSmall),
            const SizedBox(height: 24),
            for (int i = 0; i < _genSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: i <= _genStep ? AppColors.primary : AppColors.line,
                        shape: BoxShape.circle,
                      ),
                      child: i < _genStep
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : i == _genStep
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_genSteps[i],
                          style: text.bodyLarge?.copyWith(
                              color: i <= _genStep ? AppColors.ink : AppColors.muted,
                              fontWeight: i == _genStep ? FontWeight.w800 : FontWeight.w500)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- Preview
  Widget _buildPreview(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final generated = _generatedLesson;
    final editing = _editingLesson;
    final title = generated?.title ?? 'Generated lesson';
    final slides = generated?.slides ?? _aiPreviewSlides();
    final quizCount = generated?.checkpoints.length ?? _aiPreviewCheckpoints().length;

    return ListView(
      key: ValueKey(editing?.id ?? 'preview'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(gradient: AppColors.tealGradient, shape: BoxShape.circle),
              child: Icon(editing != null ? Icons.edit_rounded : Icons.check_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(editing != null ? 'Edit lesson' : 'Lesson ready!', style: text.headlineSmall),
                  Text(
                    editing != null ? 'Review and assign to your class' : 'Review, tweak, then assign',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GlassCard(
          gradient: AppColors.brandGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge?.copyWith(color: Colors.white, fontSize: 19)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Pill(label: '${slides.length} slides', icon: Icons.slideshow_rounded, color: Colors.white, background: const Color(0x33FFFFFF)),
                  if (_useAiVoice) const Pill(label: 'AI audio', icon: Icons.graphic_eq_rounded, color: Colors.white, background: Color(0x33FFFFFF)),
                  if (_includeQuiz && quizCount > 0) Pill(label: '$quizCount-q quiz', icon: Icons.quiz_rounded, color: Colors.white, background: const Color(0x33FFFFFF)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Generated slides', style: text.titleLarge),
        const SizedBox(height: 12),
        for (final slide in slides.take(6)) ...[
          _PreviewSlideRow(
            title: slide.title,
            subtitle: slide.body,
            emoji: slide.imageEmoji ?? '📘',
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (editing == null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _mode = _Mode.aiPrompt),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Tweak'),
                ),
              ),
            if (editing == null) const SizedBox(width: 12),
            if (editing != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _publishing || editing.id.isEmpty
                      ? null
                      : () => context.go('/student/lesson/${editing.id}'),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('Preview'),
                ),
              ),
            if (editing != null) const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                label: _publishing ? 'Assigning…' : 'Assign to class',
                icon: Icons.send_rounded,
                expand: true,
                onTap: _publishing
                    ? null
                    : () => editing != null
                        ? _assignExistingLesson(context, editing.id)
                        : _publishAiLesson(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _assignExistingLesson(BuildContext context, String lessonId) async {
    setState(() => _publishing = true);
    final result = await SupabaseService.instance.assignLessonToClass(lessonId);
    setState(() => _publishing = false);
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Assign failed');
      return;
    }
    ref.invalidate(teacherLessonsProvider);
    context.showSuccessSnackbar('Assigned to class!');
  }

  Future<void> _pickUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ppt', 'pptx', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() => _uploadFileName = file.name);

    if (SupabaseService.instance.isInitialized &&
        SupabaseService.instance.currentUser != null &&
        file.bytes != null) {
      await SupabaseService.instance.uploadFile(
        'lesson-files',
        file.name,
        file.bytes!,
        mimeType: file.extension == 'pdf' ? 'application/pdf' : null,
      );
    }
  }

  List<LessonSlide> _aiPreviewSlides() {
    const rows = [
      ('s1', '一 — yī', 'A single horizontal stroke.', '1️⃣', 'yī means one.', '一。yī。'),
      ('s2', '二 — èr', 'Two strokes stacked.', '2️⃣', 'èr means two.', '二。èr。'),
      ('s3', '三 — sān', 'Three horizontal strokes.', '3️⃣', 'sān means three.', '三。sān。'),
      ('s4', '四 — sì', 'Four strokes in a box shape.', '4️⃣', 'sì means four.', '四。sì。'),
    ];
    return rows
        .map((r) => LessonSlide(
              id: r.$1,
              title: r.$2,
              body: r.$3,
              imageEmoji: r.$4,
              caption: r.$5,
              speechText: r.$6,
              speechLang: 'zh-CN',
              aiVoice: _useAiVoice,
            ))
        .toList();
  }

  List<Checkpoint> _aiPreviewCheckpoints() {
    if (!_includeQuiz) return const [];
    return const [
      Checkpoint(
        id: 'c1',
        type: CheckpointType.multipleChoice,
        prompt: 'Which character means "three"?',
        options: [
          QuizOption(id: 'o1', label: '一'),
          QuizOption(id: 'o2', label: '三', isCorrect: true),
          QuizOption(id: 'o3', label: '二'),
        ],
      ),
      Checkpoint(
        id: 'c2',
        type: CheckpointType.multipleChoice,
        prompt: 'What does "yī" mean?',
        options: [
          QuizOption(id: 'o1', label: 'One', isCorrect: true),
          QuizOption(id: 'o2', label: 'Two'),
          QuizOption(id: 'o3', label: 'Four'),
        ],
      ),
    ];
  }

  int _gradeBandNumber() {
    final digits = RegExp(r'\d+').firstMatch(_gradeBand);
    return int.tryParse(digits?.group(0) ?? '') ?? 3;
  }

  Future<void> _publishAiLesson(BuildContext context) async {
    final generated = _generatedLesson;
    if (generated != null) {
      await _publishLesson(
        context,
        title: generated.title,
        subject: generated.subject,
        description: generated.description,
        source: ContentSource.aiGenerated,
        slides: generated.slides,
        checkpoints: generated.checkpoints,
        emoji: generated.emoji,
        colorHex: generated.colorHex,
        assignToClass: true,
      );
      return;
    }

    final prompt = _promptController.text.trim();
    final title = prompt.length > 48 ? '${prompt.substring(0, 45)}…' : (prompt.isEmpty ? 'Generated lesson' : prompt);
    await _publishLesson(
      context,
      title: title,
      subject: 'General',
      description: prompt.isEmpty ? 'AI-generated lesson.' : prompt,
      source: ContentSource.aiGenerated,
      slides: _aiPreviewSlides(),
      checkpoints: _aiPreviewCheckpoints(),
      emoji: '✨',
      colorHex: '#6C5CE7',
      assignToClass: true,
    );
  }

  Future<void> _publishUploaded(BuildContext context) async {
    final baseName = _uploadFileName ?? 'Uploaded lesson';
    await _publishLesson(
      context,
      title: baseName.replaceAll(RegExp(r'\.(pptx|ppt|pdf)$', caseSensitive: false), ''),
      subject: 'General',
      description: 'Uploaded from $baseName',
      source: ContentSource.uploaded,
      slides: [
        LessonSlide(
          id: 'u1',
          title: 'Slide 1',
          body: 'Content extracted from your upload will appear here.',
          imageEmoji: '📄',
          caption: 'Welcome to your uploaded lesson.',
          aiVoice: _useAiVoice,
        ),
        LessonSlide(
          id: 'u2',
          title: 'Slide 2',
          body: 'Add narration per slide in the full version.',
          imageEmoji: '🎧',
          caption: 'Listen and follow along.',
          aiVoice: _useAiVoice,
        ),
      ],
      checkpoints: _includeQuiz
          ? const [
              Checkpoint(
                id: 'uc1',
                type: CheckpointType.multipleChoice,
                prompt: 'Ready to check understanding?',
                options: [
                  QuizOption(id: 'o1', label: 'Yes!', isCorrect: true),
                  QuizOption(id: 'o2', label: 'Review slides'),
                ],
              ),
            ]
          : const [],
      emoji: '📤',
      colorHex: '#FF7A59',
      assignToClass: true,
    );
  }

  Future<void> _publishLesson(
    BuildContext context, {
    required String title,
    required String subject,
    required String description,
    required ContentSource source,
    required List<LessonSlide> slides,
    required List<Checkpoint> checkpoints,
    required String emoji,
    required String colorHex,
    bool assignToClass = false,
  }) async {
    if (!SupabaseService.instance.isInitialized) {
      if (context.mounted) {
        context.showErrorSnackbar('Supabase is not configured. Add credentials to .env and restart.');
      }
      return;
    }

    setState(() => _publishing = true);
    final result = await SupabaseService.instance.publishLesson(
      title: title,
      subject: subject,
      description: description,
      source: source,
      slides: slides,
      checkpoints: checkpoints,
      emoji: emoji,
      colorHex: colorHex,
      gradeBandLabel: _gradeBandNumber(),
      estimatedMinutes: (_slideCount * 2).clamp(5, 45),
    );
    setState(() => _publishing = false);

    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Publish failed');
      return;
    }

    if (assignToClass && result.data != null) {
      final assignResult = await SupabaseService.instance.assignLessonToClass(result.data!.id);
      if (context.mounted && assignResult.isFailure) {
        context.showErrorSnackbar(assignResult.error ?? 'Published but class assign failed');
      }
    }

    await ref.read(catalogProvider).refreshAfterLessonComplete();
    if (!context.mounted) return;
    _showPublished(context, lessonTitle: title);
  }

  void _showPublished(BuildContext context, {required String lessonTitle}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚀', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text('Assigned to your class!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('"$lessonTitle" is now live — students can find it in Explore.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Done',
              expand: true,
              onTap: () {
                Navigator.pop(context);
                setState(() => _mode = _Mode.choose);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================== Sub-widgets

class _MethodCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final Gradient gradient;
  final List<String> bullets;
  final VoidCallback onTap;
  const _MethodCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.bullets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      gradient: gradient,
      padding: const EdgeInsets.all(20),
      shadow: [BoxShadow(color: gradient.colors.last.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: text.titleLarge?.copyWith(color: Colors.white, fontSize: 20))),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          Text(subtitle, style: text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.95), fontSize: 14)),
          const SizedBox(height: 14),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 17),
                  const SizedBox(width: 8),
                  Text(b, style: text.bodyMedium?.copyWith(color: Colors.white, fontSize: 13.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final String? fileName;
  final VoidCallback onBrowse;

  const _DropZone({this.fileName, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DottedBorderBox(
      child: Column(
        children: [
          const SoftIcon(icon: Icons.cloud_upload_rounded, color: AppColors.secondary, size: 56),
          const SizedBox(height: 12),
          Text(
            fileName ?? 'Drag & drop your file here',
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            fileName != null ? 'File ready to publish' : 'PowerPoint (.pptx) or PDF • up to 25 MB',
            style: text.bodyMedium?.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Text(fileName != null ? 'Change file' : 'Browse files'),
          ),
        ],
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4), width: 2),
      ),
      child: child,
    );
  }
}

class _UploadSlideRow extends StatelessWidget {
  final int index;
  final bool useAiVoice;
  const _UploadSlideRow({required this.index, required this.useAiVoice});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 56, height: 40,
            decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text('$index', style: text.titleMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Slide $index', style: text.titleMedium?.copyWith(fontSize: 14)),
                Text(useAiVoice ? 'AI voice ready' : 'Tap to record audio',
                    style: text.bodyMedium?.copyWith(fontSize: 12, color: useAiVoice ? AppColors.accentTeal : AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(useAiVoice ? Icons.graphic_eq_rounded : Icons.mic_rounded, color: AppColors.primary),
            style: IconButton.styleFrom(backgroundColor: AppColors.primarySoft),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shadow: const [],
        child: Row(
          children: [
            SoftIcon(icon: icon, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5))),
            Switch(value: value, activeThumbColor: AppColors.primary, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label, value;
  final VoidCallback onMinus, onPlus;
  const _StepperRow({required this.label, required this.value, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15))),
        _RoundIconBtn(icon: Icons.remove_rounded, onTap: onMinus),
        SizedBox(width: 44, child: Text(value, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
        _RoundIconBtn(icon: Icons.add_rounded, onTap: onPlus),
      ],
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final String label, value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _PickerRow({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15))),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      ],
    );
  }
}

class _PreviewSlideRow extends StatelessWidget {
  final String title, subtitle, emoji;
  const _PreviewSlideRow({required this.title, required this.subtitle, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(fontSize: 15)),
                Text('means "$subtitle" • AI narration', style: text.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.graphic_eq_rounded, color: AppColors.accentTeal),
        ],
      ),
    );
  }
}

class _PulsingOrb extends StatefulWidget {
  @override
  State<_PulsingOrb> createState() => _PulsingOrbState();
}

class _PulsingOrbState extends State<_PulsingOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final scale = 1 + _c.value * 0.12;
        return Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.brandGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3 + _c.value * 0.3),
                blurRadius: 30 + _c.value * 20,
                spreadRadius: _c.value * 6,
              ),
            ],
          ),
          child: Transform.scale(
            scale: scale,
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 50),
          ),
        );
      },
    );
  }
}
