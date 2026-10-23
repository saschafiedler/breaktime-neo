import Foundation
@testable import BreakTimeNeoCore

let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

extension BreakSettings {
    /// Short values so tests can tick through whole cycles second by second.
    static let test = BreakSettings(workInterval: 60, breakDuration: 20, warningLead: 10, awayThreshold: 30)

    func with(_ change: (inout BreakSettings) -> Void) -> BreakSettings {
        var copy = self
        change(&copy)
        return copy
    }
}

/// Drives the engine the way the app does: one tick per second, with the
/// idle time derived from the last simulated input.
struct Harness {
    private(set) var engine: BreakEngine
    private(set) var now = t0
    private(set) var lastInput = t0
    private(set) var outputs: [BreakOutput] = []

    init(_ settings: BreakSettings = .test) {
        engine = BreakEngine(settings: settings, now: t0)
    }

    var phase: BreakPhase { engine.phase }
    var idle: TimeInterval { now.timeIntervalSince(lastInput) }

    /// The user keeps using the Mac for `seconds`.
    mutating func work(_ seconds: Int) {
        for _ in 0..<seconds {
            now += 1
            lastInput = now
            send(.tick(idle: idle))
        }
    }

    /// No input for `seconds`, while the app keeps ticking.
    mutating func idleFor(_ seconds: Int) {
        for _ in 0..<seconds {
            now += 1
            send(.tick(idle: idle))
        }
    }

    /// Time passes without any tick, like a Mac asleep.
    mutating func sleepFor(_ seconds: Int) {
        now += TimeInterval(seconds)
    }

    mutating func send(_ input: BreakInput) {
        outputs += engine.send(input, at: now)
    }
}
