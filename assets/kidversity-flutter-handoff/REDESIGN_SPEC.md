# Kidversity — Flutter redesign specification

Version 1.0 • 23 September 2026 • Implementation handoff

**Concept: one confident learning home, with open doors into different learning worlds.**

## 1. Authority and audience

This document is the source of truth for the redesign. The product is built with Flutter, primarily for web with mobile capability. Do not rebuild it in React, HTML, or a WebView.

The audience is school-age pre-teens and teenagers, plus teachers and parents. The interface must feel capable, contemporary, and welcoming—not infantile. Younger learners should find it understandable; older learners should not feel embarrassed using it for exams. The name Kidversity does not justify nursery graphics.

**Latest direction overrides earlier previews:** reduce large decorative headers, cartoon characters, exuberant colours, bubble type, and repetitive illustration. The older screenshots in `references/exploratory/` are composition references only. They are NOT pixel-perfect targets. In any conflict, use this specification, `tokens.json`, the included native widget source, and the current application's real behaviour.

This package was produced without the source repository. Dart files are integration starters, not a verified drop-in application. Inspect the installed Flutter SDK and project architecture before merging. There is no authorization to remove features or fabricate data to match a preview.

## 2. Product scope to preserve

Kidversity is not a Mandarin-only brand. Existing worlds: Mandarin Foundation; Nigerian past questions; Rope Pull; live class quizzes; class progress. Support future subjects through data-driven world entries.

Preserve auth, existing route/deep-link contracts, backend services, subscriptions/entitlements, lesson unlocking, progress persistence, audio, content review, class membership and multiplayer state. Keep existing state management and routing libraries unless a demonstrated technical issue requires a change. Do not change database schemas merely to restyle screens.

Roles: Student; Teacher/Parent; Reviewer by invitation only. Reviewer is not a public signup option. If the current system combines teacher and parent, preserve its permissions; do not invent a new parent access model or expose a class roster to a parent without authorization.

Do not add an unrestricted AI chatbot or free dictionary. Do not insert streaks, coins, loot, badges or leaderboards that obscure the learning task. This redesign does not introduce new payment products.

## 3. Brand system

### Logo

The primary mark is a simple open arch with an asymmetrical negative-space doorway. Use the canonical SVG or native `KidversityMark` geometry. It is an abstract learning doorway, not a Chinese character and not an illustrated fox. No gradients, KV badge, bevel, glow, enclosing circle, or arbitrary shadow.

Pair with lowercase `kidversity` in Plus Jakarta Sans ExtraBold, midnight ink. Use mark height 32 logical pixels, wordmark 24, gap 10 for ordinary headers. Compact: mark 24, wordmark 20, gap 8. Large marketing: mark 48, wordmark 32, gap 14. Clear space: at least one quarter of the mark height. Minimum standalone mark: 20 logical pixels. Favicon exports use simplified canonical mark on a plain canvas. Never stretch the mark.

Use indigo mark on light surfaces; white mark on indigo or dark ink. `brand-lockup.svg` is a browser/design reference with live font text; use the native Flutter brand widget in-app so font loading is controlled. The mark SVGs themselves are font-independent.

### Tone

Use direct, respectful language: “Continue lesson”, “Review missed questions”, “Join a class”, “Ready for your next session?” Avoid “Hey superstar!”, “You're a little genius!”, baby talk, unnecessary exclamation marks and competitive shaming. Celebrations should acknowledge learning: “Lesson complete. You're ready for the next step.”

Keep the existing tagline: “Many paths. One curious home.” Marketing headline: “Build skills. Open possibilities.” Authenticated home headline: “Your next step starts here.” These supersede the larger child-oriented exploratory headlines.

### Mascot

Preserve the existing fox asset in the repository. It may appear sparingly within optional Mandarin onboarding or a module completion moment. Do not use it in the logo, general shell, exam arena or teacher reports. Do not replace it with new generic character art.

## 4. Colour and visual hierarchy

