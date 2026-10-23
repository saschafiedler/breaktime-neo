import AppKit
import SwiftUI

/// Opens the settings window and brings it to the front. The app has no
/// Dock icon, so it has to activate itself for the window to get focus.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let controller: BreakController
    private var window: NSWindow?

    init(controller: BreakController) {
        self.controller = controller
        super.init()
    }

    func show() {
        if window == nil {
            let content = NSHostingController(rootView: SettingsView(settings: controller.settings, controller: controller))
            let window = NSWindow(contentViewController: content)
            window.title = String(localized: "Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            // SwiftUI sizes the window only when it appears; without this the
            // window would be centred at 1×32 points and then grow to the
            // upper right.
            content.view.layoutSubtreeIfNeeded()
            window.setContentSize(content.view.fittingSize)
            // Remembers where the user put it; the first time it is centred.
            if !window.setFrameUsingName(Self.frameName) {
                window.center()
            }
            window.setFrameAutosaveName(Self.frameName)
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private static let frameName = "SettingsWindow"

    /// Hand the keyboard back to the app the user came from; this app has
    /// no other windows to show.
    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }
}
