# Contributing

Thanks for your interest in BreakTime Neo. Bug reports, translations and small, focused pull requests are welcome.

## Before you start

BreakTime Neo is a clean-room re-creation. Please read the rules in [AGENTS.md](AGENTS.md#clean-room-rules-mandatory) first. In short: never look inside the original `BreakTime.app`, never copy its icons, graphics, sounds or longer texts, and note where a new feature comes from in [docs/CLEAN-ROOM.md](docs/CLEAN-ROOM.md).

## Building

You need a Mac with Apple silicon, macOS 27 and Xcode 27.

```bash
xcodebuild -project BreakTimeNeo.xcodeproj -scheme BreakTimeNeo -destination 'platform=macOS,arch=arm64' test
```

The break logic lives in the Swift package `BreakTimeNeoCore`. It has no UI, and its tests pass time in explicitly, so they run in milliseconds:

```bash
swift test --package-path BreakTimeNeoCore
```

In Xcode, the Debug launch argument `--demo` gives you a 40-second work interval and 15-second breaks for trying things out.

## Pull requests

- Keep them small and explain the why in the description.
- Put behaviour into `BreakTimeNeoCore` with a test, not into views.
- Use standard macOS controls, no fade animations, and keep the popover from taking keyboard focus.
- Write new UI strings in English and add the German translation to `BreakTimeNeo/Localizable.xcstrings`.
- Record design changes in [docs/DECISIONS.md](docs/DECISIONS.md).

## Translations

To add a language, add it to `Localizable.xcstrings` (Xcode's String Catalog editor works well) and open a pull request.
