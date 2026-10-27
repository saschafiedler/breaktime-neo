import BreakTimeNeoCore
import Foundation
import Observation

/// User settings, stored in UserDefaults. Durations are whole seconds.
@Observable
final class AppSettings {
    var workInterval: Int { didSet { save(workInterval, for: .workInterval) } }
    var breakDuration: Int { didSet { save(breakDuration, for: .breakDuration) } }
    var warningEnabled: Bool { didSet { save(warningEnabled, for: .warningEnabled) } }
    var detectsIdle: Bool { didSet { save(detectsIdle, for: .detectsIdle) } }
    var awayThreshold: Int { didSet { save(awayThreshold, for: .awayThreshold) } }
    var playSounds: Bool { didSet { save(playSounds, for: .playSounds) } }
    /// Minutes next to the menu bar icon; off shows the icon only.
    var showsTimeInMenuBar: Bool { didSet { save(showsTimeInMenuBar, for: .showsTimeInMenuBar) } }
    /// Break screen on every display; off shows it on the main display only.
    var dimsAllDisplays: Bool { didSet { save(dimsAllDisplays, for: .dimsAllDisplays) } }
    /// Enforced break: no "done", no switching apps; an emergency shortcut
    /// always ends it.
    var enforcesBreak: Bool { didSet { save(enforcesBreak, for: .enforcesBreak) } }
    /// With an enforced break, also hide "one more minute".
    var forbidsPostponeWhenEnforced: Bool { didSet { save(forbidsPostponeWhenEnforced, for: .forbidsPostponeWhenEnforced) } }
    /// A playing video (an app keeps the display awake) counts as presence.
    var videoCountsAsPresence: Bool { didSet { save(videoCountsAsPresence, for: .videoCountsAsPresence) } }
    /// Looks for a new version on GitHub once a day (see S26).
    var checksForUpdates: Bool { didSet { save(checksForUpdates, for: .checksForUpdates) } }

    /// Called after every change, so the running rhythm can pick it up.
    @ObservationIgnored var onChange: (() -> Void)?
    /// `--demo` uses a fast rhythm for trying things out and stores nothing.
    @ObservationIgnored let isDemo: Bool
    @ObservationIgnored private let defaults: UserDefaults

    /// The warning lead is fixed; the setting only turns it on or off.
    static let warningLead: TimeInterval = 10
    static let breakStartSound = "Blow"
    static let breakEndSound = "Glass"

    init(defaults: UserDefaults = .standard, launchArguments: [String] = []) {
        self.defaults = defaults
        isDemo = launchArguments.contains("--demo")
        let standard = BreakSettings.standard
        defaults.register(defaults: [
            Key.workInterval.rawValue: Int(standard.workInterval),
            Key.breakDuration.rawValue: Int(standard.breakDuration),
            Key.warningEnabled.rawValue: true,
            Key.detectsIdle.rawValue: true,
            Key.awayThreshold.rawValue: Int(standard.awayThreshold),
            Key.playSounds.rawValue: true,
            Key.showsTimeInMenuBar.rawValue: false,
            Key.dimsAllDisplays.rawValue: true,
            Key.videoCountsAsPresence.rawValue: true,
            Key.enforcesBreak.rawValue: false,
            Key.forbidsPostponeWhenEnforced.rawValue: false,
            Key.checksForUpdates.rawValue: true,
        ])
        workInterval = isDemo ? 40 : defaults.integer(forKey: Key.workInterval.rawValue)
        breakDuration = isDemo ? 15 : defaults.integer(forKey: Key.breakDuration.rawValue)
        warningEnabled = defaults.bool(forKey: Key.warningEnabled.rawValue)
        detectsIdle = defaults.bool(forKey: Key.detectsIdle.rawValue)
        awayThreshold = isDemo ? 30 : defaults.integer(forKey: Key.awayThreshold.rawValue)
        playSounds = defaults.bool(forKey: Key.playSounds.rawValue)
        showsTimeInMenuBar = defaults.bool(forKey: Key.showsTimeInMenuBar.rawValue)
        dimsAllDisplays = defaults.bool(forKey: Key.dimsAllDisplays.rawValue)
        videoCountsAsPresence = defaults.bool(forKey: Key.videoCountsAsPresence.rawValue)
        enforcesBreak = defaults.bool(forKey: Key.enforcesBreak.rawValue)
        forbidsPostponeWhenEnforced = defaults.bool(forKey: Key.forbidsPostponeWhenEnforced.rawValue)
        checksForUpdates = defaults.bool(forKey: Key.checksForUpdates.rawValue)
    }

    /// Whether the break window offers "one more minute".
    var allowsPostponingBreak: Bool { !(enforcesBreak && forbidsPostponeWhenEnforced) }

    var breakSettings: BreakSettings {
        BreakSettings(
            workInterval: TimeInterval(workInterval),
            breakDuration: TimeInterval(breakDuration),
            warningLead: warningEnabled ? Self.warningLead : 0,
            awayThreshold: TimeInterval(awayThreshold),
            detectsIdle: detectsIdle
        )
    }

    private enum Key: String {
        case workInterval, breakDuration, warningEnabled
        case detectsIdle, awayThreshold, playSounds, showsTimeInMenuBar
        case dimsAllDisplays, videoCountsAsPresence, enforcesBreak, forbidsPostponeWhenEnforced
        case checksForUpdates
    }

    private func save(_ value: Any, for key: Key) {
        if !isDemo {
            defaults.set(value, forKey: key.rawValue)
        }
        onChange?()
    }
}
