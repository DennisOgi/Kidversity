# Animation / effects contract

All durations below are visual defaults. They never set server scoring or round timing.

| Event/state | Included visual | Duration / behaviour |
|---|---|---|
| Lobby / idle | Subtle alternating cutout rocking around hand anchor | 2.4s cycle, <=0.6 degree |
| Correct answer | Position eases toward authoritative target; team leans; dust + ring | Position ~420ms, impulse ~650ms |
| Incorrect answer | Team panel text/error, short restrained ring | ~300ms; no rope penalty invented |
| Close to goal | Higher small-amplitude rope tension | Position-based, no camera shake |
| Countdown | Large central 3 / 2 / 1 with dark scrim | Uses countdownSeconds from state |
| Win / draw | Team/result label; winning-side colour confetti for win | Burst decays over 2.2s; no loop |
| Pause / reconnect | Frozen scene with visible overlay | Until new authoritative phase |
| Reduced motion | Static art/rope; immediate positions; text feedback | No rocking or particles |

## Character motion

The included animation is **grip-pivot cutout motion**: translate to the rope grip, mirror if on the right, rotate a few degrees, then draw the asset relative to its calibrated grip point. Hands stay at the rope anchor. The pose is a pulling stance; it does not morph into independent walking, cheering, falling or facial expressions.

Character art remains separate from the rope, background and UI. Root translation follows the score displacement. Shadows stay near the corresponding feet. During a winning state, keep the stable pose and use result UI/confetti; don't bounce a rigid cutout excessively or pretend it is a skeletal rig.

## Rope

Draw a warm neutral rope with dark outer edge and fine repeating diagonal braid ticks. Its slight sag reduces as tension increases. Centre ribbon moves with the rope. Right-facing and mirrored player hands share one horizontal grip line. Do not stretch baked-in rope pixels with sprites. Rope movement is presentation interpolation only.

## Effect layers

Dust: small low-opacity warm particles near shoes, travelling backward from pulling side. Ring: a short expanding translucent circle at the team's front grip after confirmed correct/incorrect feedback. Confetti: bounded deterministic ribbons in winning colour/amber/white, limited to 48 particles. Wrong answers do not trigger camera shake or punitive animation.

The browser preview and Flutter source implement the same visual family; exact raster output is not promised to be identical across renderers. Assets are shared. SVG effect shapes are optional source references; runtime effects use geometry.

## Audio

Original generated WAV signals: correct.wav, incorrect.wav, countdown.wav, start.wav, win.wav. Short nonverbal synthesized sounds; no licensed recordings or background music. Sound off by default. Play only after an explicit user interaction unlocks browser audio. In Flutter, wire the `onCue` callback to the app's existing audio service. No audio package was added; Flutter source itself is silent until that callback is connected.

## Future upgrade path

For more expressive characters, commission/author layered source art and actual Rive/Spine/Flame sprite animations for idle, pull, brace, recover, cheer and lose. Keep the same hand anchor and event contract. This package contains no .riv, .spine, FBX, layered PSD or multi-frame character sheets. Do not ask an IDE to infer missing elbow/hand layers from a flattened PNG and call it a production rig.
