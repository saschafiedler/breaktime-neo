import Foundation

/// What the menu bar and the break screen show at one moment.
public struct StatusSnapshot: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case working
        case warning
        case onBreak
        case away
        case paused
    }

    public var kind: Kind
    /// Time left until the break (working, warning) or until its end (on break).
    public var remaining: TimeInterval?
    /// Share of the running break that is over, 0…1.
    public var breakProgress: Double?
    /// Time since the running break started.
    public var breakElapsed: TimeInterval?
    /// Share of the work interval that is over, 0…1, for the menu bar icon.
    /// Full during a break, `nil` while away or paused.
    public var workProgress: Double?
    /// End of a time-limited pause.
    public var pausedUntil: Date?

    /// Short text next to the menu bar icon; `nil` shows the icon only.
    public var menuBarText: String? {
        guard let remaining else { return nil }
        switch kind {
        case .working: return Countdown.short(remaining)
        case .warning, .onBreak: return Countdown.clock(remaining)
        case .away, .paused: return nil
        }
    }
}

extension BreakEngine {
    public func snapshot(at now: Date) -> StatusSnapshot {
        switch phase {
        case .working(let next):
            StatusSnapshot(kind: .working, remaining: next.timeIntervalSince(now), workProgress: workProgress(until: next, at: now))
        case .warning(let next):
            StatusSnapshot(kind: .warning, remaining: next.timeIntervalSince(now), workProgress: workProgress(until: next, at: now))
        case .onBreak(let started, let ends), .away(_, .rest(let started, let ends), _):
            StatusSnapshot(
                kind: .onBreak,
                remaining: ends.timeIntervalSince(now),
                breakProgress: Self.progress(from: started, to: ends, at: now),
                breakElapsed: max(now.timeIntervalSince(started), 0),
                workProgress: 1
            )
        case .away:
            StatusSnapshot(kind: .away)
        case .paused(let until):
            StatusSnapshot(kind: .paused, pausedUntil: until)
        }
    }

    /// A break postponed beyond one interval shows an empty icon.
    private func workProgress(until next: Date, at now: Date) -> Double {
        let remaining = next.timeIntervalSince(now)
        return min(max(1 - remaining / settings.workInterval, 0), 1)
    }

    private static func progress(from start: Date, to end: Date, at now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(max(now.timeIntervalSince(start) / total, 0), 1)
    }
}
