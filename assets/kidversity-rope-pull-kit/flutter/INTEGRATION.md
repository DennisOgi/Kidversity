# Flutter integration

1. Copy `assets/rope_pull/` into the project and merge `pubspec-assets.example.yaml`.
2. Copy `rope_arena.dart` into your existing game/presentation directory.
3. For an isolated local demo, copy `rope_pull_demo.dart` alongside it and navigate to `RopePullDemoPage`. `main.example.dart` is optional and must not overwrite your real entry point.
4. The demo uses Dart 3 record syntax. If the project uses an older SDK, replace its sample tuple records with a tiny question class; do not upgrade the whole app blindly. The actual arena renderer does not use records.
5. The only imports are Flutter SDK/dart libraries. No new third-party rendering/audio package is required.
6. Keep one controller per scene, owned by the route/feature and disposed with it. Avoid attaching the same controller to two animated arenas simultaneously: each scene would advance its clock.
7. Pass real server state through `applyState`, with duplicate/out-of-order handling in your service adapter. See STATE_CONTRACT.md.
8. Pass confirmed new answer events through `feedback`. Wire optional onCue to the existing sound service, honoring mute and platform autoplay policy.
9. Provide a production preload barrier and handle error/retry before starting a round. The demo illustrates the renderer but is not your authenticated room orchestration.
10. Use real student/teacher role boundaries. The two input panels are same-device demo controls, not an online authorization pattern.
11. Reduced motion uses MediaQuery.disableAnimations; lifecycle/TickerMode suspend visual ticking. After 2.3 seconds, completed-round effects stop ticking. Verify these paths on your actual target platforms.
12. Run dart format, flutter analyze, relevant tests and flutter build web. No Flutter compilation was possible in this workspace; treat the Dart code as supplied integration source pending project validation.
