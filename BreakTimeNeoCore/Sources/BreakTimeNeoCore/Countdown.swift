import Foundation

/// Text for remaining times.
public enum Countdown {
    /// Compact form for the menu bar: whole minutes (rounded up) from one
    /// minute on, so the label does not change every second; below that
    /// seconds as `0:42`.
    public static func short(_ remaining: TimeInterval) -> String {
        let seconds = wholeSeconds(remaining)
        if seconds >= 60 {
            let minutes = (seconds + 59) / 60
            return "\(minutes) min"
        }
        return clock(TimeInterval(seconds))
    }

    /// The big number in the popover: whole minutes (rounded up) from one
    /// minute on, below that seconds.
    public static func headline(_ remaining: TimeInterval) -> (value: Int, inMinutes: Bool) {
        let seconds = wholeSeconds(remaining)
        if seconds >= 60 {
            return ((seconds + 59) / 60, true)
        }
        return (seconds, false)
    }

    /// Two-digit clock `00:15` or `04:12` (hours as `1:02:05`) for the break
    /// window. Elapsed time rounds down and remaining time up, so the two
    /// always add up to the break length.
    public static func padded(_ interval: TimeInterval, roundingUp: Bool = false) -> String {
        let seconds = interval.isFinite && interval > 0 ? Int(interval.rounded(roundingUp ? .up : .down)) : 0
        let hours = seconds / 3600
        let minutes = seconds / 60 % 60
        let rest = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, rest)
        }
        return String(format: "%02d:%02d", minutes, rest)
    }

    /// Clock form `4:12` or `1:02:05`, rounded up to whole seconds.
    public static func clock(_ remaining: TimeInterval) -> String {
        let seconds = wholeSeconds(remaining)
        let hours = seconds / 3600
        let minutes = seconds / 60 % 60
        let rest = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, rest)
        }
        return String(format: "%d:%02d", minutes, rest)
    }

    private static func wholeSeconds(_ interval: TimeInterval) -> Int {
        guard interval.isFinite, interval > 0 else { return 0 }
        return Int(interval.rounded(.up))
    }
}

/// End times for "pause reminders" choices.
public enum PauseUntil {
    /// The next `hour`:00 after `date`, e.g. 6:00 tomorrow when it is evening,
    /// or 6:00 today shortly after midnight.
    public static func nextMorning(after date: Date, hour: Int = 6, calendar: Calendar = .current) -> Date {
        calendar.nextDate(
            after: date,
            matching: DateComponents(hour: hour, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(24 * 3600)
    }
}
