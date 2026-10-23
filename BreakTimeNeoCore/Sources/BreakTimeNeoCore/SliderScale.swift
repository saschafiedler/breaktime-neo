import Foundation

/// Maps a slider position 0…1 to a value along a power curve, so short
/// times get more room on the slider than long ones.
public struct PowerScale: Equatable, Sendable {
    public var lower: Double
    public var upper: Double
    public var exponent: Double

    public init(lower: Double, upper: Double, exponent: Double) {
        self.lower = lower
        self.upper = upper
        self.exponent = exponent
    }

    public func value(at position: Double) -> Double {
        lower + (upper - lower) * pow(min(max(position, 0), 1), exponent)
    }

    /// Inverse of `value(at:)`; values outside the range end up at 0 or 1.
    public func position(of value: Double) -> Double {
        guard upper > lower else { return 0 }
        let share = min(max((value - lower) / (upper - lower), 0), 1)
        return pow(share, 1 / exponent)
    }
}

/// Rounding of slider values to times people would pick.
public enum TimeSnap {
    /// Time until the next break: whole seconds below a minute, whole
    /// minutes above. Below half a second it is zero (break now).
    public static func secondsThenMinutes(_ seconds: Double) -> Int {
        if seconds < 59.5 {
            return Int(seconds.rounded())
        }
        return Int((seconds / 60).rounded()) * 60
    }

    /// Whole minutes, at least one.
    public static func minutes(_ seconds: Double) -> Int {
        max(Int((seconds / 60).rounded()), 1) * 60
    }

    /// Break length: whole seconds below a minute, whole minutes above.
    public static func breakLength(_ seconds: Double) -> Int {
        secondsThenMinutes(seconds)
    }
}

/// How a duration reads next to a slider: seconds below a minute, whole
/// minutes from one minute on.
public enum DurationDisplay {
    public static func parts(_ seconds: Int) -> (value: Int, inMinutes: Bool) {
        if seconds < 60 {
            return (seconds, false)
        }
        return (Int((Double(seconds) / 60).rounded()), true)
    }

    /// Seconds for a number typed into the field in the unit it shows.
    public static func seconds(fromField value: Int, inMinutes: Bool) -> Int {
        inMinutes ? value * 60 : value
    }
}
