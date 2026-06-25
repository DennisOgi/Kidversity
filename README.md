# Kidversity 🎓

A friendly, browser-first learning platform built with **Flutter**. Students learn
slide-by-slide with synced audio and game-like rewards. Teachers & parents either
**upload** their own PowerPoint/PDF + audio **or** **auto-generate** a full lesson
(slides + audio + quiz) from a single topic prompt.

> You're never locked in — Kidversity adapts to how you teach and learn.

## ✨ What's inside (MVP)

**Student experience**
- Animated home dashboard: level/XP ring, streak, daily goal, "continue learning"
- Explore catalog with search + subject filters
- **Slide + audio player**: play / pause / replay / scrub, captions toggle,
  teacher vs. AI narration, auto-advance, accessibility-friendly
- Interactive checkpoints (multiple-choice, listen-&-tap pronunciation) with
  instant feedback and a celebratory completion screen
- Rewards: badges with unlock progress + opt-in class leaderboard
- Profile: skills mastered, accessibility settings (dyslexia-friendly text, captions)

**Teacher / parent experience**
- Dashboard with class metrics and weekly activity snapshot
- **Create content wizard** with two paths:
  - *Upload your own*: drag-drop zone, per-slide audio (record or AI voice), optional auto-quiz
  - *Auto-generate with AI*: topic prompt + options (slide count, grade level, voice, quiz)
    → animated step-by-step generation → preview → tweak → assign
- Students analytics: per-student mastery rings, strengths, growth areas, leaderboard toggle

## 🏗️ Architecture

```
lib/
  theme/        # AppColors + AppTheme (Material 3, Fredoka + Nunito)
  models/       # Domain models (Lesson, LessonSlide, Checkpoint, RewardBadge, ...)
  data/         # MockData + Riverpod providers (swap for a real backend later)
  router/       # go_router config (StatefulShellRoute per persona)
  widgets/      # Reusable UI (GlassCard, GradientButton, ProgressRing, charts, LessonCard)
  features/
    landing/    # Role selection
    shell/      # Floating pill bottom-nav shell
    student/    # home, explore, lesson_player, rewards, profile
    teacher/    # home, create, students
```

- **State management:** Riverpod
- **Navigation:** go_router (clean web URLs, persona shells)
- **Data layer:** all content flows through `MockData` + providers in `lib/data/`,
  so a real backend (e.g. Supabase) and an LLM generation service can be dropped in
  without touching the UI.

## 🚀 Run it

```bash
flutter pub get
flutter run -d chrome      # web (recommended — it's browser-first)
# also targets android / ios / windows
```

## 🔌 Next steps to make it production-ready
- Replace `MockData` with a backend (auth, lessons, progress) — Supabase recommended
- Wire real audio playback (`just_audio`) + file upload (`file_picker`) for PPT/PDF
- Connect AI auto-generate to an LLM + TTS service behind the `CreateScreen` flow
- Persist XP / streaks / badges and real leaderboard data
