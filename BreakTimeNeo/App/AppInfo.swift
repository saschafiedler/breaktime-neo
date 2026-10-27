import Foundation

/// Name and version as the user sees them.
enum AppInfo {
    /// Product name; not translated.
    static let name = "BreakTime Neo"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    /// Website of the original BreakTime, linked in the settings as a thank-you.
    static let originalWebsite = URL(string: "https://www.breaktimeapp.com")!

    /// GitHub's answer for the latest release, read by the update check
    /// (see S26 in docs/DECISIONS.md).
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/saschafiedler/breaktime-neo/releases/latest")!

    /// Download page of the latest release, opened from the update hint.
    static let latestReleasePage = URL(string: "https://github.com/saschafiedler/breaktime-neo/releases/latest")!
}
