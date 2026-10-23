import AppKit
import CoreGraphics
import IOKit.pwr_mgt

/// Reports how long the user has not touched keyboard, mouse or trackpad, and
/// when they leave or come back (sleep, display sleep, screen lock, user
/// switch). Needs no Accessibility permission.
final class ActivityMonitor {
    enum Change: Sendable {
        case left
        case returned
    }

    var onChange: ((Change) -> Void)?

    private var tokens: [NSObjectProtocol] = []

    var idleSeconds: TimeInterval {
        // ~0 stands for "any input event".
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// Whether some app asks macOS to keep the display on, as video players
    /// and video calls do while playing. Read from the power management
    /// assertions; no screen access or permission needed.
    var isDisplayKeptAwake: Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let counts = status?.takeRetainedValue() as? [String: Int] else {
            return false
        }
        return (counts["PreventUserIdleDisplaySleep"] ?? 0) > 0
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification, as: .left)
        observe(workspace, NSWorkspace.screensDidSleepNotification, as: .left)
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification, as: .left)
        observe(workspace, NSWorkspace.didWakeNotification, as: .returned)
        observe(workspace, NSWorkspace.screensDidWakeNotification, as: .returned)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, as: .returned)

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), as: .left)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), as: .returned)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, as change: Change) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onChange?(change)
            }
        }
        tokens.append(token)
    }
}
