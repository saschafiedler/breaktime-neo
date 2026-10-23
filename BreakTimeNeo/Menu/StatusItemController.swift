import AppKit
import BreakTimeNeoCore
import SwiftUI

/// The menu bar item: a ring that fills up towards the next break. A click
/// opens the popover; a right-click (or control-click) opens a short menu
/// with extra actions.
final class StatusItemController: NSObject {
    private let controller: BreakController
    private let openSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var iconKey: String?
    private var lastKind: StatusSnapshot.Kind?
    private var widthTemplate: String?
    private var outsideClickMonitor: Any?
    private var menuActions: MenuActions?

    init(controller: BreakController, openSettings: @escaping () -> Void) {
        self.controller = controller
        self.openSettings = openSettings
        super.init()

        let content = NSHostingController(rootView: PopoverView(controller: controller) { [weak self] in
            self?.popover.performClose(nil)
            openSettings()
        })
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
        popover.delegate = self
        // Appears at once, like everything else in the app.
        popover.animates = false

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.alignment = .left
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }
        controller.onUpdate = { [weak self] in self?.update() }
        update()
    }

    private func update() {
        guard let button = statusItem.button else { return }
        let status = controller.status
        let key = StatusIcon.key(for: status)
        if key != iconKey {
            button.image = StatusIcon.image(for: status)
            iconKey = key
        }
        let showsTime = controller.settings.showsTimeInMenuBar
        let template = showsTime ? widestTitle(for: status) : nil
        if template != widthTemplate {
            applyWidth(for: template)
        }
        let title = showsTime ? menuBarTitle(for: status) : ""
        if button.title != title {
            button.title = title
        }
        button.appearsDisabled = status.kind == .paused
        button.toolTip = StatusLine.text(for: status, now: controller.now)

        if status.kind != lastKind {
            switch status.kind {
            case .warning:
                // Like BreakTime: the same popover opens by itself and counts
                // the last seconds down, without taking the keyboard away.
                showPopover()
            case .onBreak:
                popover.performClose(nil)
            default:
                break
            }
            lastKind = status.kind
        }
    }

    /// Time next to the icon, only when turned on in the settings: minutes,
    /// under a minute `0:42`.
    private func menuBarTitle(for status: StatusSnapshot) -> String {
        guard let remaining = status.remaining else { return "" }
        switch status.kind {
        case .working, .warning, .onBreak:
            return Countdown.short(remaining)
        case .away, .paused:
            return ""
        }
    }

    /// The widest text the item can show in this rhythm: a full work interval
    /// (or more, after postponing) with every digit as 8.
    private func widestTitle(for status: StatusSnapshot) -> String {
        let longest = max(TimeInterval(controller.settings.workInterval), status.remaining ?? 0)
        return String(Countdown.short(longest).map { $0.isNumber ? "8" : $0 })
    }

    /// With the time shown, the item keeps the width of its widest text, so
    /// it and the popover hanging from it never jump when a digit drops away.
    /// Only as wide as needed, with the standard gap between icon and text.
    private func applyWidth(for template: String?) {
        guard let button = statusItem.button else { return }
        if let template {
            let current = button.title
            button.title = template
            statusItem.length = ceil(button.fittingSize.width)
            button.title = current
        } else {
            statusItem.length = NSStatusItem.variableLength
        }
        widthTemplate = template
    }

    @objc private func clicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    /// Shows the popover without activating the app, so the app the user
    /// works in keeps the keyboard (the popover is a non-activating panel).
    /// The same popover opens on a click and by itself before a break.
    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            KeyAppearance.force(onPopoverWindow: window)
        }
        // While the app is not active, a transient popover does not notice
        // clicks into other apps; close it on any click outside.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.popover.performClose(nil) }
        }
    }

    private func showMenu() {
        popover.performClose(nil)
        let status = controller.status
        let actions = MenuActions()
        menuActions = actions
        let menu = NSMenu()
        let header = NSMenuItem(title: StatusLine.text(for: status, now: controller.now), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        switch status.kind {
        case .onBreak:
            menu.addItem(actions.item(String(localized: "End Break")) { [controller] in controller.skip() })
        case .paused:
            menu.addItem(actions.item(String(localized: "Turn On")) { [controller] in controller.resume() })
            menu.addItem(actions.item(String(localized: "Start Break Now")) { [controller] in controller.startBreak() })
        case .working, .warning, .away:
            menu.addItem(actions.item(String(localized: "Start Break Now")) { [controller] in controller.startBreak() })
            menu.addItem(actions.item(String(localized: "Skip Next Break")) { [controller] in controller.skip() })
            let pauseMenu = NSMenu()
            pauseMenu.addItem(actions.item(String(localized: "For 1 Hour")) { [controller] in controller.pause(until: .now + 3600) })
            pauseMenu.addItem(actions.item(String(localized: "For 3 Hours")) { [controller] in controller.pause(until: .now + 3 * 3600) })
            pauseMenu.addItem(actions.item(String(localized: "Until Tomorrow Morning")) { [controller] in
                controller.pause(until: PauseUntil.nextMorning(after: .now))
            })
            let pauseItem = NSMenuItem(title: String(localized: "Turn Off"), action: nil, keyEquivalent: "")
            pauseItem.submenu = pauseMenu
            menu.addItem(pauseItem)
        }

        menu.addItem(.separator())
        menu.addItem(actions.item(String(localized: "Settings…")) { [openSettings] in openSettings() })
        menu.addItem(actions.item(String(localized: "Quit \(AppInfo.name)")) { NSApp.terminate(nil) })

        // Attaching the menu for one click shows it right under the item.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}

/// Runs closures for menu items; the items keep their target only weakly,
/// so the status item controller holds on to this while the menu is open.
final class MenuActions: NSObject {
    private var handlers: [() -> Void] = []

    func item(_ title: String, handler: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(run(_:)), keyEquivalent: "")
        item.target = self
        item.tag = handlers.count
        handlers.append(handler)
        return item
    }

    @objc private func run(_ sender: NSMenuItem) {
        handlers[sender.tag]()
    }
}

/// Draws the menu bar icon: a stopwatch whose face fills up as the work
/// interval runs out. Template image, so macOS tints it for light and dark.
enum StatusIcon {
    /// Steps the pie is drawn in; the icon is only redrawn when this changes.
    private static let steps = 48.0

    static func key(for status: StatusSnapshot) -> String {
        let step = status.workProgress.map { Int(($0 * steps).rounded()) } ?? -1
        return "\(status.kind)-\(step)"
    }

    static func image(for status: StatusSnapshot) -> NSImage {
        let progress = status.workProgress.map { ($0 * steps).rounded() / steps }
        let dashed = status.kind == .away
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            // Case of the stopwatch, a little below the middle to leave room
            // for the crown.
            let center = NSPoint(x: 9, y: 8)
            let caseRadius = 6.25
            let ring = NSBezierPath(ovalIn: NSRect(x: center.x - caseRadius, y: center.y - caseRadius,
                                                   width: caseRadius * 2, height: caseRadius * 2))
            ring.lineWidth = 1.5
            if dashed {
                ring.setLineDash([2, 1.6], count: 2, phase: 0)
            }
            ring.stroke()

            // Crown on top and the small button at the upper right.
            NSBezierPath(rect: NSRect(x: 8.25, y: 14.25, width: 1.5, height: 1.5)).fill()
            NSBezierPath(roundedRect: NSRect(x: 6.5, y: 15.5, width: 5, height: 1.75), xRadius: 0.8, yRadius: 0.8).fill()
            let button = NSBezierPath()
            button.move(to: NSPoint(x: 13.6, y: 12.6))
            button.line(to: NSPoint(x: 14.9, y: 13.9))
            button.lineWidth = 1.6
            button.lineCapStyle = .round
            button.stroke()

            if let progress, progress > 0 {
                let radius = caseRadius - 2.5
                let pie = NSBezierPath()
                if progress >= 1 {
                    pie.appendOval(in: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                } else {
                    pie.move(to: center)
                    pie.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * progress, clockwise: true)
                    pie.close()
                }
                pie.fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = AppInfo.name
        return image
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }
}
