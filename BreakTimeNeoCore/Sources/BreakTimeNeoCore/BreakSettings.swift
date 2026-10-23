import Foundation

/// The rhythm the engine works with. All values are in seconds.
public struct BreakSettings: Equatable, Sendable {
    /// Working time from the end of one break to the start of the next.
    public var workInterval: TimeInterval
    /// Length of a break.
    public var breakDuration: TimeInterval
    /// How long before a break the warning starts. `0` turns the warning off.
    public var warningLead: TimeInterval
    /// Time without any input after which the user counts as away. An absence
    /// at least this long counts as a break and restarts the work interval.
    public var awayThreshold: TimeInterval
    /// Whether idle time makes the user count as away. Sleep and screen lock
    /// count regardless.
    public var detectsIdle: Bool

    public init(
        workInterval: TimeInterval,
        breakDuration: TimeInterval,
        warningLead: TimeInterval,
        awayThreshold: TimeInterval,
        detectsIdle: Bool = true
    ) {
        self.workInterval = workInterval
        self.breakDuration = breakDuration
        self.warningLead = warningLead
        self.awayThreshold = awayThreshold
        self.detectsIdle = detectsIdle
    }

    /// Defaults on first launch: the 20-20-20 rule (see S2 in
    /// docs/DECISIONS.md).
    public static let standard = BreakSettings(
        workInterval: 20 * 60,
        breakDuration: 20,
        warningLead: 10,
        awayThreshold: 5 * 60
    )

    /// Values clamped to ranges the engine can handle: positive durations and
    /// a warning that fits into the work interval.
    public var sanitized: BreakSettings {
        let work = max(workInterval, 10)
        return BreakSettings(
            workInterval: work,
            breakDuration: max(breakDuration, 5),
            warningLead: min(max(warningLead, 0), work / 2),
            awayThreshold: max(awayThreshold, 10),
            detectsIdle: detectsIdle
        )
    }
}
