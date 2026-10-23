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
}
