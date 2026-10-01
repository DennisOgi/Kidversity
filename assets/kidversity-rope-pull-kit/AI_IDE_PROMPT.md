# Give this instruction to your AI IDE

Integrate this Rope Pull visual kit into the existing Kidversity FLUTTER app. Read README, GAME_UI_SPEC, ANIMATION_SPEC and ASSET_MANIFEST first. Audience: pre-teens and teenagers; preserve the restrained contemporary art direction.

Inspect current Flutter SDK, routing, state management, game room and realtime services before editing. Retain architecture and authentication. This is presentation work, not permission to rewrite the backend, reset data or replace established multiplayer rules.

Copy assets/rope_pull to the app assets directory and merge the example pubspec entries. Preserve transparent PNGs. Use the supplied grip anchors. The scene uses four separate character cutouts, one background and procedural rope/effects. Do not bake UI into images or render a screenshot as the game. Do not claim PNG cutout transforms are skeletal animation.

Use flutter/rope_arena.dart as an integration source, adapting only for the installed SDK and project conventions. Bind it to real authoritative position, phase, scores, remaining time, countdown and winner. Trigger cue/effects once for each NEW server event. Reject duplicate/out-of-order sequence numbers in the integration adapter. Never award a pull from a client-side guess before server confirmation.

Use the demo page to understand the visuals, not as production scoring or question logic. The browser/Flutter demo arithmetic is fake local content. Retain real question APIs, validated answers, class roles, rooms, joins, reconnection, host permissions and game termination.

Desktop shared-screen mode may show both answer panels. Individual student phones must show only their authorized team's controls. Teacher spectator view has no student submission controls. Numeric keypad is only for numeric questions; use real MCQ options for A–D questions. Keep text/inputs outside Canvas.

Handle loading, failed image decode, invalid room, room full, waiting, countdown, playing, submitting, feedback, paused, reconnecting, ended and draw states. Honour reduced motion, offscreen/inactive ticker suspension, mute-first sound and keyboard accessibility. Wire onCue to the app's existing sound service; do not add a dependency merely to match the demo.

Compile and test in the actual repo. Run formatter, flutter analyze, relevant widget/game tests and flutter build web. Verify 390px phone, tablet, laptop and classroom display; long prompts, 200% text, keyboard focus and reconnect state restoration. Provide real screenshots, changed files and remaining limitations. Do not call the integration finished because the visual demo works.
