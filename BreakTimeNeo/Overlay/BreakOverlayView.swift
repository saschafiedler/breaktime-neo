import AppKit
import BreakTimeNeoCore
import SwiftUI

/// Content of the break window, a Liquid Glass panel in the middle of the
/// main display: title, elapsed and remaining time, progress bar,
/// "In a Minute" (more choices behind the arrow) and "Done".
/// An enforced break hides the buttons it does not allow instead of greying
/// them out.
struct BreakWindowView: View {
    let controller: BreakController

    private var settings: AppSettings { controller.settings }

    var body: some View {
        let status = controller.status
        VStack(spacing: 10) {
            Text(verbatim: AppInfo.name)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                // The time already taken is what counts; the rest is secondary.
                Text(Countdown.padded(status.breakElapsed ?? 0))
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Break so far")
                Spacer()
                Text(Countdown.padded(status.remaining ?? 0, roundingUp: true))
                    .fontWeight(.light)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Break left")
            }
            .font(.system(size: 30))
            .monospacedDigit()

            // Moves in one-second steps, in time with the clock above.
            ProgressView(value: status.breakProgress ?? 0)
                .progressViewStyle(.linear)

            buttons
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(width: 300)
    }

    // No Return shortcut on purpose: the window appears while the user may
    // still be typing.
    @ViewBuilder
    private var buttons: some View {
        let showsPostpone = settings.allowsPostponingBreak
        let showsDone = !settings.enforcesBreak
        if showsPostpone || showsDone {
            HStack(spacing: 10) {
                if showsPostpone {
                    Menu {
                        ForEach(PostponeChoice.allCases, id: \.self) { choice in
                            // The shortcut is shown here; OverlayController
                            // handles the key itself, so it works without
                            // opening the menu.
                            Button(choice.title) { controller.postpone(minutes: choice.minutes) }
                                .keyboardShortcut(.escape, modifiers: choice.modifiers)
                        }
                    } label: {
                        Text("In a Minute")
                    } primaryAction: {
                        controller.postpone(minutes: PostponeChoice.oneMinute.minutes)
                    }
                    .buttonStyle(.glass)
                    .fixedSize()
                }
                if showsDone {
                    Button("Done") {
                        controller.skip()
                    }
                    .buttonStyle(.glassProminent)
                    .fixedSize()
                }
            }
        }
        if settings.enforcesBreak {
            Text("Emergency exit: ⌃⌥⌘⎋")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// How far "In a Minute" moves the break, with the Escape shortcuts listed
/// behind the arrow: ⎋ one, ⇧⎋ five, ⇧⌘⎋ fifteen minutes.
enum PostponeChoice: CaseIterable {
    case oneMinute, fiveMinutes, fifteenMinutes

    var minutes: Int {
        switch self {
        case .oneMinute: 1
        case .fiveMinutes: 5
        case .fifteenMinutes: 15
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .oneMinute: "In a Minute"
        case .fiveMinutes: "In 5 Minutes"
        case .fifteenMinutes: "In 15 Minutes"
        }
    }

    var modifiers: EventModifiers {
        switch self {
        case .oneMinute: []
        case .fiveMinutes: .shift
        case .fifteenMinutes: [.shift, .command]
        }
    }

    /// The choice for Escape pressed with these modifiers, if any.
    static func forEscape(with flags: NSEvent.ModifierFlags) -> PostponeChoice? {
        switch flags.intersection(.deviceIndependentFlagsMask) {
        case []: .oneMinute
        case .shift: .fiveMinutes
        case [.shift, .command]: .fifteenMinutes
        default: nil
        }
    }
}
