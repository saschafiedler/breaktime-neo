import BreakTimeNeoCore
import Foundation
import Observation

/// Looks on GitHub for a newer release: once a day while automatic checks
/// are on, and whenever the user asks. It only points to the download page
/// and never downloads or installs anything (see S26 in docs/DECISIONS.md).
@Observable
final class UpdateChecker {
    enum CheckResult {
        case upToDate
        case failed
    }

    /// The latest release, if it is newer than this app. Kept across
    /// launches, so the hint does not wait for the next check.
    private(set) var availableVersion: AppVersion?
    private(set) var isChecking = false
    /// Outcome of the last check the user started, for the settings.
    private(set) var lastResult: CheckResult? = nil

    /// The new version the popover and the menu point to: only while
    /// automatic checks are on, so turning them off also hides the hint.
    var announcedVersion: AppVersion? {
        settings.checksForUpdates ? availableVersion : nil
    }

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let currentVersion: String
    /// Time of the last successful check; failed checks do not count.
    @ObservationIgnored private var lastCheck: Date?
    @ObservationIgnored private var timer: Timer?

    init(settings: AppSettings, defaults: UserDefaults = .standard, launchArguments: [String] = []) {
        self.settings = settings
        self.defaults = defaults
        let currentVersion = Self.pretendedVersion(in: launchArguments) ?? AppInfo.version
        self.currentVersion = currentVersion
        lastCheck = defaults.object(forKey: Key.lastUpdateCheck.rawValue) as? Date
        availableVersion = UpdateCheck.newerVersion(tag: defaults.string(forKey: Key.latestReleaseTag.rawValue), than: currentVersion)
    }

    /// Looks every hour whether a check is due, so a check that failed (no
    /// network yet right after login) is tried again soon.
    func start() {
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        timer.tolerance = 300
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        checkIfDue()
    }

    /// "Check Now" in the settings; works with automatic checks off, too.
    func checkNow() {
        check(byUser: true)
    }

    private func checkIfDue() {
        guard settings.checksForUpdates, UpdateCheck.isDue(lastCheck: lastCheck, now: .now) else { return }
        check(byUser: false)
    }

    private func check(byUser: Bool) {
        guard !isChecking else { return }
        isChecking = true
        if byUser {
            lastResult = nil
        }
        Task {
            let tag = await Self.latestReleaseTag()
            isChecking = false
            guard let tag else {
                if byUser {
                    lastResult = .failed
                }
                return
            }
            lastCheck = .now
            availableVersion = UpdateCheck.newerVersion(tag: tag, than: currentVersion)
            if byUser, availableVersion == nil {
                lastResult = .upToDate
            }
            // `--demo` stores nothing.
            if !settings.isDemo {
                defaults.set(lastCheck, forKey: Key.lastUpdateCheck.rawValue)
                defaults.set(tag, forKey: Key.latestReleaseTag.rawValue)
            }
        }
    }

    /// Tag of the latest release on GitHub, e.g. `v1.1.0`; nil when GitHub
    /// cannot be reached or answers with anything else.
    private static func latestReleaseTag() async -> String? {
        var request = URLRequest(url: AppInfo.latestReleaseAPI, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return UpdateCheck.tag(fromLatestRelease: data)
        } catch {
            return nil
        }
    }

    /// `--update-as 1.0.0` (Debug builds): the app takes itself for that
    /// version, so "Check Now" shows the hint for the latest release.
    private static func pretendedVersion(in arguments: [String]) -> String? {
        #if DEBUG
        if let index = arguments.firstIndex(of: "--update-as"), index + 1 < arguments.count {
            return arguments[index + 1]
        }
        #endif
        return nil
    }

    #if DEBUG
    /// For snapshots: shows a new version without asking GitHub.
    func setAvailableVersion(_ version: AppVersion?) {
        availableVersion = version
    }
    #endif

    private enum Key: String {
        case lastUpdateCheck, latestReleaseTag
    }
}
