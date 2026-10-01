# Kidversity Flutter redesign handoff

**Latest direction: confident, contemporary learning for pre-teens and teens.**

1. Extract this folder into your repository as `design/kidversity/` (or open it alongside the repo).
2. Give your AI IDE the text in `AI_IDE_START_HERE.md`.
3. Have it read `REDESIGN_SPEC.md` and `ASSET_GUIDE.md` before editing.
4. Copy runtime assets to the corresponding `assets/` paths; merge, do not overwrite, pubspec declarations.

## Contents

- `REDESIGN_SPEC.md`: complete visual, screen, behaviour, responsive and accessibility specification.
- `AI_IDE_START_HERE.md`: implementation instruction for your coding assistant.
- `ASSET_GUIDE.md`: exact file mapping and usage rules.
- `tokens.json`: machine-readable palette, spacing and responsive values.
- `flutter/`: theme, logo, asset constants, world entry and responsive layout starters.
- `assets/brand/`: canonical vector marks/lockup and PNG/favicon exports.
- `assets/illustrations/`: separate reusable raster artwork; not screenshot crops.
- `asset-gallery.html`: local visual inventory; open in a browser.
- `references/exploratory/`: earlier composition concepts, superseded by the mature direction.
- `GENERATION_NOTES.md`: provenance and generation prompts.
- `manifest.json`: inventory with sizes and SHA-256 checksums.

No font files or existing fox asset are included. Fonts must use the project's font setup; the original fox must be preserved from the repository. No project source was supplied, so the Dart starters require integration and compile verification in your actual project. This is not a deployed or pre-integrated app.
