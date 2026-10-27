import Foundation

/// A version number such as `1.2.3`, compared part by part as numbers, so
/// that 1.10 comes after 1.9 and 1.1 equals 1.1.0.
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    public let parts: [Int]

    /// Reads `1.2.3` or a release tag like `v1.2.3`. Anything else, such as
    /// the pre-release `1.2.0-beta.1`, is not a version here.
    public init?(_ text: String) {
        let number = text.hasPrefix("v") ? text.dropFirst() : text[...]
        var parts: [Int] = []
        for part in number.split(separator: ".", omittingEmptySubsequences: false) {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(part) else {
                return nil
            }
            parts.append(value)
        }
        self.parts = parts
    }

    public var description: String {
        parts.map { String($0) }.joined(separator: ".")
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.padded(to: rhs) == rhs.padded(to: lhs)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for (left, right) in zip(lhs.padded(to: rhs), rhs.padded(to: lhs)) where left != right {
            return left < right
        }
        return false
    }

    /// The parts, with zeros added until they are as many as `other`'s.
    private func padded(to other: AppVersion) -> [Int] {
        parts + Array(repeating: 0, count: max(other.parts.count - parts.count, 0))
    }
}

/// Looking for a new version: the app reads the latest release on GitHub
/// and compares its tag with its own version (see S26 in docs/DECISIONS.md).
public enum UpdateCheck {
    /// Time between two successful checks.
    public static let interval: TimeInterval = 24 * 3600

    /// Whether to check now: never checked yet, the last successful check is
    /// a day old, or the clock was set back since.
    public static func isDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed >= interval || elapsed < 0
    }

    /// The version of a release tag such as `v1.1.0`, if it is newer than
    /// the running app's version `current`.
    public static func newerVersion(tag: String?, than current: String) -> AppVersion? {
        guard let tag, let latest = AppVersion(tag), let installed = AppVersion(current), latest > installed else {
            return nil
        }
        return latest
    }

    /// The tag in GitHub's answer for `repos/<owner>/<repo>/releases/latest`.
    /// That address never returns drafts or pre-releases.
    public static func tag(fromLatestRelease json: Data) -> String? {
        struct Release: Decodable {
            let tagName: String
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(Release.self, from: json).tagName
    }
}
