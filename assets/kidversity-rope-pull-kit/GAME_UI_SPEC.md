# Rope Pull UI specification

## Direction

A focused school competition in a clean campus sports arena. Contemporary illustrated teenage characters, calm environment, clear team identity and large readable questions. This inherits Kidversity's indigo/ink identity while giving the opposing team teal. Keep the concept understandable at a distance on a classroom display.

Use labels and emblem shapes in addition to colour: Indigo / diamond; Teal / ring. Avoid red-versus-green scoring distinctions, babyish avatars, distracting reward economies or toy-like controls. Illustrations belong to the arena. Answer controls remain ordinary accessible Flutter widgets.

## Composition and responsive modes

Desktop shared-screen/classroom mode: indigo question panel on the left, central arena about 55–65% available width, teal question panel on the right. A compact shared header shows room/class identity, current phase and server time remaining. Each panel has team label, score, readable prompt, its own answer field/selection and Submit. Numeric keypad is appropriate only for a numeric question. For an MCQ render actual A–D options; do not force general exam questions into numeric input.

At widths below 1100, move the arena above both question panels. Below 650, stack question panels. On a student's own phone, production should show only the local team's answer controls below the shared arena, plus the opponent's public score/status. Do not give a student an opponent submission path merely because the demonstration has two input panels. Teacher spectator mode has no student answer controls; authorized host controls remain separate.

The browser demo deliberately shows both panels as a same-device classroom example. In production, bind the mode to actual role/device context. All fields retain focus and state across layout changes. Touch targets >=48 px. Questions >=18 px, controls >=16 px, descriptions >=14 px. Keep question text selectable/readable; no text baked into artwork. Support long questions and 200% text scale by reflowing, never shrinking to fit.

## Arena coordinates

Render in a 1200×600 logical stage with a fixed 2:1 aspect ratio and letterbox/fit inside its widget. Arena scales uniformly; controls do not scale down with it. On very small screens an alternate tighter camera is a future enhancement; do not horizontally stretch sprites. The default scene fits all four players.

Rope centre: (600,340). Main grip anchors at x=255,395,805,945 with the same y=340. Left characters face right. Right characters use a horizontal mirror of their right-facing asset. Each artwork's actual grip point is calibrated in `ASSET_MANIFEST.json`. Drawing uses these anchors rather than guessing margins. Centre flag displacement is `90 * position`, with position in [-1,+1]. Teams/rope translate by the same amount. Visual win thresholds at x=510 and x=690. The server alone decides whether reaching a threshold is victory.

Use the environment as one flattened background plane. The floor shadow, goal markers, players, rope and effects are separate runtime layers. Do not fake multiple parallax planes by moving one flattened image. No cinematic camera shake or unnecessary motion during reading.

Draw order: background → goal/centre floor guides → character shadows → character cutouts → rope + braid + centre ribbon → dust/feedback effects → countdown/result overlay. Rope overlays wrists to visually join the grip. Small surface contact discrepancies may remain with static poses; keep rocking restrained. No character body or face is redrawn in code.

## Game states

Lobby → countdown → playing → finished. Pause/reconnect are explicit presentation states that can interrupt active play. Spectator is an input mode, not a scoring state.

Lobby shows room code, members, teams and readiness from real data. Invalid code/full room/disconnected states need useful messages and retry/back actions. Countdown displays 3/2/1 then Go using server timing. Playing shows questions, score and the rope. A correct answer produces a short visual pull only after the authoritative result arrives. Wrong answer produces inline explanation or retry per current mode; do not invent a penalty. Finished shows the actual winning team or Draw, score and next authorized action. Losing side should not be mocked or depicted being hurt.

The demo uses deterministic local arithmetic, six net pulls to win and a 60-second round. These are DEMO choices, not requirements to change the app's existing game rules. Server position is authoritative even if it does not derive linearly from score.

## Question interactions

Input states: ready, editing, submitting, correct, incorrect, locked, waiting for next question, disconnected. Preserve response until confirmed. Disable only the appropriate team's Submit while in flight; guard duplicate submissions. Never trust browser correctness checks for a real competitive match. Question ID/version and answer token should accompany the existing service request. Do not log private answer keys into student clients beyond what the current content model permits.

When a prompt is replaced, announce the new question without stealing focus unnecessarily. Preserve timer visibility without announcing every tick to a screen reader. Reveal solutions only according to the actual mode. Avoid assigning a timer to untimed content.

## Accessibility and performance

Provide a text equivalent to the scene: team scores, which side leads and round phase. Art is decorative; do not give every sprite an overlapping semantic node. The question controls are outside Canvas and fully keyboard accessible. Use reduced motion to suppress idle rocking, particles and interpolated pulls; keep score changes and results understandable through text. Mute by default, with a persistent opt-in sound control. Never rely on sound for correctness.

Preload/decode artwork once before a match. Show loading/error/retry rather than entering a broken arena. Stop animation when paused, offscreen, application inactive or reduced motion is enabled. Bound particle counts, do not rebuild the whole page on every arena frame, and dispose tickers/decoded images when the renderer owns them. Test on real school laptops/phones; no performance target is claimed without measurement.

## Flutter architecture

Use the included `RopeArenaController` and `RopeArena` as a presentation boundary. They do not import a state manager/router/backend. Keep existing project services and map state into the controller. `RopePullDemoPage` demonstrates layout/input locally; do not put its sample bank or local scoring into production multiplayer.

Asset loading uses rootBundle and dart:ui codecs. Canvas animation is driven by a repaint Listenable. Controls stay Material widgets. This package adds no Flame or Rive dependency. If the current game already uses Flame, adapt the same anchor/effect contract instead of replacing its renderer blindly.

References checked during preparation:
- https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
- https://api.flutter.dev/flutter/dart-ui/instantiateImageCodec.html
- https://api.flutter.dev/flutter/animation/AnimationController-class.html

Validate source with the project's installed SDK. The package was not compiled in Flutter here.