| Semantic token | Value | Use |
|---|---|---|
| brand.primary | #4433CC | Primary actions, active states, logo |
| brand.primaryPressed | #3526A6 | Pressed primary control |
| brand.primaryTint | #EEEBFF | Selected backgrounds |
| text.primary | #20213B | Headings and reading text |
| text.secondary | #595B72 | Readable supporting text |
| surface.canvas | #F5F6FB | Page background |
| surface.base | #FFFFFF | Work surfaces |
| border.default | #DADDEA | Nonessential separators |
| border.control | #73778B | Visible field/option boundaries |
| accent.spark | #F5C56A | Small highlights, use ink text |
| world.language | #6751B5 | Mandarin identity details |
| world.exams | #2456A6 | Exam identity details |
| world.play | #916015 | Play identity details |
| status.success | #16714A | Correct state plus check/text |
| status.error | #B42332 | Incorrect/error plus text |
| status.warning | #865B00 | Warnings on pale amber |

This is a light-theme release specification. Do not auto-invert images to make a dark mode. Preserve an existing dark mode if required by the project, but implement and verify a dedicated accessible token set before claiming visual parity.

Neutral surfaces should dominate roughly 80% of the app. Brand colour owns actionable emphasis. World colours distinguish content categories, not competing primary buttons. No aurora, glass surfaces or full-page gradients. Images may contain illustrated shading, but UI surfaces and controls use solid fills. Shadows are optional and subtle, reserved for genuine overlay/elevation.

## 5. Type, spacing and controls

Headings/wordmark: Plus Jakarta Sans. Body, question text, labels and data: DM Sans. Use the project's Google Fonts integration or bundle legally obtained font files and licenses for reliable production loading. Font binaries are NOT included. CJK needs a verified font with Chinese glyph coverage, such as Noto Sans SC; keep tone marks in pinyin intact. Do not render Hanzi in a Latin decorative font.

| Style | Desktop / compact | Weight | Line height |
|---|---|---|---|
| Landing headline | 48 / 34 | 700 | 1.12 |
| Page heading | 32 / 26 | 700 | 1.2 |
| Section heading | 22 / 20 | 700 | 1.3 |
| Item title | 18 / 18 | 600 | 1.35 |
| Body/question | 16–18 / 16–18 | 400–500 | 1.5–1.6 |
| Label/button | 14–16 / 14–16 | 600 | 1.35 |
| Secondary metadata | 13 / 13 | 400–500 | 1.45 |

Do not disable system text scaling. Never shrink exam questions to make them fit a fixed-height box. Avoid all-caps for paragraphs; compact short category labels are acceptable.

Spacing scale: 4, 8, 12, 16, 24, 32, 48, 64. Control radius 8; standard surface radius 12; prominent marketing panel radius 16. Large arches belong to logo/art, not every field. Buttons at least 48 high; touch targets at least 48×48. Controls have visible focus and press states. Secondary actions are outlined/text, not another bright primary colour.

## 6. Responsive layout contract

Use available logical width, not device names or user-agent detection. `LayoutBuilder` should drive local layout. Breakpoints are starting points; child constraints and text scaling can force an earlier stack.

| Available app width | Navigation | Content |
|---|---|---|
| <600 | Bottom NavigationBar; public compact header | One column; 16–20 outer padding |
| 600–1023 | Compact NavigationRail where shell fits | 24 padding; one/two columns by content width |
| >=1024 | Extended NavigationRail ~220 wide | 32 padding; up to 1200 main content width |

World cards: use three columns only if each can be >=250 wide; otherwise two; below 600 use horizontal rows with 80–96px artwork. At large text scale, rows become vertical if required. Do not use fixed heights around text.

Reading and question content: max 720. Auth form: max 440. Exam setup: overall max 1000; options column about 600 and summary about 300, then stack. Teacher roster can use wider space with semantic headers. Mobile tables become labelled learner rows, not a miniature desktop table.

Deep task flows (lesson, exam session, live quiz) use a minimal focused shell with Back/Save & exit as appropriate. Do not retain distracting full-world navigation over an active timed task. Preserve browser Back and meaningful deep links.

## 7. Information architecture

