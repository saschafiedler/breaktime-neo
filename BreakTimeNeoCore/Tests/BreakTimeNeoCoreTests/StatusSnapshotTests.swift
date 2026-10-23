import Foundation
import Testing
@testable import BreakTimeNeoCore

struct StatusSnapshotTests {
    @Test func workingShowsMinutes() {
        var h = Harness(.test.with { $0.workInterval = 600 })
        h.work(5)
        let status = h.engine.snapshot(at: h.now)
        #expect(status.kind == .working)
        #expect(status.menuBarText == "10 min")
    }

    @Test func warningShowsSeconds() {
        var h = Harness()
        h.work(51)
        let status = h.engine.snapshot(at: h.now)
        #expect(status.kind == .warning)
        #expect(status.menuBarText == "0:09")
    }

    @Test func breakShowsRemainingTimeAndProgress() {
        var h = Harness()
        h.work(65)
        let status = h.engine.snapshot(at: h.now)
        #expect(status.kind == .onBreak)
        #expect(status.menuBarText == "0:15")
        #expect(status.breakProgress == 0.25)
    }

    @Test func breakStaysVisibleWhileLocked() {
        var h = Harness()
        h.work(65)
        h.send(.sleep(idle: 0))
        #expect(h.engine.snapshot(at: h.now).kind == .onBreak)
    }

    @Test func awayAndPausedShowIconOnly() {
        var h = Harness()
        h.work(5)
        h.send(.sleep(idle: 0))
        #expect(h.engine.snapshot(at: h.now) == StatusSnapshot(kind: .away))
        h.send(.wake)
        h.work(1)
        h.send(.pause(until: t0 + 3600))
        let paused = h.engine.snapshot(at: h.now)
        #expect(paused.menuBarText == nil)
        #expect(paused.pausedUntil == t0 + 3600)
    }
}

struct WorkProgressTests {
    @Test func fillsUpTowardsTheBreak() {
        var h = Harness()
        #expect(h.engine.snapshot(at: h.now).workProgress == 0)
        h.work(30)
        #expect(h.engine.snapshot(at: h.now).workProgress == 0.5)
        h.work(30)
        #expect(h.engine.snapshot(at: h.now).workProgress == 1)
    }

    @Test func emptyWhenPostponedBeyondOneInterval() {
        var h = Harness()
        h.work(30)
        h.send(.postpone(600))
        #expect(h.engine.snapshot(at: h.now).workProgress == 0)
    }

    @Test func noProgressWhilePaused() {
        var h = Harness()
        h.send(.pause(until: nil))
        #expect(h.engine.snapshot(at: h.now).workProgress == nil)
    }
}

struct HeadlineTests {
    @Test(arguments: [
        (15 * 60.0, 15, true),
        (14 * 60 + 1.0, 15, true),
        (60.0, 1, true),
        (59.0, 59, false),
        (0.0, 0, false),
    ])
    func headline(remaining: TimeInterval, value: Int, inMinutes: Bool) {
        let result = Countdown.headline(remaining)
        #expect(result.value == value)
        #expect(result.inMinutes == inMinutes)
    }
}
