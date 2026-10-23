import Foundation

/// Where the user currently is in the work/break rhythm.
public enum BreakPhase: Equatable, Sendable {
    /// Working; the next break is due at `nextBreak`.
    case working(nextBreak: Date)
    /// The break starts soon; the menu bar shows the warning.
    case warning(nextBreak: Date)
    /// A break is running.
    case onBreak(started: Date, ends: Date)
    /// The user is away: idle, screen locked or Mac asleep. While `locked` is
    /// true the idle time is ignored; only `.wake` can end that.
    case away(since: Date, resume: Resumption, locked: Bool)
    /// Reminders are suspended until `until`, or until resumed when `nil`.
    case paused(until: Date?)
}

/// What was going on when the user left.
public enum Resumption: Equatable, Sendable {
    case work(nextBreak: Date)
    case rest(started: Date, ends: Date)
}

/// Everything that can happen to the engine. Time is never read inside the
/// engine; it always comes with the input, so tests can jump ahead freely.
public enum BreakInput: Equatable, Sendable {
    /// Regular heartbeat with the seconds since the last keyboard/mouse input.
    case tick(idle: TimeInterval)
    /// Screen locked, display or Mac asleep, user session switched away.
    case sleep(idle: TimeInterval)
    /// Counterpart of `.sleep`. The user only counts as back after the next
    /// tick reports recent input.
    case wake
    case startBreak
    /// Skips the upcoming break, or ends the running one.
    case skip
    /// Moves the upcoming break back, or ends the running one and schedules
    /// the next break after the delay.
    case postpone(TimeInterval)
    /// Sets the time until the upcoming break (the slider in the popover);
    /// zero or less starts the break right away.
    case scheduleBreak(in: TimeInterval)
    /// Suspends reminders until a date, or until `.resume` when `nil`.
    case pause(until: Date?)
    case resume
    case updateSettings(BreakSettings)
}

/// Things the app has to act on (overlay, sounds, notifications).
public enum BreakOutput: Equatable, Sendable {
    case warningStarted(breakAt: Date)
    case breakStarted(ends: Date)
    case breakEnded(BreakEnd)
}

public enum BreakEnd: Equatable, Sendable {
    case completed
    case skipped
    case postponed
    case paused
}

/// The state machine at the heart of the app:
/// working → warning → break → working, plus away and paused.
public struct BreakEngine: Equatable, Sendable {
    public private(set) var settings: BreakSettings
    public private(set) var phase: BreakPhase

    public init(settings: BreakSettings = .standard, now: Date) {
        let settings = settings.sanitized
        self.settings = settings
        self.phase = .working(nextBreak: now + settings.workInterval)
    }

    /// When the next break is due, if one is scheduled right now.
    public var nextBreak: Date? {
        switch phase {
        case .working(let next), .warning(let next): next
        default: nil
        }
    }

    /// When the running break ends. Also set while the user stepped away
    /// during a break, because the break screen stays up then.
    public var breakEnds: Date? {
        switch phase {
        case .onBreak(_, let ends), .away(_, .rest(_, let ends), _): ends
        default: nil
        }
    }

    /// The next moment the phase changes on its own: start of the warning,
    /// start or end of the break, end of a timed pause. The app ticks
    /// exactly then, so nothing starts up to a second late.
    public func nextBoundary(after now: Date) -> Date? {
        let candidates: [Date]
        switch phase {
        case .working(let next):
            candidates = [next - settings.warningLead, next]
        case .warning(let next):
            candidates = [next]
        case .onBreak(_, let ends):
            candidates = [ends]
        case .paused(let until):
            candidates = until.map { [$0] } ?? []
        case .away:
            candidates = []
        }
        return candidates.filter { $0 > now }.min()
    }

    @discardableResult
    public mutating func send(_ input: BreakInput, at now: Date) -> [BreakOutput] {
        switch input {
        case .tick(let idle):
            return tick(idle: idle, now: now)
        case .sleep(let idle):
            goToSleep(idle: idle, now: now)
            return []
        case .wake:
            if case .away(let since, let resume, true) = phase {
                phase = .away(since: since, resume: resume, locked: false)
            }
            return []
        case .startBreak:
            if case .onBreak = phase { return [] }
            return beginBreak(now: now)
        case .skip:
            return endUpcomingOrRunningBreak(nextBreak: now + settings.workInterval, reason: .skipped)
        case .postpone(let delay):
            if let next = nextBreak {
                phase = .working(nextBreak: max(next, now) + delay)
                return []
            }
            return endUpcomingOrRunningBreak(nextBreak: now + delay, reason: .postponed)
        case .scheduleBreak(let delay):
            guard nextBreak != nil else { return [] }
            if delay <= 0 {
                return beginBreak(now: now)
            }
            return advanceWork(nextBreak: now + delay, now: now)
        case .pause(let until):
            let breakWasShowing = breakEnds != nil
            phase = .paused(until: until)
            return breakWasShowing ? [.breakEnded(.paused)] : []
        case .resume:
            guard case .paused = phase else { return [] }
            phase = .working(nextBreak: now + settings.workInterval)
            return []
        case .updateSettings(let newSettings):
            apply(newSettings.sanitized, now: now)
            return []
        }
    }

