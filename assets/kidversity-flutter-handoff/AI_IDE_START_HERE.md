# Start here — paste the following into your AI IDE

You are redesigning my EXISTING Flutter web/mobile application, Kidversity. Read `REDESIGN_SPEC.md` completely, then `ASSET_GUIDE.md`, `tokens.json`, and the supplied Dart starters before changing files.

The audience is school-age PRETEENS AND TEENAGERS, plus teachers/parents. Make the product contemporary, confident and age-respectful. Avoid babyish cartoons, nursery colours, bubble fonts, oversized decorative heroes and mascots in the general shell. The screenshots in `references/exploratory/` are superseded visual explorations, not instructions to reproduce their cartoon styling. The written specification is authoritative.

Work in Flutter and Material 3. Do not create a React site or use screenshots/WebViews as screens. Build actual widgets, responsive navigation, readable forms and real interactive states. Reuse the canonical doorway logo and supplied assets; do not generate random replacement icons or draw the fox into every screen.

First inspect the repository: Flutter/Dart versions, theme, routes, state management, services, auth/roles, API models, assets and tests. Identify the existing files corresponding to each screen in the spec. Briefly report the mapping and implementation sequence, then carry out the redesign. Keep existing architecture unless a concrete issue requires a narrowly justified change.

Preserve authentication, role permissions, reviewer invitation and publishing rules, class membership, existing deep links, backend integrations, lesson/audio/progress/unlock behaviour, exam query IDs and subject dependencies, multiplayer and live quiz state. Do not fabricate data, paper years, scores, lessons, API capabilities or payment options. No database reset, destructive migration or backend rewrite for cosmetic work.

Use `flutter/` files as integration starters, adapting SDK compatibility after inspecting the project. They are not a replacement app. Merge asset declarations into the existing pubspec; never overwrite it. Keep font licences and existing dependencies. Move only runtime assets into the bundle; design references/docs stay outside it.

Implement in phases: shared tokens/logo/shell; landing/auth/home; Mandarin/exams; class/play/reviewer; verification. Don't stop after reskinning the landing page. Make Home truly multi-world and leave Mandarin's lesson path within Mandarin. Use actual persisted activity for Continue; show a new-user state if none exists.

Validate at 320/390/768/1024/1440 logical pixels, keyboard navigation and 200% text scale. Run formatter, analyzer, existing and targeted regression tests, and a web build using the installed project SDK. Show screenshots of actual implemented mobile and desktop views. Report changed files, verification results and unresolved limitations honestly. Do not claim success from the handoff images.