Student: Home / Practice / Play / Me. Rename the visible Path destination to Home; preserve old route aliases if external deep links rely on them. Mandarin path moves within its world. Practice includes past questions first, Mandarin review second, and a secondary Rope Pull shortcut. Play opens Rope Pull create/join. Me preserves profile, class joining, board and settings.

Teacher: Class / Progress / Live. Reviewer: separate protected Review queue. Public: splash, landing, auth, onboarding, privacy, terms, guardian consent. Preserve existing consent requirements and do not invent legal text or minimum-age rules.

World catalog entries should map stable IDs to title, description, artwork, destination, availability and role eligibility. Use existing models where possible. A future world appears from configuration without duplicating shell code. Do not expose empty “coming soon” cards just to fill a grid.

## 8. Screen specifications

### Landing

Header: logo left; Explore, For schools, Sign in right; compact public menu on phone. Main headline “Build skills. Open possibilities.” Supporting copy: “Learn Mandarin, practise for Nigerian exams, and challenge your class—one connected learning home.” Primary Create account; secondary Explore learning worlds. Sign in remains available.

Desktop split about 55/45, with `hero-open-doors.png` on the right, no text baked into art. Hero art max height 340, never a full-screen animated scene. Mobile headline/actions first; illustration optional below and capped around 180 high. Follow with one functional world directory, then concrete product explanations (lesson sequence, worked solutions, teacher visibility). Never repeat the same decorative cards under a second heading. Trust claims must reflect actual content review and available papers.

### Splash and authentication

Splash: small centered mark and neutral loading indicator while existing auth boots. No fake delay. Provide a recoverable error if initialization fails.

Auth: calm opaque form, persistent visible labels, password visibility control, errors adjacent to fields, loading state and prevention of duplicate submissions. Desktop may pair a compact brand panel with form. On phone show form promptly. Keep current validation/reset/account flows. Do not replace with a screenshot or local-only simulation.

### Onboarding

Keep name, companion choice, role and relevant consent. Make companion selection modest and skippable only if current requirements allow it. Do not force exam-focused users through Mandarin tutorials; show those on first Mandarin entry. Reviewer access remains invitation-gated. Preserve user's state when going back.

### Student home

Top: greeting/page title and account access. No giant heading illustration. Main resume surface identifies the actual last learning activity, next task and one Continue action. If new, show “Choose where to start” and the world directory; do not invent progress. If user studied exams last, resume exam activity only if a valid persisted session exists; otherwise show its setup shortcut.

Below: available learning worlds, with understated artwork and exact destination. Desktop cards have artwork no taller than 120–140; mobile compact rows use 80–96 square crops. Follow with class section. If a class has a real live quiz, prioritize Join live quiz above the worlds; otherwise show Join a class or current class access. No fictional sample names/counts in production.

### Mandarin path

Show module title, completed lessons, current next lesson and locked lessons with reasons. Course path can have restrained vertical connectors; no giant winding game board that hides content. Render ~30 lessons efficiently, preserving backend ordering and unlock rules. Next lesson must be reachable without scrolling through all completed material. Labels alongside completion icons. Resume stage from persisted state.

### Lesson moment

Compact header with lesson title, close/save action and Look / Listen / Meaning / Practice / Quest progress. Central content changes by stage. Character 64–88 depending on width, pinyin 22–26, English 18, large accessible audio action. For a recall question do not reveal the answer beforehand. Never synthesize replacement learning content to fit a design.

Audio: idle, loading, playing, replay and unavailable states. Feedback: concise reason, retry or continue. Preserve attempt submission and unlock timing. Existing fox may make a small instructional appearance, not occupy half the screen. Save/exit must honour current server/local persistence guarantees.

### Exam setup

Title “Exam practice”; optional category label “Exam arena”. Use concise searchable/accessible selection controls, not dozens of full-width chip rows. Required: exam, subject. Optional: year. Screening institution selector appears only when applicable. Session lengths: 10 / 20 / 40, with explicit selected state. Desktop summary shows chosen exam, subject, year, institution if needed, question count and Start practice. Phone stacks summary last.

