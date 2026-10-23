import Foundation
import Testing
@testable import BreakTimeNeoCore

struct PowerScaleTests {
    /// The popover slider: 0 on the left, 20 minutes on the right.
    let popover = PowerScale(lower: 0, upper: 1200, exponent: 3)

    @Test func endsMatchTheRange() {
        #expect(popover.value(at: 0) == 0)
        #expect(popover.value(at: 1) == 1200)
        #expect(popover.value(at: -1) == 0)
        #expect(popover.value(at: 2) == 1200)
    }

    @Test func oneSecondSitsNearTheLeftEnd() {
        let position = popover.position(of: 1)
        #expect(position > 0.05 && position < 0.12)
    }

    @Test func firstMinuteGetsAboutAThirdOfTheSlider() {
        let position = popover.position(of: 60)
        #expect(position > 0.3 && position < 0.45)
    }

    @Test(arguments: [0.0, 0.1, 0.37, 0.5, 0.9, 1.0])
    func positionIsInverseOfValue(position: Double) {
        #expect(abs(popover.position(of: popover.value(at: position)) - position) < 1e-9)
    }

    @Test func valuesOutsideRangeStickToTheEnds() {
        #expect(popover.position(of: 5000) == 1)
        #expect(popover.position(of: -3) == 0)
    }
}

struct TimeSnapTests {
    @Test(arguments: [
        (0.3, 0),
        (0.6, 1),
        (42.4, 42),
        (59.4, 59),
        (59.6, 60),
        (89.0, 60),
        (91.0, 120),
        (1187.0, 1200),
    ])
    func secondsThenMinutes(seconds: Double, expected: Int) {
        #expect(TimeSnap.secondsThenMinutes(seconds) == expected)
    }

    @Test(arguments: [(20.4, 20), (59.4, 59), (59.6, 60), (62.0, 60), (95.0, 120), (298.0, 300), (412.0, 420)])
    func breakLength(seconds: Double, expected: Int) {
        #expect(TimeSnap.breakLength(seconds) == expected)
    }

    @Test func minutesNeverBelowOne() {
        #expect(TimeSnap.minutes(10) == 60)
        #expect(TimeSnap.minutes(1170) == 1200)
    }
}

struct DurationDisplayTests {
    @Test(arguments: [(20, 20, false), (59, 59, false), (60, 1, true), (300, 5, true)])
    func parts(seconds: Int, value: Int, inMinutes: Bool) {
        let parts = DurationDisplay.parts(seconds)
        #expect(parts.value == value)
        #expect(parts.inMinutes == inMinutes)
    }

    @Test func fieldValueUsesTheShownUnit() {
        #expect(DurationDisplay.seconds(fromField: 45, inMinutes: false) == 45)
        #expect(DurationDisplay.seconds(fromField: 3, inMinutes: true) == 180)
    }
}
