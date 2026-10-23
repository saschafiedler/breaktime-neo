import AppKit

/// AppKit entry point: a status item with a popover, a settings window and
/// the break screen. SwiftUI draws the content of each.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = BreakController(settings: AppSettings(launchArguments: ProcessInfo.processInfo.arguments))
    private var statusItem: StatusItemController?
    private lazy var settingsWindow = SettingsWindowController(controller: controller)

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.mainMenu = MainMenu.make()
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if SnapshotExporter.runIfRequested(arguments: ProcessInfo.processInfo.arguments) {
            return
        }
        #endif
        statusItem = StatusItemController(controller: controller) { [weak self] in
            self?.showSettings()
        }
        controller.start()
    }

    @objc func showSettings() {
        settingsWindow.show()
    }
}

/// The app has no visible menu bar most of the time, but while the settings
/// window is in front these menus provide the usual shortcuts.
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Settings…"), action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Quit \(AppInfo.name)"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(appMenu, to: main)

        let editMenu = NSMenu(title: String(localized: "Edit"))
        editMenu.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        add(editMenu, to: main)

        let windowMenu = NSMenu(title: String(localized: "Window"))
        windowMenu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        add(windowMenu, to: main)

        return main
    }

    private static func add(_ menu: NSMenu, to main: NSMenu) {
        let item = NSMenuItem()
        item.submenu = menu
        main.addItem(item)
    }
}
