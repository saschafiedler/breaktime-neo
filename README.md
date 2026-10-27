# BreakTime Neo

A break reminder that lives in the macOS menu bar. It counts down to your next break and dims the screen when it's time to look away. It runs on Apple silicon Macs with macOS 27 or later and speaks English and German.

## Why this exists

BreakTime by Excited Pixel did exactly this, and did it well. It hasn't been updated in years, though, and it is an Intel-only app. On Apple silicon it runs through Rosetta, and it will stop working once Rosetta is gone.

BreakTime Neo brings it to current Macs. Where it made sense, it works and looks like the original, but every line is new. No code, icons, graphics or sounds from BreakTime were used, and [docs/CLEAN-ROOM.md](docs/CLEAN-ROOM.md) records where each feature came from.

## What it does

- A stopwatch in the menu bar fills up as your next break gets closer. If you prefer numbers, you can show the time next to it.
- Click the stopwatch to see the minutes left, an on/off switch and a slider. Drag the slider to move your next break, down to the second. All the way to the left starts a break right now.
- Ten seconds before a break, the same panel opens by itself and counts down. It doesn't steal keyboard focus, so you can finish the sentence you're typing.
- During a break the screen dims a little and a small glass window shows how long you've been resting and how long is left. "In a Minute" (⎋) pushes the break back, ⇧⎋ gives you five minutes and ⇧⌘⎋ fifteen. "Done" ends it.
- If you've been away long enough (no input, screen locked, Mac asleep), the countdown starts over when you come back. A playing video counts as activity, so watching a film doesn't reset it.
- You can also enforce breaks (with an emergency exit, ⌃⌥⌘⎋), dim every display or only the main one, turn sounds on or off, and start at login.
- Once a day it asks GitHub whether there is a new version. If there is, a red dot on the gear and a button in the settings point you to the download page; nothing is downloaded or installed by itself. The request carries nothing about you, but like any web request it reaches GitHub with your IP address. You can turn the check off in the settings.

## Requirements

- A Mac with Apple silicon
- macOS 27 or later
- Xcode 27, to build from source

## Install

Download `BreakTime-Neo-<version>.zip` from the [latest release](https://github.com/saschafiedler/breaktime-neo/releases/latest), unzip it and move `BreakTime Neo.app` to the Applications folder. The app is signed with a Developer ID and notarised by Apple, so it opens without warnings. Open the settings with the gear button in the panel if you want it to start at login.

You can also build it yourself:

```bash
git clone https://github.com/saschafiedler/breaktime-neo.git BreakTimeNeo
cd BreakTimeNeo
scripts/install-local.sh
```

The script builds a release version, copies `BreakTime Neo.app` to `/Applications` and starts it.

## Development

Open `BreakTimeNeo.xcodeproj` and run the `BreakTimeNeo` scheme. The break logic sits in the Swift package `BreakTimeNeoCore`. It has no UI and passes time in explicitly, so its tests finish in milliseconds:

```bash
swift test --package-path BreakTimeNeoCore
```

To build the app and run all tests:

```bash
xcodebuild -project BreakTimeNeo.xcodeproj -scheme BreakTimeNeo -destination 'platform=macOS,arch=arm64' test
```

[CONTRIBUTING.md](CONTRIBUTING.md) covers the clean-room rules and how to add a translation. Design decisions are written down in [docs/DECISIONS.md](docs/DECISIONS.md).

## Thanks, BreakTime

The idea and the way BreakTime Neo works come from Excited Pixel's [BreakTime](https://www.breaktimeapp.com). Thank you for a small app that made a lot of working days a bit healthier. BreakTime Neo is a fan's tribute and is not affiliated with or endorsed by Excited Pixel.

## License

MIT. See [LICENSE](LICENSE).
