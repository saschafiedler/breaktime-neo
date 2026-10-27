import BreakTimeNeoCore
import ServiceManagement
import SwiftUI

/// Settings in BreakTime's layout and wording: labels right-aligned on the
/// left, controls on the right, the rarely needed options folded away under
/// "Advanced". Built from standard controls only.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    let controller: BreakController
    let updates: UpdateChecker
    @State var showsAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The system switch has no ON/OFF lettering, so the text next to
            // it says the state instead.
            HStack {
                Spacer()
                Text(controller.isEnabled ? "\(AppInfo.name) is on" : "\(AppInfo.name) is off")
                Toggle(isOn: Binding(
                    get: { controller.isEnabled },
                    set: { controller.setEnabled($0) }
                )) {
                    Text(verbatim: AppInfo.name)
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }

            // One grid for all rows, so every label ends on the same line.
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
                GridRow {
                    label("Time between breaks:")
                    DurationControl(
                        value: $settings.workInterval,
                        scale: PowerScale(lower: 60, upper: 7200, exponent: 2),
                        snap: TimeSnap.minutes,
                        fieldRange: 60...14400,
                        alwaysMinutes: true
                    )
                }
                GridRow {
                    label("Length of break:")
                    DurationControl(
                        value: $settings.breakDuration,
                        scale: PowerScale(lower: 5, upper: 1800, exponent: 3),
                        snap: TimeSnap.breakLength,
                        fieldRange: 5...3600,
                        alwaysMinutes: false
                    )
                }
                GridRow {
                    label("Enforce break:")
                    Toggle(isOn: $settings.enforcesBreak) {
                        Text("Prevents switching apps and clicking the done button early")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    label("Disable In a Minute:")
                    Toggle(isOn: $settings.forbidsPostponeWhenEnforced) {
                        Text("Hides the “In a Minute” button")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(!settings.enforcesBreak)
                }
                GridRow {
                    label("Start at login:")
                    LaunchAtLoginToggle()
                }
                GridRow {
                    label("Play sounds:")
                    Toggle("Play sounds:", isOn: $settings.playSounds)
                        .labelsHidden()
                }
                GridRow {
                    label("Updates:")
                        .gridCellAnchor(.topTrailing)
                    UpdateControl(settings: settings, updates: updates)
                }

                GridRow {
                    HStack {
                        Button {
                            showsAdvanced.toggle()
                        } label: {
                            Label("Advanced", systemImage: showsAdvanced ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        Spacer()
                        Button("Quit \(AppInfo.name)") {
                            NSApp.terminate(nil)
                        }
                    }
                    .gridCellColumns(2)
                }

                if showsAdvanced {
                    GridRow {
                        Divider()
                            .gridCellColumns(2)
                    }
                    GridRow {
                        label("Magic reschedule:")
                            .gridCellAnchor(.topTrailing)
                        VStack(alignment: .leading, spacing: 5) {
                            Toggle(isOn: $settings.detectsIdle) {
                                Text("Reschedules break when no activity is detected")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Picker("Magic reschedule:", selection: $settings.awayThreshold) {
                                ForEach([60, 120, 180, 300, 600, 900], id: \.self) { seconds in
                                    Text("after \(seconds / 60) minutes without activity").tag(seconds)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                            .disabled(!settings.detectsIdle)
                            Toggle(isOn: $settings.videoCountsAsPresence) {
                                Text("A playing video counts as activity")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(!settings.detectsIdle)
                        }
                    }
                    GridRow {
                        label("Countdown:")
                        Toggle(isOn: $settings.warningEnabled) {
                            Text("Opens the menu 10 seconds before a break")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    GridRow {
                        label("All displays:")
                        Toggle(isOn: $settings.dimsAllDisplays) {
                            Text("Shows breaks on every display")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    GridRow {
                        label("Time in menu bar:")
                        Toggle(isOn: $settings.showsTimeInMenuBar) {
                            Text("Shows the time left next to the icon")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    GridRow {
                        HStack(spacing: 6) {
                            Spacer()
                            Text("In memory of [BreakTime](https://www.breaktimeapp.com) ❤️")
                            Text(verbatim: "·")
                            Text("Version: \(AppInfo.version)")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .gridCellColumns(2)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 560)
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .gridColumnAlignment(.trailing)
    }
}

/// Slider plus number field plus unit, both editing the same value in
/// seconds. The slider is not linear: short times get more room. Durations
/// below a minute read in seconds, from one minute on in minutes.
private struct DurationControl: View {
    @Binding var value: Int
    /// Slider range and curve, in seconds.
    let scale: PowerScale
    /// Rounds a slider value (seconds) to a sensible step.
    let snap: (Double) -> Int
    /// Allowed range in seconds.
    let fieldRange: ClosedRange<Int>
    /// The work interval always reads in minutes.
    let alwaysMinutes: Bool

    private var shown: (value: Int, inMinutes: Bool) {
        alwaysMinutes ? (value / 60, true) : DurationDisplay.parts(value)
    }

    var body: some View {
        HStack(spacing: 10) {
            Slider(
                value: Binding(
                    get: { scale.position(of: Double(value)) },
                    set: { value = snap(scale.value(at: $0)) }
                ),
                in: 0...1
            )
            .frame(minWidth: 180)
            TextField(
                value: Binding(
                    get: { shown.value },
                    set: { typed in
                        let seconds = DurationDisplay.seconds(fromField: typed, inMinutes: shown.inMinutes)
                        value = snap(Double(min(max(seconds, fieldRange.lowerBound), fieldRange.upperBound)))
                    }
                ),
                format: .number
            ) {
                EmptyView()
            }
            .multilineTextAlignment(.trailing)
            .frame(width: 56)
            // Fixed width, so both sliders end at the same place.
            Text(shown.inMinutes ? "Minutes" : "Seconds")
                .frame(width: 72, alignment: .leading)
        }
    }
}

/// Automatic checks for a new version, a button to check now and its
/// result. A new version shows as a button that opens its download page in
/// the browser (see S26 in docs/DECISIONS.md).
private struct UpdateControl: View {
    @Bindable var settings: AppSettings
    let updates: UpdateChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: $settings.checksForUpdates) {
                Text("Looks for a new version on GitHub once a day")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let version = updates.availableVersion {
                    Button("Download Version \(version.description)") {
                        NSWorkspace.shared.open(AppInfo.latestReleasePage)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Check Now") {
                        updates.checkNow()
                    }
                    .disabled(updates.isChecking)
                    result
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var result: some View {
        if updates.isChecking {
            Text("Checking…")
        } else {
            switch updates.lastResult {
            case .upToDate:
                Text("\(AppInfo.name) is up to date")
            case .failed:
                Text("Could not check for a new version")
            case nil:
                EmptyView()
            }
        }
    }
}

/// Registers the app as a login item via SMAppService.
struct LaunchAtLoginToggle: View {
    @State private var status = SMAppService.mainApp.status
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Start at login:", isOn: Binding(
                get: { status == .enabled || status == .requiresApproval },
                set: { setEnabled($0) }
            ))
            .labelsHidden()
            if status == .requiresApproval {
                Button("macOS still needs your approval: open Login Items…") {
                    SMAppService.openSystemSettingsLoginItems()
                }
                .buttonStyle(.link)
                .font(.footnote)
            }
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
        status = SMAppService.mainApp.status
    }
}
