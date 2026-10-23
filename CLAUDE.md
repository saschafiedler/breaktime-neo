# BreakTime Neo — guide for contributors and coding agents

`AGENTS.md` is the canonical file; `CLAUDE.md` is an identical copy for Claude Code. Change both in the same commit.

If a git-ignored `notes/` folder exists, read `notes/README.md` first: it holds the maintainer's private working notes and instructions.

## What this is

A break reminder for the macOS menu bar: Apple silicon, macOS 27 or later, English and German. It re-creates the Intel-only app BreakTime by Excited Pixel from scratch. Behaviour, layout and labels follow the original; code, icons, graphics and sounds are original work.

## Clean-room rules (mandatory)

- Never open, list, extract or inspect anything inside `BreakTime.app` (binary, resources, nibs, strings, images, sounds) — not even briefly with `ls`, `plutil`, `strings`, `otool`, `nm`, `codesign -d`, `mdls` or Quick Look.
- Never run disassemblers or decompilers (Ghidra, Hopper, class-dump and the like) on BreakTime.
- Never copy or trace BreakTime's icons, graphics or sounds, and never copy longer texts (help, website). Motifs such as the stopwatch may be taken up; drawings are always original. Short control labels may be adopted.
- Allowed sources: the public website, observing the running app from the outside, user experience, Apple documentation, open-source projects with compatible licenses (credited).
- Record the source of every new feature in [docs/CLEAN-ROOM.md](docs/CLEAN-ROOM.md). If you come across BreakTime internals anywhere, stop reading, take nothing and tell the maintainer.

## Project layout

```
BreakTimeNeo/              App target (folder synchronised with Xcode: new files join the target)
  App/                     BreakController, AppSettings, AppInfo
  Menu/                    Status item, popover, stopwatch icon, KeyAppearance
  Overlay/                 Break screen: dimming panels and the glass break window
  Settings/                Settings window
  System/                  Idle, sleep and lock detection; system sounds
  Debug/                   Snapshot export, Debug builds only
  AppIcon.icon             Icon Composer app icon
  Localizable.xcstrings    German translations
BreakTimeNeoCore/          Swift package with the break logic and its tests
BreakTimeNeo.xcodeproj     Xcode project, scheme BreakTimeNeo
docs/                      DECISIONS.md, CLEAN-ROOM.md
scripts/install-local.sh   Release build into /Applications
scripts/release.sh         Signed, notarised release on Forgejo and GitHub
```

## Architecture

- `BreakTimeNeoCore` holds all rules and no UI or system services. `BreakEngine` is a state machine (working → warning → break → working, plus away and paused). Time always comes in with the input (`send(_:at:)`), so tests fast-forward instead of waiting. `nextBoundary(after:)` tells the app when the next change is due.
- `BreakController` drives the engine with a one-second heartbeat that lands exactly on every change, feeds it idle time and sleep/lock events, and turns its outputs into the break screen and sounds.
- UI is AppKit-driven with SwiftUI content: `NSStatusItem` with an `NSPopover`, a settings window, and for breaks one dimming panel per display plus an `NSGlassEffectView` panel.
- Rules belong in the core package, not in views or the controller.
- Design decisions with IDs (N1–N7, S1–S25) are in [docs/DECISIONS.md](docs/DECISIONS.md). Add new ones there.

## Conventions

- Swift 6, default actor isolation `MainActor` in the app target; no third-party dependencies.
- Standard macOS 27 look with Liquid Glass: system components instead of custom controls, SF Pro, the system accent colour, no fade animations, compact layouts.
- The popover must never activate the app or take the keyboard from the app the user is typing in.
- Code, comments and documents in English. UI strings are written in English in code; every new string gets its German translation in `Localizable.xcstrings`.

## Build and test

Build and test before calling anything done:

```bash
xcodebuild -project BreakTimeNeo.xcodeproj -scheme BreakTimeNeo -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData test
```

The logic alone, faster: `swift test --package-path BreakTimeNeoCore`.

The scheme runs the package tests through a plain file reference to `BreakTimeNeoCore` in the project; without it `xcodebuild` reports “There are no test bundles available”.

Check the string catalog after a build: every key in the `*.stringsdata` files under `build/DerivedData/Build/Intermediates.noindex/BreakTimeNeo.build/Debug/BreakTimeNeo.build/` must exist in `Localizable.xcstrings`, and nothing stale may remain. Test a language with `-AppleLanguages "(de)"` or `"(en)"`.

Launch arguments (Debug builds):

- `--demo`: fast rhythm (40 s work, 15 s break, away after 30 s), stores nothing. It dims the real screen, so quit it afterwards with `pkill -x "BreakTime Neo"`.
- `--snapshots <folder>`: writes PNGs of the menu bar icon and popover in every state, the break window and the settings, plus `report.txt`, then quits. Needs no screen-recording permission. Glass effects do not render there.

Installing for daily use: `scripts/install-local.sh` (builds a Release and copies it to `/Applications`).

## Releasing

Versions follow Semantic Versioning (`MARKETING_VERSION`); the build number (`CURRENT_PROJECT_VERSION`) goes up by one for every release. Each version has a `CHANGELOG.md` section and an annotated tag `vX.Y.Z`.

Forgejo is the primary repository (`origin`); a push mirror copies every push to GitHub. Never push to GitHub directly. After the tag is pushed to Forgejo:

```bash
scripts/release.sh 1.0.1            # build from the tag, sign with Developer ID, notarise, staple, zip
scripts/release.sh 1.0.1 --publish  # create the release on Forgejo and GitHub with that zip
```

The script needs a "Developer ID Application" certificate, the notarytool keychain profile `notary`, and `tea` (login `forgejo`) and `gh` signed in. The maintainer tries the zip before publishing.

## Do not

Commit, push, publish, sign for distribution or notarise without the maintainer's explicit OK.