Exam choices originate from API: UTME, WASSCE, NECO, Post-UTME, variants and University. Human-readable display labels may be formatted; raw IDs/slugs stay intact in data. Never submit display names instead of API IDs. On exam change, clear an incompatible subject/institution/year, reload dependent options, and discard stale responses. University and Post-UTME must use their screening subject sets, not the full secondary-school list. Institution variants need correct display names from API or a verified mapping; do not guess an expansion from a slug.

English and Mathematics are currently restricted by the free content API plan. Show lock and readable explanation. A provider restriction is NOT automatically an end-user subscription entitlement. Say “Unavailable on the current content plan” unless a real purchase/upgrade flow exists. No dummy Upgrade button. Handle loading, empty subject/year lists, API errors and no matching paper; preserve selections where valid on retry.

### Exam question and results

Question counter and subdued progress; timer only if that real mode is timed. Keep readable question body, images/formulas as supplied, four A–D answer rows and Check answer. Selection is different from submission. After submission show Correct/Incorrect text and icon plus explanation; never depend on red/green alone. Keep actual scoring behaviour and answer-reveal rules.

Report question opens the existing report flow with its original ID. Exit uses the real save/discard contract. Results show actual score/denominator, missed answers, correct answers and worked solutions. Do not invent a percentile or mastery rating. Untimed practice should feel focused; live quizzes may be more energetic without obscuring reading.

### Rope Pull

Lobby: Create room, Join room with four-letter code, participants, team assignment and ready/start state. Preserve server-authoritative joining and host permissions. Arena: opposing teams, central rope and clear question input; game state must be live, not a looping decoration. Maintain readable team labels/icons; colours alone are insufficient.

Use `world-play.png` for entry/lobby illustration only. The actual game must be built from its existing interactive renderer. No image asset substitutes for synchronization, answer submission or rope movement. Represent disconnect/reconnect, invalid code, room full, countdown, finished round and rematch using existing service behaviour. Keep character styling age-appropriate; no nursery proportions or excessive emotes.

### Teacher / parent

Class home: class selector/name, class code, setup live quiz and learner activity. Desktop roster columns: learner, latest activity, learning status, contextual action. Mobile learner rows retain labels and details. Use actual timestamps and learning events; no invented engagement score. “Check in” should be factual, not a public judgement of a child.

Progress uses actual completed lessons, attempts and recent activity from available data. Live includes setup, waiting lobby, start controls, running monitor and results. Clearly distinguish “waiting for learners” from “connection lost”. Parent view respects existing permissions and data scope. Do not expose students outside the user's authorized classes.

### Reviewer

Protected review queue: status filter, lesson title/version, review action. Review detail retains source content, audio, approval/rejection/comment flow and publishing rules. Neutral dense layout; no mascot. Loading/empty/error/permission denied states. Do not let a visual redesign bypass review authorization or publish unapproved content.

## 9. Asset rules

Use included `assets/brand/` and `assets/illustrations/` as reusable content assets. Build all text, controls, nav, progress and layouts using Flutter widgets. Never display an entire screenshot as an app screen. Do not crop the logo from a generated mockup.

New world art is decorative, not authoritative learning content. Keep it out of active question/lesson reading areas. Primary UI remains useful if all art fails to load. Hero belongs mainly on public landing. Keep assets at natural aspect ratio or carefully tested center crop; do not distort. Original PNGs are included as source assets. Optimize export sizes in the project as part of implementation, retaining originals outside the runtime bundle.

Use the supplied font-independent brand mark or the native CustomPainter. Icons should come from the existing consistent Material/icon system, not emoji. Asset paths are centralized in the Dart starter and manifest. Keep asset-directory casing exactly consistent on web builds.

## 10. Flutter implementation guidance

