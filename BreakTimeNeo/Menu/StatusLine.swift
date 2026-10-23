import BreakTimeNeoCore
import Foundation

/// One line describing the current state, for the tooltip and the header of
/// the right-click menu.
enum StatusLine {
    static func text(for status: StatusSnapshot, now: Date) -> String {
        let remaining = status.remaining ?? 0
        switch status.kind {
        case .working:
            let time = (now + remaining).formatted(date: .omitted, time: .shortened)
            return String(localized: "Next break in \(Countdown.short(remaining)) (at \(time))")
        case .warning:
            return String(localized: "Break starts in \(Countdown.clock(remaining))")
        case .onBreak:
            return String(localized: "Break ends in \(Countdown.clock(remaining))")
        case .away:
            return String(localized: "You are away from your Mac")
        case .paused:
            guard let until = status.pausedUntil else {
                return String(localized: "\(AppInfo.name) is off")
            }
            return String(localized: "\(AppInfo.name) is off until \(describe(until))")
        }
    }

    static func describe(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return time
        }
        if calendar.isDateInTomorrow(date) {
            return String(localized: "tomorrow, \(time)")
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
