# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.1] - 2026-10-23

### Fixed

- The countdown popover no longer takes the keyboard. Before, keystrokes went to BreakTime Neo and were lost until you clicked back into your app, and that click closed the popover.
- The countdown popover now stays open until the break starts, wherever you click. If you postpone the break or turn BreakTime Neo off during the countdown, a click elsewhere closes it again. The countdown can be turned off in the settings.

## [1.0.0] - 2026-10-23

### Added

- First version of BreakTime Neo, a menu bar break reminder for Apple silicon Macs on macOS 27.
- Stopwatch icon in the menu bar that fills up towards the next break; optional time next to it.
- Popover with the time left, an on/off switch and a non-linear slider to move the next break, down to the second.
- Ten-second countdown that opens the popover without taking keyboard focus.
- Break screen with slight dimming and a Liquid Glass window: elapsed and remaining time, progress bar, “In a Minute” (⎋, ⇧⎋, ⇧⌘⎋) and “Done”.
- Magic reschedule: being away (no input, screen locked, Mac asleep) restarts the countdown; a playing video counts as activity.
- Enforced breaks with an emergency exit (⌃⌥⌘⎋), breaks on all displays or the main display only, sounds, start at login.
- English and German, following the system language.
- Liquid Glass app icon.

[1.0.1]: https://github.com/saschafiedler/breaktime-neo/releases/tag/v1.0.1
[1.0.0]: https://github.com/saschafiedler/breaktime-neo/releases/tag/v1.0.0
