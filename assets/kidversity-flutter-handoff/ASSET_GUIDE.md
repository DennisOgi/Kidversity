# Asset guide

## Canonical brand assets

| Path under assets/brand | Purpose |
|---|---|
| mark-indigo.svg / .png | Main doorway mark on white/canvas; SVG is scalable, PNG 256×256 |
| mark-ink.svg / .png | Single dark-colour mark for neutral applications |
| mark-white.svg / .png | Reversed mark; PNG/SVG have transparent surrounding area |
| brand-lockup.svg | Editable mark + live-text wordmark reference; requires Plus Jakarta Sans for exact appearance |
| app-icon.svg | White doorway on indigo square, with safe interior padding |
| app-icon-32.png | Browser favicon source |
| app-icon-192.png | Web app icon source |
| app-icon-512.png | Large web app icon source |

SVG marks contain paths only, with no external references. Use `KidversityBrand` in `flutter/kidversity_brand.dart` for the in-app lockup. It draws the same vector mark and uses the actual font, avoiding SVG text-rendering differences. Wordmark text in the reference SVG is not converted to paths. Font binaries are not included. Do not crop a logo from an AI screenshot.

App icon files are sources, not a complete Android/iOS launcher configuration. Have the IDE integrate them with the existing app/web manifest and launcher pipeline, preserving current platform settings. Verify masked icon display.

## Standalone artwork

All four illustrations are separate PNG assets, 1536×1024, with opaque backgrounds. None contains UI text or buttons; none is an exported app screen. Files are original generated source images; production resizing/compression is an integration step.

| Path under assets/illustrations | Contents | Placement / fit |
|---|---|---|
| hero-open-doors.png | Three architectural open doors | Public landing only, preferably contain; max ~340 logical px high desktop / 180 mobile |
| world-mandarin.png | Speech bubbles, waveform and indigo architecture; no character | Mandarin world entry / optional compact intro; center crop or contain |
| world-exams.png | Answer sheet and pencil in blue architecture | Exam world entry; omit during questions; center crop or contain |
| world-play.png | Opposing team banners and a rope; no character | Play entry/lobby; preserve full composition with contain for square thumbnails |

Use limited image area: desktop world headers 120–140 high; mobile 80–96 thumbnails. Do not make every page illustration-led. Use calm, ordinary Flutter controls around art. Do not draw text over busy images. Keep central information visible when cropping. For compact cards, the starter uses `BoxFit.contain` to retain full art, especially both team banners in Play.

The complete learner experience must function without decorative images. Exclude purely decorative artwork from screen-reader semantics if its meaning is already provided in adjacent text. On loading failure, show a neutral world icon or simply preserve the text/control layout.

## Reference images

`references/exploratory/desktop-home-earlier.png` and `mobile-home-earlier.png` are the previous AI mockups. **They are NOT the final style authority.** They illustrate possible hierarchy only. Do not reproduce large character graphics, oversized headings, gradients, inconsistent logo geometry or all screenshot text. Read the mature audience revision in `REDESIGN_SPEC.md` first. Do not add references/ to the Flutter runtime asset bundle.

## Assets not included

- Original fox mascot: retain the one already in the application; optional within Mandarin only.
- Fonts: configure Plus Jakarta Sans, DM Sans and a verified CJK font through the existing project setup. Preserve applicable font licenses when bundling.
- Lesson audio, learning images, papers and live game sprites: continue using the real content pipeline and assets. Do not substitute generated art for factual lesson content or synchronized game state.

## Import checklist

1. Merge both assets directory declarations into existing pubspec.
2. Reuse centralized constants in `kidversity_assets.dart`.
3. Import/adapt the brand widget; don't introduce an SVG dependency solely for this mark.
4. Keep artwork separate from dynamic labels and user progress.
5. Verify image decoding, case-sensitive paths, cropping and responsive layout in actual Flutter web/mobile builds.
6. Keep raw references/source images outside the deployed bundle where possible; ship only required runtime exports.
