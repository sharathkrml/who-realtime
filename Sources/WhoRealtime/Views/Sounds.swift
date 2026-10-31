import AppKit

/// Quiet chimes + trackpad haptic taps. Uses the system's own short tones so
/// the app ships no audio assets and stays quiet by default (low volume).
enum Sounds {
    private static var keepAlive: [NSSound] = []

    static func started() { play("Pop", volume: 0.30) }
    static func saved()   { play("Glass", volume: 0.30) }
    static func failed()  { play("Basso", volume: 0.22) }

    private static func play(_ name: String, volume: Double) {
        guard let sound = NSSound(named: name) else { return }
        sound.volume = Float(volume)
        // NSSound is deallocated mid-play if nothing retains it.
        keepAlive.append(sound)
        if keepAlive.count > 8 { keepAlive.removeFirst(keepAlive.count - 4) }
        sound.play()
    }

    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}
