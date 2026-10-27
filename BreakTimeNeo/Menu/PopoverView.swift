import BreakTimeNeoCore
import SwiftUI

/// Content of the popover under the menu bar icon: big countdown on the left,
/// on/off switch, and a slider that moves the next break.
struct PopoverView: View {
    let controller: BreakController
    let updates: UpdateChecker
    let openSettings: () -> Void
    /// Seconds while the slider is being dragged; committed on release.
    @State private var draggedSeconds: Double?

    var body: some View {
        let status = controller.status
        HStack(alignment: .center, spacing: 12) {
            // Fixed size, so the popover is equally big in every state.
            headline(for: status)
                .frame(width: 76, height: 60)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(caption(for: status))
                        .font(.title3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 12)
                    Toggle(isOn: Binding(
                        get: { controller.isEnabled },
                        set: { controller.setEnabled($0) }
                    )) {
                        Text(verbatim: AppInfo.name)
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                HStack(spacing: 10) {
                    Slider(value: sliderPosition(for: status), in: 0...1) { editing in
                        if !editing, let seconds = draggedSeconds {
                            controller.scheduleBreak(inSeconds: TimeSnap.secondsThenMinutes(seconds))
                            draggedSeconds = nil
                        }
                    }
                    .disabled(!canMoveBreak(status))
                    .accessibilityLabel("Time until the next break")

                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            // A new version is out (see S26).
                            .overlay(alignment: .topTrailing) {
                                if updates.announcedVersion != nil {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 6, height: 6)
                                        .offset(x: 2, y: -1)
                                }
                            }
                    }
                    .buttonStyle(.borderless)
                    .help(updates.announcedVersion == nil ? "Settings" : "Settings: a new version is available")
                    .accessibilityLabel(updates.announcedVersion == nil ? "Settings" : "Settings: a new version is available")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 320)
    }

    // MARK: - Parts

    @ViewBuilder
    private func headline(for status: StatusSnapshot) -> some View {
        switch status.kind {
        case .paused:
            Image(systemName: "infinity")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
        case .away:
            Image(systemName: "moon.zzz")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
        case .working, .warning, .onBreak:
            // Standard system font (SF Pro) at display size.
            Text(verbatim: "\(displayed(for: status).value)")
                .font(.system(size: 52, weight: .regular))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(status.kind == .onBreak ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
        }
    }

    private func caption(for status: StatusSnapshot) -> String {
        switch status.kind {
        case .working, .warning:
            let shown = displayed(for: status)
            if shown.inMinutes {
                return shown.value == 1
                    ? String(localized: "minute until break")
                    : String(localized: "minutes until break")
            }
            switch shown.value {
            case 0: return String(localized: "Break starts now")
            case 1: return String(localized: "second until break")
            default: return String(localized: "seconds until break")
            }
        case .onBreak:
            let headline = Countdown.headline(status.remaining ?? 0)
            return headline.inMinutes
                ? String(localized: "minutes of break left")
                : String(localized: "seconds of break left")
        case .away:
            return String(localized: "You are away")
        case .paused:
            guard let until = status.pausedUntil else {
                return String(localized: "\(AppInfo.name) is off")
            }
            return String(localized: "\(AppInfo.name) is off until \(StatusLine.describe(until))")
        }
    }

    /// The big number: the value being dragged to, otherwise the countdown.
    private func displayed(for status: StatusSnapshot) -> (value: Int, inMinutes: Bool) {
        guard let draggedSeconds else {
            return Countdown.headline(status.remaining ?? 0)
        }
        let snapped = TimeSnap.secondsThenMinutes(draggedSeconds)
        return snapped < 60 ? (snapped, false) : (snapped / 60, true)
    }

    // MARK: - Slider

    /// Not linear: the right end is one work interval, 1 second sits close
    /// to the left end, and the last minute gets about a third of the width.
    private var scale: PowerScale {
        PowerScale(lower: 0, upper: Double(max(controller.settings.workInterval, 60)), exponent: 3)
    }

    private func sliderPosition(for status: StatusSnapshot) -> Binding<Double> {
        Binding(
            get: {
                if let draggedSeconds {
                    return scale.position(of: draggedSeconds)
                }
                guard canMoveBreak(status), let remaining = status.remaining else {
                    return status.kind == .paused ? 0.5 : 0
                }
                return scale.position(of: remaining)
            },
            set: { draggedSeconds = scale.value(at: $0) }
        )
    }

    private func canMoveBreak(_ status: StatusSnapshot) -> Bool {
        status.kind == .working || status.kind == .warning
    }
}
