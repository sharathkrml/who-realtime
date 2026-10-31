import Foundation
import Synchronization

/// Peak level accumulator fed on an audio callback thread and drained by the
/// UI tick (~20 Hz). `record` allocates nothing and takes one short lock per
/// source, so it is safe to sit in front of the mixdown push on the IO thread.
nonisolated final class LevelMeter: @unchecked Sendable {   // @unchecked: two Mutex fields
    private let peak = Mutex<Float>(0)
    private let seen = Mutex<Bool>(false)

    /// Audio callback thread. One pass over the buffer, no allocation.
    func record(_ samples: [Float]) {
        var loudest: Float = 0
        for sample in samples {
            let magnitude = sample.magnitude
            if magnitude > loudest { loudest = magnitude }
        }
        peak.withLock { if loudest > $0 { $0 = loudest } }
        seen.withLock { $0 = true }
    }

    /// `peak` is the maximum absolute sample since the last drain; `hasSignal`
    /// stays raised once any chunk arrived — that is how the UI can tell a
    /// pending permission prompt from a silent source.
    func drain() -> (peak: Double, hasSignal: Bool) {
        let windowPeak = peak.withLock { value -> Float in
            let old = value
            value = 0
            return old
        }
        return (min(1, Double(windowPeak)), seen.withLock { $0 })
    }

    /// Display curve: instant rise, per-tick decay (~130 ms half-life at the
    /// 20 Hz tick). Pure so the meter math can be tested without audio.
    static func display(previous: Double, peak: Double) -> Double {
        max(peak, previous * 0.86)
    }
}
