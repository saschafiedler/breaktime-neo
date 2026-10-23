import Foundation
import Testing
@testable import BreakTimeNeoCore

@Suite("Rhythm: working, warning, break")
struct RhythmTests {
    @Test func startsWithFullWorkInterval() {
        let h = Harness()
        #expect(h.phase == .working(nextBreak: t0 + 60))
        #expect(h.engine.nextBreak == t0 + 60)
    }

    @Test func warnsOnceTenSecondsBeforeBreak() {
        var h = Harness()
        h.work(49)
        #expect(h.phase == .working(nextBreak: t0 + 60))
        h.work(1)
        #expect(h.phase == .warning(nextBreak: t0 + 60))
        h.work(5)
        #expect(h.outputs == [.warningStarted(breakAt: t0 + 60)])
    }

    @Test func breakStartsOnTimeAndEndsAfterItsDuration() {
        var h = Harness()
        h.work(60)
        #expect(h.phase == .onBreak(started: t0 + 60, ends: t0 + 80))
        #expect(h.engine.breakEnds == t0 + 80)
        h.idleFor(20)
        #expect(h.phase == .working(nextBreak: t0 + 140))
        #expect(h.outputs == [
            .warningStarted(breakAt: t0 + 60),
            .breakStarted(ends: t0 + 80),
            .breakEnded(.completed),
        ])
    }

    @Test func noWarningWhenTurnedOff() {
        var h = Harness(.test.with { $0.warningLead = 0 })
        h.work(60)
        #expect(h.outputs == [.breakStarted(ends: t0 + 80)])
    }

    @Test func idleDuringBreakIsIgnored() {
        var h = Harness(.test.with { $0.breakDuration = 100 })
        h.work(60)
        h.idleFor(99)
        #expect(h.phase == .onBreak(started: t0 + 60, ends: t0 + 160))
    }

    @Test func staysAwayAfterBreakWhenUserDoesNotReturn() {
        var h = Harness()
        h.work(60)
        h.idleFor(40)
        #expect(h.phase == .away(since: t0 + 60, resume: .work(nextBreak: t0 + 140), locked: false))
        h.work(1)
        #expect(h.phase == .working(nextBreak: t0 + 161))
    }
}

@Suite("Away: idle, lock and sleep")
struct AwayTests {
    @Test func longIdleCountsAsBreakAndRestartsOnReturn() {
        var h = Harness()
        h.work(20)
        h.idleFor(30)
        #expect(h.phase == .away(since: t0 + 20, resume: .work(nextBreak: t0 + 60), locked: false))
        h.idleFor(15)  // the scheduled break passes while away
        h.work(1)
        #expect(h.phase == .working(nextBreak: t0 + 66 + 60))
        #expect(h.outputs.isEmpty)
    }

    @Test func shortIdleKeepsSchedule() {
        var h = Harness()
        h.work(10)
        h.idleFor(25)
        h.work(5)
        #expect(h.phase == .working(nextBreak: t0 + 60))
    }

    @Test func ticksWhileLockedDoNotEndAbsence() {
        var h = Harness()
        h.work(20)
        h.send(.sleep(idle: 0))
        h.idleFor(15)
        #expect(h.phase == .away(since: t0 + 20, resume: .work(nextBreak: t0 + 60), locked: true))
    }

    @Test func shortLockKeepsSchedule() {
        var h = Harness()
        h.work(20)
        h.send(.sleep(idle: 0))
        h.idleFor(15)
        h.send(.wake)
        h.work(1)
        #expect(h.phase == .working(nextBreak: t0 + 60))
    }

    @Test func returningRightBeforeBreakShowsWarningFirst() {
        var h = Harness()
        h.work(55)
        h.send(.sleep(idle: 0))
        h.sleepFor(3)
        h.send(.wake)
        h.work(1)
        #expect(h.phase == .warning(nextBreak: t0 + 69))
        #expect(h.outputs.last == .warningStarted(breakAt: t0 + 69))
    }

    @Test func sleepUsesIdleTimeBeforeIt() {
        var h = Harness()
        h.work(10)
        h.idleFor(20)
        h.send(.sleep(idle: h.idle))
        #expect(h.phase == .away(since: t0 + 10, resume: .work(nextBreak: t0 + 60), locked: true))
    }

    @Test func longSleepCountsAsBreak() {
        var h = Harness()
        h.work(20)
        h.send(.sleep(idle: 0))
        h.sleepFor(3600)
        h.send(.wake)
        h.work(1)
        #expect(h.phase == .working(nextBreak: t0 + 3621 + 60))
        #expect(h.outputs.isEmpty)
    }

    @Test func wakeWithoutInputIsNoReturn() {
        var h = Harness()
        h.work(20)
        h.send(.sleep(idle: 0))
        h.sleepFor(600)
        h.send(.wake)
        h.idleFor(5)
        #expect(h.phase == .away(since: t0 + 20, resume: .work(nextBreak: t0 + 60), locked: false))
    }

