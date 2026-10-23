import Foundation
import Testing
@testable import BreakTimeNeoCore

struct CountdownTests {
    @Test(arguments: [
        (23 * 60 + 10.0, "24 min"),
        (60.0, "1 min"),
        (59.5, "1 min"),
        (59.0, "0:59"),
        (0.2, "0:01"),
        (0.0, "0:00"),
        (-5.0, "0:00"),
    ])
    func short(remaining: TimeInterval, expected: String) {
        #expect(Countdown.short(remaining) == expected)
    }

    @Test(arguments: [
        (252.0, "4:12"),
        (3725.0, "1:02:05"),
        (TimeInterval.infinity, "0:00"),
        (TimeInterval.nan, "0:00"),
    ])
    func clock(remaining: TimeInterval, expected: String) {
        #expect(Countdown.clock(remaining) == expected)
    }
}

struct PauseUntilTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func eveningGoesToNextMorning() {
        #expect(PauseUntil.nextMorning(after: date(21, 22), calendar: calendar) == date(22, 6))
    }

    @Test func afterMidnightGoesToSameMorning() {
        #expect(PauseUntil.nextMorning(after: date(22, 1, 30), calendar: calendar) == date(22, 6))
    }

    @Test func exactlySixGoesToNextDay() {
        #expect(PauseUntil.nextMorning(after: date(22, 6), calendar: calendar) == date(23, 6))
    }
}

struct PaddedClockTests {
    @Test(arguments: [
        (15.0, "00:15"),
        (15.9, "00:15"),
        (252.0, "04:12"),
        (3725.0, "1:02:05"),
        (-1.0, "00:00"),
    ])
    func padded(interval: TimeInterval, expected: String) {
        #expect(Countdown.padded(interval) == expected)
    }

    @Test func elapsedAndRemainingAddUpToBreakLength() {
        var h = Harness()
        h.work(60)
        h.idleFor(15)
        let status = h.engine.snapshot(at: h.now + 0.4)
        #expect(Countdown.padded(status.breakElapsed ?? 0) == "00:15")
        #expect(Countdown.padded(status.remaining ?? 0, roundingUp: true) == "00:05")
    }
}