1. Inventory actual routes, state providers, theme files, assets and API models. Report the mapping before edits, then proceed.
2. Introduce semantic tokens, typography and shared components. Rename outdated palette identifiers to semantic names through a controlled migration; avoid indefinite aliases that leave mixed visual systems.
3. Adopt a shared responsive shell. Layout changes must not recreate controllers, restart sessions or lose navigation selection. Keep state outside width-dependent branches where needed.
4. Replace presentation while retaining existing service calls and route parameters. Use immutable view models/adapters if presentation data needs formatting.
5. Scope styles with ThemeData and component themes. Avoid arbitrary one-off colour/radius constants. A Material 3 default theme alone is not the specified design.
6. Keep layout scrollable. Avoid Expanded in an unbounded vertical scroll context. Use slivers/builders for long lesson/roster lists, and constrain reading columns.
7. Bundle artwork once; no network-image dependence for this brand set. Do not eagerly decode all full-resolution images. Include semantic labels only when they communicate information not already labelled; otherwise exclude decorative art from semantics.
8. Starter code deliberately does not choose a state manager, router, backend or package version. Match the installed project SDK/dependencies. If google_fonts is already present, reuse it; if not, decide between the existing font pipeline and a compatible package, documenting the choice.

Suggested reusable components: BrandLockup, ResponsiveShell, WorldEntry, ResumeActivityPanel, LessonStageHeader, AudioControl, ExamSetupSummary, AnswerOption, AnswerFeedback, ClassLearnerRow, AsyncContentState. Names may follow existing conventions. Reuse behaviour instead of duplicating mobile and desktop business logic.

## 11. Accessibility and states

Check normal text contrast >=4.5:1 and large text >=3:1 against actual surfaces; essential control indicators >=3:1. Pale separators are decorative, not the only input boundary. Keep visible keyboard focus. Support Tab, Enter, Space, screen-reader names and selected states. Use native buttons/selection semantics. No essential hover-only action.

Verify 200% text scaling, 320 logical-pixel width, browser zoom, keyboard navigation and safe area padding. Do not cut off options or bottom navigation labels. Reduce motion according to platform preferences; avoid looping backgrounds. Progress announcements should be meaningful and not fire on every animation frame.

Each data-backed screen needs loading, success, empty, recoverable error and permission states where applicable. Disabled states explain why. Submit buttons prevent duplicate requests but do not silently lose input. Render real service failures; never present fake success for a disconnected integration.

## 12. Delivery phases and acceptance

Phase A: audit + theme + logo + asset integration + responsive shell.
Phase B: landing/auth/onboarding + real multi-world home.
Phase C: Mandarin path/lesson + exam setup/session/results.
Phase D: Rope Pull + teacher/class/live + reviewer consistency.
Phase E: regression, responsive and accessibility verification.

Check all of the following before calling the implementation done:

- [ ] Flutter app remains Flutter; existing routing/state/services preserved.
- [ ] Pre-teen/teen tone throughout; no cartoon-heavy general shell.
- [ ] One canonical logo and semantic palette; no remaining KV placeholder.
- [ ] Home represents every available world, with real resume/new-user states.
- [ ] Course progression, review gating, audio and save/exit still work.
- [ ] Changing exam/institution updates valid subject sets and query IDs.
- [ ] Restricted subjects have truthful availability messaging.
- [ ] 10/20/40 question selection, scoring, report and missed-review flows work.
- [ ] Rope Pull create/join, live state, reconnect and host permissions work.
- [ ] Teacher/parent/reviewer permissions and data isolation remain intact.
- [ ] 320, 390, 768, 1024 and 1440 widths; 200% text; keyboard checked.
- [ ] Existing tests run; add focused regression checks only for changed behaviour.
- [ ] Run formatter, flutter analyze, relevant tests and Flutter web build in the actual repository.
- [ ] Supply real desktop/mobile screenshots of implemented screens, changed files and known limitations.

## 13. Evidence and boundaries

The visual direction and dimensions here are design decisions, not claims of framework defaults. Flutter references checked for the handoff:
- https://docs.flutter.dev/ui/adaptive-responsive/general — using constraints and adaptive navigation.
- https://docs.flutter.dev/ui/adaptive-responsive/best-practices — reusable layouts and state continuity.
- https://docs.flutter.dev/ui/assets/assets-and-images — asset declarations and loading.

No Flutter SDK or application repository was supplied in this workspace. Starter Dart code is not compiled here. No backend changes, deployment, real user tests or application regression tests have been performed. The package is a design/implementation handoff, not an already-applied redesign.