    @Test func longLockDuringBreakCompletesIt() {
        var h = Harness(.test.with { $0.breakDuration = 60 })
        h.work(60)
        h.idleFor(5)
        h.send(.sleep(idle: h.idle))
        #expect(h.engine.breakEnds == t0 + 120)
        h.sleepFor(40)
        h.send(.wake)
        h.work(1)
        #expect(h.phase == .working(nextBreak: t0 + 106 + 60))
        #expect(h.outputs.last == .breakEnded(.completed))
    }

    @Test func shortLockDuringBreakResumesIt() {
        var h = Harness()
        h.work(60)
        h.send(.sleep(idle: 0))
        h.sleepFor(5)
        h.send(.wake)
        h.work(1)
        #expect(h.phase == .onBreak(started: t0 + 60, ends: t0 + 80))
        #expect(h.outputs.last == .breakStarted(ends: t0 + 80))
    }

    @Test func breakThatEndedDuringShortLockIsCompleted() {
        var h = Harness()
        h.work(75)
        h.send(.sleep(idle: 0))
        h.sleepFor(10)
        h.send(.wake)
        h.work(1)
        #expect(h.phase == .working(nextBreak: t0 + 86 + 60))
        #expect(h.outputs.last == .breakEnded(.completed))
    }
}

@Suite("User actions")
struct ActionTests {
    @Test func skipUpcomingBreakRestartsWorkInterval() {
        var h = Harness()
        h.work(30)
        h.send(.skip)
        #expect(h.phase == .working(nextBreak: t0 + 90))
        #expect(h.outputs.isEmpty)
    }

    @Test func skipRunningBreak() {
        var h = Harness()
        h.work(65)
        h.send(.skip)
        #expect(h.phase == .working(nextBreak: t0 + 125))
        #expect(h.outputs.last == .breakEnded(.skipped))
    }

    @Test func postponeAddsDelayToUpcomingBreak() {
        var h = Harness()
        h.work(30)
        h.send(.postpone(300))
        #expect(h.phase == .working(nextBreak: t0 + 360))
    }

    @Test func postponeDuringWarningLeavesWarning() {
        var h = Harness()
        h.work(55)
        h.send(.postpone(300))
        #expect(h.phase == .working(nextBreak: t0 + 360))
        h.work(300)
        #expect(h.phase == .warning(nextBreak: t0 + 360))
        #expect(h.outputs.last == .warningStarted(breakAt: t0 + 360))
    }

    @Test func postponeRunningBreak() {
        var h = Harness()
        h.work(62)
        h.send(.postpone(600))
        #expect(h.phase == .working(nextBreak: t0 + 662))
        #expect(h.outputs.last == .breakEnded(.postponed))
    }

    @Test func startBreakNow() {
        var h = Harness()
        h.work(5)
        h.send(.startBreak)
        #expect(h.phase == .onBreak(started: t0 + 5, ends: t0 + 25))
        h.send(.startBreak)
        #expect(h.outputs == [.breakStarted(ends: t0 + 25)])
    }

    @Test func pauseUntilDateThenResumeAutomatically() {
        var h = Harness()
        h.work(5)
        h.send(.pause(until: t0 + 100))
        h.work(94)
        #expect(h.phase == .paused(until: t0 + 100))
        h.work(1)
        #expect(h.phase == .working(nextBreak: t0 + 160))
        #expect(h.outputs.isEmpty)
    }

    @Test func pauseIndefinitelyUntilResumed() {
        var h = Harness()
        h.send(.pause(until: nil))
        h.work(1000)
        h.send(.sleep(idle: 0))
        h.sleepFor(100)
        h.send(.wake)
        h.idleFor(100)
        #expect(h.phase == .paused(until: nil))
        h.send(.resume)
        #expect(h.phase == .working(nextBreak: t0 + 1200 + 60))
    }

    @Test func pauseDuringBreakEndsIt() {
        var h = Harness()
        h.work(60)
        h.send(.pause(until: nil))
        #expect(h.outputs.last == .breakEnded(.paused))
    }

    @Test func startBreakWhilePaused() {
        var h = Harness()
        h.send(.pause(until: nil))
        h.send(.startBreak)
        #expect(h.phase == .onBreak(started: t0, ends: t0 + 20))
    }

    @Test func actionsWhileAwayAreIgnored() {
        var h = Harness()
        h.work(10)
        h.send(.sleep(idle: 0))
        let before = h.phase
        h.send(.skip)
        h.send(.postpone(300))
        h.send(.resume)
        #expect(h.phase == before)
    }
}

