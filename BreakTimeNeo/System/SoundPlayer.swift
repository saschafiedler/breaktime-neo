import AppKit

/// Plays the sounds that come with macOS. The app ships no sounds of its own.
enum SoundPlayer {
    /// Plays a system sound by name; an empty name plays nothing.
    static func play(_ name: String) {
        guard !name.isEmpty, let sound = NSSound(named: name) else { return }
        sound.stop()
        sound.play()
    }
}
