import AppKit
import SwiftUI

/// The break screen: a dimming panel per display (or only the main display)
/// above all windows, on every Space and over full-screen apps, and on the
/// main display a standard window with the break controls on top of it.
/// Everything appears and disappears at once, without fading.
final class OverlayController {
    /// How dark the screen gets; content underneath stays readable.
    static let dimming = 0.45

    private var panels: [NSPanel] = []
    /// Windows built ahead during the warning, not yet on screen.
    private var prepared: [NSPanel] = []
    private var screenObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var isEnforcing = false
    private var optionsBeforeEnforcing: NSApplication.PresentationOptions = []
    private weak var controller: BreakController?

    var isShowing: Bool { !panels.isEmpty }

    /// Builds the windows ahead of a break (during the warning), so showing
    /// them later is instant.
    func prepare(controller: BreakController) {
        self.controller = controller
        guard panels.isEmpty, prepared.isEmpty else { return }
        prepared = makePanels()
    }

    /// Drops windows built for a warning that did not end in a break
    /// (postponed, skipped, switched off).
    func discardPrepared() {
        prepared = []
    }

    func show(controller: BreakController) {
        self.controller = controller
        guard panels.isEmpty else { return }
        orderFront(prepared.isEmpty ? makePanels() : prepared)
        prepared = []
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildPanels() }
        }
        if controller.settings.enforcesBreak {
            enforce()
        }
        watchKeys()
    }

    /// The break window holds the keyboard during a break: ⎋, ⇧⎋ and ⇧⌘⎋
    /// postpone by 1, 5 or 15 minutes (when allowed); ⌃⌥⌘⎋ always ends
    /// the break, so nobody can lock themselves out of an enforced one.
    private func watchKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            MainActor.assumeIsolated {
                guard let controller = self?.controller else { return }
                if flags == [.control, .option, .command] {
                    controller.skip()
                } else if controller.settings.allowsPostponingBreak, let choice = PostponeChoice.forEscape(with: flags) {
                    controller.postpone(minutes: choice.minutes)
                }
            }
            return nil
        }
    }

    /// Enforced break: the app comes to the front and macOS blocks switching
    /// apps (⌘⇥) while it is. The panels already catch all clicks. Force quit
    /// (⌥⌘⎋) stays available.
    private func enforce() {
        NSApp.activate()
        optionsBeforeEnforcing = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .disableProcessSwitching, .disableHideApplication]
        isEnforcing = true
    }

    private func stopWatching() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if isEnforcing {
            NSApp.presentationOptions = optionsBeforeEnforcing
            isEnforcing = false
            // Hand the keyboard back to the app the user came from.
            NSApp.hide(nil)
        }
    }

    func hide() {
        stopWatching()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        for panel in panels + prepared {
            panel.orderOut(nil)
        }
        panels = []
        prepared = []
    }

    /// Displays were added, removed or rearranged during a break.
    private func rebuildPanels() {
        guard !panels.isEmpty else { return }
        for panel in panels {
            panel.orderOut(nil)
        }
        panels = []
        orderFront(makePanels())
    }

    /// Dimming for each display (or the main one), then the break window
    /// centred on the main display, which is the one with the menu bar.
    private func makePanels() -> [NSPanel] {
        guard let controller, let mainScreen = NSScreen.screens.first else { return [] }
        let screens = controller.settings.dimsAllDisplays ? NSScreen.screens : [mainScreen]
        var result: [NSPanel] = screens.map { DimmingPanel(screen: $0) }
        let window = BreakPanel(content: BreakWindowView(controller: controller))
        let area = mainScreen.visibleFrame
        window.setFrameOrigin(NSPoint(
            x: area.midX - window.frame.width / 2,
            y: area.midY - window.frame.height / 2
        ))
        result.append(window)
        return result
    }

    private func orderFront(_ newPanels: [NSPanel]) {
        for panel in newPanels {
            if panel is BreakPanel {
                // Takes keyboard focus without activating the app, so typing
                // does not continue into the window underneath.
                panel.makeKeyAndOrderFront(nil)
            } else {
                panel.orderFrontRegardless()
            }
        }
        panels = newPanels
    }
}

/// Darkens one display and catches all clicks during a break.
private final class DimmingPanel: NSPanel {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = NSColor.black.withAlphaComponent(OverlayController.dimming)
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The break window: a Liquid Glass panel like the popover (the same
/// `NSGlassEffectView` macOS uses for popovers and Control Center), above
/// the dimming. Borderless, so the glass defines the shape; the title is a
/// line inside the glass.
private final class BreakPanel: NSPanel {
    /// Corner radius of the system popover on macOS 27, so both match.
    static let cornerRadius: CGFloat = 20

    init(content: some View) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        let hosting = NSHostingView(rootView: content)
        let glass = NSGlassEffectView()
        glass.cornerRadius = Self.cornerRadius
        glass.contentView = hosting
        contentView = glass
        setContentSize(hosting.fittingSize)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
