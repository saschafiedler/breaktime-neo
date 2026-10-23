import AppKit
import BreakTimeNeoCore
import Observation

/// Runs the break rhythm: feeds the engine with a one-second heartbeat that
/// lands exactly on every change (warning, break start, break end) and with
/// system events, and turns its outputs into the break screen and sounds.
/// Views only read from it and call its actions.
@Observable
final class BreakController {
    let settings: AppSettings
    private(set) var engine: BreakEngine
    /// Time of the last update; views derive countdowns from it.
    private(set) var now: Date

    /// Called after every change of state or time, e.g. to redraw the
    /// status item, which is AppKit and does not observe on its own.
    @ObservationIgnored var onUpdate: (() -> Void)?
    @ObservationIgnored private let activity = ActivityMonitor()
    @ObservationIgnored private let overlay = OverlayController()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var appNapBlocker: NSObjectProtocol?

    init(settings: AppSettings, now: Date = .now) {
        self.settings = settings
        self.now = now
        engine = BreakEngine(settings: settings.breakSettings, now: now)
    }

    var status: StatusSnapshot { engine.snapshot(at: now) }

    /// The on/off switch: off suspends reminders until switched on again.
    var isEnabled: Bool {
        if case .paused = engine.phase { return false }
        return true
    }

    func start() {
        settings.onChange = { [weak self] in
            guard let self else { return }
            send(.updateSettings(settings.breakSettings))
        }
        activity.onChange = { [weak self] change in
            guard let self else { return }
            switch change {
            case .left:
                send(.sleep(idle: effectiveIdleSeconds))
            case .returned:
                send(.wake)
                tick()
            }
        }
        activity.start()

        // Without this, macOS may throttle the timer of a background app
        // (App Nap) and the break would start late. Idle sleep stays allowed.
        appNapBlocker = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Break timer"
        )
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Small tolerance: the heartbeat is what starts a break on time.
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        scheduleNextTick()
    }

    // MARK: - Actions

    func startBreak() { send(.startBreak) }
    func skip() { send(.skip) }
    func postpone(minutes: Int) { send(.postpone(TimeInterval(minutes * 60))) }
    func pause(until date: Date?) { send(.pause(until: date)) }
    func resume() { send(.resume) }
    func scheduleBreak(inSeconds seconds: Int) { send(.scheduleBreak(in: TimeInterval(seconds))) }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            resume()
        } else {
            pause(until: nil)
        }
    }

    // MARK: - Engine

    private func tick() {
        send(.tick(idle: effectiveIdleSeconds))
    }

    /// Seconds without input, except while a video plays: then the user is
    /// watching, not away (see S18 in docs/DECISIONS.md).
    private var effectiveIdleSeconds: TimeInterval {
        let idle = activity.idleSeconds
        // Only ask macOS once idle time could matter at all.
        if idle > 10, settings.videoCountsAsPresence, activity.isDisplayKeptAwake {
            return 0
        }
        return idle
    }

    private func send(_ input: BreakInput) {
        now = .now
        for output in engine.send(input, at: now) {
            handle(output)
        }
        onUpdate?()
        if case .warning = engine.phase {} else if !overlay.isShowing {
            overlay.discardPrepared()
        }
        scheduleNextTick()
    }

    /// The next tick comes a second from now, or earlier if the phase changes
    /// before that. Ticking right at that moment starts a break without
    /// delay, and the following ticks fall on whole seconds of it, so the
    /// break window counts in step with the break.
    private func scheduleNextTick() {
        guard let timer else { return }
        var next = now + 1
        if let boundary = engine.nextBoundary(after: now), boundary < next {
            next = boundary
        }
        timer.fireDate = next
    }

    #if DEBUG
    /// For snapshots: changes state without any side effect.
    func setEngineState(_ input: BreakInput, at date: Date) {
        now = date
        engine.send(input, at: date)
    }
    #endif

    private func handle(_ output: BreakOutput) {
        switch output {
        case .warningStarted:
            // The status item opens the popover on its own. Build the break
            // windows now, so they only need to be shown when the break starts.
            overlay.prepare(controller: self)
        case .breakStarted:
            overlay.show(controller: self)
            if settings.playSounds {
                SoundPlayer.play(AppSettings.breakStartSound)
            }
        case .breakEnded(let reason):
            overlay.hide()
            if reason == .completed, settings.playSounds {
                SoundPlayer.play(AppSettings.breakEndSound)
            }
        }
    }
}
