#if DEBUG
import AppKit
import BreakTimeNeoCore
import SwiftUI

/// Debug aid: `--snapshots <folder>` writes PNGs of the menu bar icon, the
/// popover, the break screen and the settings window, then quits. It only
/// draws the app's own views, so it needs no screen recording permission and
/// nothing dims the screen.
enum SnapshotExporter {
    static func runIfRequested(arguments: [String]) -> Bool {
        guard let index = arguments.firstIndex(of: "--snapshots"), index + 1 < arguments.count else {
            return false
        }
        let folder = URL(filePath: arguments[index + 1], directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Task {
            export(to: folder)
            NSApp.terminate(nil)
        }
        return true
    }

    private static func export(to folder: URL) {
        var report: [String] = []
        let start = Date.now
        let examples: [(name: String, inputs: [(BreakInput, TimeInterval)])] = [
            ("working-start", [(.tick(idle: 0), 1)]),
            ("working", [(.tick(idle: 0), 5 * 60 + 10)]),
            ("working-late", [(.tick(idle: 0), 16 * 60)]),
            ("working-seconds", [(.tick(idle: 0), 20 * 60 - 42)]),
            ("warning", [(.tick(idle: 0), 20 * 60 - 7)]),
            ("break", [(.startBreak, 0), (.tick(idle: 0), 15.4)]),
            ("away", [(.sleep(idle: 0), 60)]),
            ("paused", [(.pause(until: nil), 60)]),
        ]
        for example in examples {
            let controller = BreakController(settings: snapshotSettings(), now: start)
            let updates = UpdateChecker(settings: controller.settings, defaults: snapshotDefaults())
            for (input, offset) in example.inputs {
                controller.setEngineState(input, at: start + offset)
            }
            let status = controller.status
            report.append("\(example.name): \(StatusLine.text(for: status, now: controller.now))")
            saveIcon(StatusIcon.image(for: status), to: folder, name: "icon-\(example.name)")
            capture(PopoverView(controller: controller, updates: updates) {}, to: folder, name: "popover-\(example.name)")
            if example.name == "break" {
                capture(BreakWindowView(controller: controller), to: folder, name: "overlay")
                controller.settings.enforcesBreak = true
                capture(BreakWindowView(controller: controller), to: folder, name: "overlay-enforced")
                controller.settings.forbidsPostponeWhenEnforced = true
                capture(BreakWindowView(controller: controller), to: folder, name: "overlay-enforced-strict")
            }
        }

        let controller = BreakController(settings: snapshotSettings(), now: start)
        let updates = UpdateChecker(settings: controller.settings, defaults: snapshotDefaults())
        capture(SettingsView(settings: controller.settings, controller: controller, updates: updates, showsAdvanced: true), to: folder, name: "settings")

        // A new version is out: dot on the gear, button in the settings.
        updates.setAvailableVersion(AppVersion("1.2.0"))
        controller.setEngineState(.tick(idle: 0), at: start + 5 * 60 + 10)
        capture(PopoverView(controller: controller, updates: updates) {}, to: folder, name: "popover-update")
        capture(SettingsView(settings: controller.settings, controller: controller, updates: updates), to: folder, name: "settings-update")
        try? report.joined(separator: "\n").write(to: folder.appending(path: "report.txt"), atomically: true, encoding: .utf8)
    }

    private static func snapshotSettings() -> AppSettings {
        AppSettings(defaults: snapshotDefaults())
    }

    /// Empty defaults, so stored settings and update checks of the
    /// installed app do not show up in the snapshots.
    private static func snapshotDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "com.saschafiedler.breaktimeneo.snapshots")!
        defaults.removePersistentDomain(forName: "com.saschafiedler.breaktimeneo.snapshots")
        return defaults
    }

    /// Draws the template icon black on white at 4×, as in a light menu bar.
    private static func saveIcon(_ icon: NSImage, to folder: URL, name: String) {
        let size = NSSize(width: 72, height: 72)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            icon.draw(in: rect)
            return true
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return }
        save(rep, to: folder, name: name)
    }

    /// Lays the view out in an off-screen window, so AppKit-backed controls
    /// (buttons, sliders, switches) are drawn too.
    private static func capture(_ view: some View, to folder: URL, name: String) {
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        let frame = CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: host.fittingSize)
        let window = SnapshotWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: .now + 0.4)
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            save(rep, to: folder, name: name)
        }
        window.orderOut(nil)
    }

    private static func save(_ rep: NSBitmapImageRep, to folder: URL, name: String) {
        try? rep.representation(using: .png, properties: [:])?.write(to: folder.appending(path: "\(name).png"))
    }
}
/// Off-screen window that draws its controls as active, like the popover
/// does on screen (see KeyAppearance).
private final class SnapshotWindow: NSWindow {
    @objc var hasKeyAppearance: Bool { true }
}
#endif
