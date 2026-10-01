# Handoff validation

- All SVGs parsed as XML.
- All PNG headers/dimensions valid.
- Dart asset constants resolve to included files.
- Asset-gallery links resolve locally.
- Four standalone illustrations present.
- Logo PNGs rendered from canonical SVG geometry.
- All generated-art prompts present.

## Contrast on white

- primary: 8.1:1
- ink: 15.65:1
- secondaryText: 6.64:1
- success: 6.01:1
- error: 6.51:1
- warning: 5.98:1
- controlBorder: 4.43:1

These checks validate the package, not the app. Actual layout, focus, states and semantic contrast must be checked in Flutter. No Flutter SDK/repository was available; Dart starters were not compiled.