    // MARK: - Transitions

    private mutating func tick(idle: TimeInterval, now: Date) -> [BreakOutput] {
        switch phase {
        case .working(let next), .warning(let next):
            if settings.detectsIdle, idle >= settings.awayThreshold {
                phase = .away(since: now - idle, resume: .work(nextBreak: next), locked: false)
                return []
            }
            return advanceWork(nextBreak: next, now: now)
        case .onBreak(_, let ends):
            // Idle time is expected during a break and is ignored.
            return now >= ends ? finishBreak(nextBreak: now + settings.workInterval, reason: .completed) : []
        case .away(let since, let resume, let locked):
            guard !locked, idle < settings.awayThreshold else { return [] }
            return comeBack(since: since, resume: resume, back: now - idle, now: now)
        case .paused(let until):
            if let until, now >= until {
                phase = .working(nextBreak: now + settings.workInterval)
            }
            return []
        }
    }

    private mutating func advanceWork(nextBreak next: Date, now: Date) -> [BreakOutput] {
        if now >= next {
            return beginBreak(now: now)
        }
        if settings.warningLead > 0, now >= next - settings.warningLead {
            if case .warning = phase { return [] }
            phase = .warning(nextBreak: next)
            return [.warningStarted(breakAt: next)]
        }
        phase = .working(nextBreak: next)
        return []
    }

    private mutating func beginBreak(now: Date) -> [BreakOutput] {
        let ends = now + settings.breakDuration
        phase = .onBreak(started: now, ends: ends)
        return [.breakStarted(ends: ends)]
    }

    private mutating func finishBreak(nextBreak next: Date, reason: BreakEnd) -> [BreakOutput] {
        phase = .working(nextBreak: next)
        return [.breakEnded(reason)]
    }

    private mutating func endUpcomingOrRunningBreak(nextBreak next: Date, reason: BreakEnd) -> [BreakOutput] {
        switch phase {
        case .working, .warning:
            phase = .working(nextBreak: next)
            return []
        case .onBreak:
            return finishBreak(nextBreak: next, reason: reason)
        case .away, .paused:
            return []
        }
    }

    private mutating func goToSleep(idle: TimeInterval, now: Date) {
        let since = now - max(idle, 0)
        switch phase {
        case .working(let next), .warning(let next):
            phase = .away(since: since, resume: .work(nextBreak: next), locked: true)
        case .onBreak(let started, let ends):
            phase = .away(since: since, resume: .rest(started: started, ends: ends), locked: true)
        case .away(let since, let resume, _):
            phase = .away(since: since, resume: resume, locked: true)
        case .paused:
            break
        }
    }

    /// The user is back at `back` (first input after the absence).
    private mutating func comeBack(since: Date, resume: Resumption, back: Date, now: Date) -> [BreakOutput] {
        let countsAsBreak = back.timeIntervalSince(since) >= settings.awayThreshold
        switch resume {
        case .work(let next):
            if countsAsBreak {
                phase = .working(nextBreak: back + settings.workInterval)
                return []
            }
            // Short absence: keep the schedule, but never start a break
            // without the warning when the user just sat down again.
            return advanceWork(nextBreak: max(next, now + settings.warningLead), now: now)
        case .rest(let started, let ends):
            if countsAsBreak || now >= ends {
                return finishBreak(nextBreak: back + settings.workInterval, reason: .completed)
            }
            phase = .onBreak(started: started, ends: ends)
            return []
        }
    }

    private mutating func apply(_ newSettings: BreakSettings, now: Date) {
        let old = settings
        settings = newSettings
        switch phase {
        case .working, .warning:
            if newSettings.workInterval != old.workInterval {
                phase = .working(nextBreak: now + newSettings.workInterval)
            }
        case .onBreak(let started, _):
            if newSettings.breakDuration != old.breakDuration {
                phase = .onBreak(started: started, ends: started + newSettings.breakDuration)
            }
        case .away, .paused:
            break
        }
    }
}
