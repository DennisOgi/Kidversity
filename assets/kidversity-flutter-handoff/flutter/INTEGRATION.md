# Flutter integration notes

These files contain a theme, canonical mark/wordmark, asset paths, a reusable world entry and width-based layout boundary. They are source starters, not a runnable app. No Flutter SDK exists in the handoff workspace, so compilation must be checked in your repository.

1. Copy/adapt the Dart files into the existing design-system directory, preserving relative imports or updating them.
2. `kidversity_theme.dart` and `kidversity_brand.dart` use the project's `google_fonts` dependency. The other files add no packages. Do not upgrade the SDK or packages just to match a starter.
3. Apply `buildKidversityLightTheme()` through the existing app theme configuration. Preserve any required theme extensions and component styles, migrating their colours deliberately.
4. Copy assets and merge `pubspec-assets.example.yaml`. `KidversityMark` draws the canonical vector directly; it needs no SVG package. PNG marks are also provided. SVGs can use an already-installed renderer if desired.
5. Bind `WorldEntry.onTap` to existing route logic. Pass catalog titles/descriptions, never preview sample data.
6. Parent content width chooses card/row presentation. On 200% text scale, use a vertical card if horizontal content becomes crowded. Do not set a fixed height around text.
7. The responsive helper chooses layout only. Keep session/controller/provider state outside that boundary; do not recreate it on a window resize. Reuse existing navigation state.
8. Starter theme is light-only. Do not ship an untested auto-inverted dark theme.
9. Press/focus/disabled controls inherit Material interaction behaviour. Tune pressed colours and visible focus in the target SDK's state-property APIs, then verify keyboard and screen-reader behaviour.
10. The source PNGs are full resolution. Generate appropriately sized runtime derivatives through your normal asset pipeline; keep originals in design source rather than loading all of them eagerly. No art is required for a learner to complete a task.

Run `dart format` on integrated files, `flutter analyze`, applicable tests and `flutter build web` in the actual repository. Resolve API compatibility against its installed Flutter version. Do not describe this package as compiled or tested application code.
