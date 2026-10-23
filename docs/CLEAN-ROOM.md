# Clean-room record

BreakTime Neo re-creates the behaviour of BreakTime by Excited Pixel without using any of its code or assets. This file records where every feature came from, so the independent origin can be shown at any time. It is updated with every new feature.

## Principles

- No code, resources, icons, graphics or sounds of BreakTime were used. The BreakTime application bundle was never opened or analysed, by people or by AI tools.
- Sources for behaviour: the public website [breaktimeapp.com](https://www.breaktimeapp.com), observation of the running app from the outside (including screenshots, which are not part of this repository), the maintainer's experience as a long-time user, and original ideas.
- Layout, interaction flow and the short labels of controls were adopted on purpose; longer texts (help, website) were not. Code, icons, graphics and defaults are original. Only Apple frameworks, SF Symbols and the system sounds that ship with macOS are used.

## History

| Date | Event |
|---|---|
| 2026-10-14 | Decided against decompiling: under EU and German copyright law (§ 69e UrhG, Art. 6 of Directive 2009/24/EC) decompiling is only allowed for interoperability, not to build a similar program. |
| 2026-10 | Asked Excited Pixel whether they would release the source under an open license, and announced an independent re-creation otherwise. The maintainer keeps the sent mail as evidence. |
| 2026-10-21 | No reply. Clean-room work started. |
| 2026-10-22 | Layout, interaction flow and labels adopted from observation of the running app; the app is named BreakTime Neo as a tribute. |

## Features

“Website” means the feature is mentioned on breaktimeapp.com; only the idea was taken.

| ID | Feature | Source | Implementation |
|---|---|---|---|
| F1 | Time until the next break in the menu bar | Website, observation | Icon only, filling up as observed; own stopwatch drawing (`StatusIcon`). Big number of minutes in the popover as observed. |
| F2 | Countdown shortly before a break | Website, observation | As observed: the popover opens ten seconds before and counts down. |
| F3 | Screen dims for a break, on all displays | Website, observation | Layout as observed (slight dimming, small break window with elapsed time, remaining time, progress bar, split “In a Minute” button and “Done”), built as a Liquid Glass panel. Unlike BreakTime, no gradual dimming. |
| F4 | Move the break by dragging | Website, observation | Slider over one interval in the popover, as observed; non-linear and down to the second (own design); the left end starts the break now (own design). |
| F5 | Skip a break or start it now | Own idea | Right-click menu, slider, “Done”. |
| F6 | Turn reminders off quickly | Website, observation | On/off switch in the popover and settings, infinity sign when off, as observed. Timed turning off (1 h, 3 h, until tomorrow) via right-click is an own idea. |
| F7 | Idle detection restarts the countdown | Website, observation | Own implementation: idle time from `CGEventSource`, own threshold, “away” state in `BreakEngine`. |
| F8 | Sleep and screen lock count as a break | Own idea | `NSWorkspace` and screen-lock notifications. |
| F9 | Enforced break with an emergency exit | Website, observation | Options as observed; buttons hidden instead of greyed out; emergency exit ⌃⌥⌘⎋ is an own design. |
| F10 | Settings: interval, break length, sounds, start at login | Website, observation | Layout and labels as observed (sliders with number fields, “Advanced”, quit button); system sounds, `SMAppService`. |
| F11 | Pause automatically during full-screen video or calls | Own idea | Not implemented yet. |
| F12 | Choice of menu bar, Dock or background | Website | Not implemented yet. |
| F13 | A playing video counts as activity | Own idea | Power assertions read through IOKit. |
| F14 | Break on the main display only | Own idea | Setting “All displays”. |
| F15 | Non-linear sliders with seconds | Own idea | Power curve (`PowerScale`). |

## What the website says (read 2026-10-22, in own words)

- BreakTime is controlled through a popup from the menu bar, where the next break can be moved by dragging.
- Countdown in the menu bar, a warning about ten seconds before a break.
- The screen slowly darkens for a break.
- Can be turned off quickly, for example for a film.
- Optional enforced breaks; idle detection reschedules the next break after being away.
- Runs in the Dock, the menu bar or the background.

## Observations of the running app (2026-10-22, version 2.5.2)

- **Menu bar:** an icon only, no number; a segment inside the stopwatch grows as the break approaches. Off: empty and dimmed.
- **Popover:** big number of minutes until the break in a thin accent-coloured font, a short caption, an on/off switch at the top right, a full-width slider (right end = full interval), a gear button for the settings. Off: an infinity sign instead of the number.
- **Countdown:** about ten seconds before a break the popover opens by itself and counts down in seconds; the slider sits near the left end.
- **Settings:** one window without tabs, labels right-aligned on the left; on/off switch at the top right; sliders with number fields and units for the interval and the break length; checkboxes for enforce break, disable the “In a Minute” button (only with enforce), start at login, play sounds; “Advanced” folds out Dock icon, menu bar icon, magic reschedule, auto dismiss, scripts at break start and end, version.
- **Break:** the whole screen, menu bar included, dims slightly; content stays readable. A small dark window in the middle with the app name as title shows elapsed time (accent colour) and remaining time (grey), a progress bar and two equal buttons: a split “In a Minute” button with an arrow (1, 5 or 15 minutes, shortcuts ⎋, ⇧⎋, ⇧⌘⎋) and “Done”.
- **Enforced break:** the buttons are greyed out (BreakTime Neo hides them instead).
- **App icon (seen on the website):** a dark round stopwatch with a light rim, crown and side button, a glowing blue digital time and a blue bar. BreakTime Neo takes up only the motifs (stopwatch, blue, dark ground); both of its icons are original drawings.

## Third-party material

| Source | Use | Terms |
|---|---|---|
| Apple documentation | API usage | Documentation only, no code copied |
| SF Symbols (`gearshape`, `infinity`, `moon.zzz`, `chevron.up`, `chevron.down`) | Symbols in the popover and settings | Apple license, displayed through the system font |
| macOS system sounds (“Blow”, “Glass”) | Break start and end | Played by the system, not shipped with the app |
