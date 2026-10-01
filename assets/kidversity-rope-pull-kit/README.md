# Kidversity Rope Pull — Flutter visual game kit

A school quiz tug-of-war arena for pre-teens and teenagers. Two teams advance a shared rope by answering questions correctly. The social-media reference supplied the interaction idea only; this kit uses original artwork, controls and code.

## Start here

1. Open `preview/index.html` in a modern browser. It runs locally with the relative assets—no server or package installation needed. Click Start round, then answer both teams' sample questions. Sound is opt-in. This is a local visual demo, not online multiplayer.
2. Read `GAME_UI_SPEC.md`, `ASSET_MANIFEST.json` and `ANIMATION_SPEC.md`.
3. Give your AI IDE `AI_IDE_PROMPT.md` and the `flutter/` source files.
4. Copy `assets/rope_pull/` into your Flutter project and merge asset declarations. Keep your existing game backend, question sources and room logic.

## Included

- One original empty campus-court environment.
- Four separate team character PNG cutouts: Indigo captain/partner and Teal captain/partner.
- Original SVG team emblems and UI effect source shapes.
- Procedural animated rope with braid, centre ribbon, goal markers and shadows.
- Grip-anchored cutout rocking, correct-answer surge, dust, feedback ring, countdown and victory confetti.
- Five original short WAV effects, plus explicit mute-first integration guidance.
- Local browser demo with working numeric sample questions for two sides.
- Flutter arena/controller and demonstration screen source, with no third-party runtime package dependency.
- State/event contract, responsive UI rules, asset anchor metadata and an AI IDE handoff prompt.

## Important boundaries

The character PNGs are static cutouts. Runtime transforms produce the motion; these are NOT frame-by-frame sprite sheets, Rive rigs or skeletal animations. There are no independently animated arms/faces, separate cheering poses, or 3D models. The rope/effects are genuinely animated in code. This deliberately keeps the first integration light and clear.

The supplied scene renderer does not implement authenticated online rooms, server scoring, class permissions or production question retrieval. The browser demo and Flutter demo contain labelled sample arithmetic only. Connect the renderer to the application's existing authoritative state. The included Flutter source must be compiled and checked against your actual project's Flutter SDK; no Flutter SDK was available when preparing this kit.

No real students, uploaded reference photograph, school branding, social-media UI or copyrighted reference characters are included in the generated game assets.