@Suite("Settings")
struct SettingsTests {
    @Test func changingWorkIntervalRestartsCountdown() {
        var h = Harness()
        h.work(30)
        h.send(.updateSettings(.test.with { $0.workInterval = 120 }))
        #expect(h.phase == .working(nextBreak: t0 + 150))
    }

    @Test func changingOtherValuesKeepsCountdown() {
        var h = Harness()
        h.work(30)
        h.send(.updateSettings(.test.with { $0.warningLead = 5; $0.awayThreshold = 60 }))
        #expect(h.phase == .working(nextBreak: t0 + 60))
    }

    @Test func changingBreakDurationMovesEndOfRunningBreak() {
        var h = Harness()
        h.work(60)
        h.send(.updateSettings(.test.with { $0.breakDuration = 40 }))
        #expect(h.phase == .onBreak(started: t0 + 60, ends: t0 + 100))
    }

    @Test func valuesAreClampedToUsableRanges() {
        let engine = BreakEngine(
            settings: BreakSettings(workInterval: 0, breakDuration: -1, warningLead: 100, awayThreshold: 0),
            now: t0
        )
        #expect(engine.settings == BreakSettings(workInterval: 10, breakDuration: 5, warningLead: 5, awayThreshold: 10))
    }
}

@Suite("Slider and idle detection")
struct ScheduleTests {
    @Test func sliderSetsTimeUntilBreak() {
        var h = Harness()
        h.work(10)
        h.send(.scheduleBreak(in: 45))
        #expect(h.phase == .working(nextBreak: t0 + 55))
    }

    @Test func sliderAtZeroStartsBreak() {
        var h = Harness()
        h.work(10)
        h.send(.scheduleBreak(in: 0))
        #expect(h.phase == .onBreak(started: t0 + 10, ends: t0 + 30))
        #expect(h.outputs == [.breakStarted(ends: t0 + 30)])
    }

    @Test func sliderInsideWarningTimeWarns() {
        var h = Harness()
        h.work(10)
        h.send(.scheduleBreak(in: 5))
        #expect(h.phase == .warning(nextBreak: t0 + 15))
        #expect(h.outputs == [.warningStarted(breakAt: t0 + 15)])
    }

    @Test func sliderLeavesWarningWhenMovedOut() {
        var h = Harness()
        h.work(52)
        h.send(.scheduleBreak(in: 300))
        #expect(h.phase == .working(nextBreak: t0 + 352))
    }

    @Test func sliderIsIgnoredWhilePausedOrOnBreak() {
        var h = Harness()
        h.send(.pause(until: nil))
        h.send(.scheduleBreak(in: 30))
        #expect(h.phase == .paused(until: nil))
        h.send(.resume)
        h.send(.startBreak)
        let onBreak = h.phase
        h.send(.scheduleBreak(in: 30))
        #expect(h.phase == onBreak)
    }

    @Test func idleIsIgnoredWhenDetectionIsOff() {
        var h = Harness(.test.with { $0.detectsIdle = false })
        h.work(10)
        h.idleFor(45)
        #expect(h.phase == .warning(nextBreak: t0 + 60))
    }

    @Test func lockStillCountsWhenIdleDetectionIsOff() {
        var h = Harness(.test.with { $0.detectsIdle = false })
        h.work(10)
        h.send(.sleep(idle: 0))
        h.sleepFor(600)
        h.send(.wake)
        h.work(1)
        #expect(h.phase == .working(nextBreak: t0 + 611 + 60))
    }
}

@Suite("Exact timing")
struct BoundaryTests {
    @Test func workingWaitsForWarningThenBreak() {
        var h = Harness()
        #expect(h.engine.nextBoundary(after: h.now) == t0 + 50)
        h.work(50)
        #expect(h.engine.nextBoundary(after: h.now) == t0 + 60)
    }

    @Test func breakEndsOnTime() {
        var h = Harness()
        h.work(60)
        #expect(h.engine.nextBoundary(after: h.now) == t0 + 80)
    }

    @Test func noWarningMeansBreakIsNext() {
        let h = Harness(.test.with { $0.warningLead = 0 })
        #expect(h.engine.nextBoundary(after: h.now) == t0 + 60)
    }

    @Test func timedPauseEndsOnTimeAndOpenPauseNever() {
        var h = Harness()
        h.send(.pause(until: t0 + 300))
        #expect(h.engine.nextBoundary(after: h.now) == t0 + 300)
        h.send(.pause(until: nil))
        #expect(h.engine.nextBoundary(after: h.now) == nil)
    }

    @Test func tickingAtTheBoundaryStartsTheBreakExactly() {
        var engine = BreakEngine(settings: .test, now: t0)
        var now = t0
        while let boundary = engine.nextBoundary(after: now), boundary <= t0 + 60 {
            now = boundary
            engine.send(.tick(idle: 0), at: now)
        }
        #expect(engine.phase == .onBreak(started: t0 + 60, ends: t0 + 80))
    }
}
