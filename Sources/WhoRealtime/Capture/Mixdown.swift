import Foundation
import Synchronization

/// Samples from one capture source, timestamped on the shared host clock.
struct AudioChunk: Sendable {
    /// Seconds into the session (relative to `sessionStart`).
    let offset: TimeInterval
    let rate: Double
    let samples: [Float]
}

/// Mixdown: merges two gapless-but-interleaved sources (call audio + mic) into
/// one mono timeline on a shared sample grid.
///
/// The audio callbacks of both sources deliver at slightly different cadences,
/// so chunks may arrive a few buffers late and overlap what's already written.
/// A late chunk's already-written prefix is dropped rather than remixed —
/// shortcut: a mid-callback stall longer than a buffer (~20 ms) shifts that
/// overlap slightly; upgrade if recordings ever audibly skew between sources.
/// All input must be in-order per source; offsets come from the host clock, so
/// sources started late sit at the right place on the timeline.
nonisolated final class Mixdown: @unchecked Sendable {   // @unchecked: pending is Mutex-guarded
    private let _pending = Mutex<[AudioChunk]>([])
    let outputRate: Double

    init(outputRate: Double) {
        self.outputRate = outputRate
    }

    /// Audio callback thread. Lock + append only.
    func push(_ chunk: AudioChunk) {
        _pending.withLock { $0.append(chunk) }
    }

    /// Drain task only for the rest of this class.
    func take() -> [AudioChunk] {
        _pending.withLock { chunks in
            let drained = chunks
            chunks.removeAll()
            return drained
        }
    }

    /// Mix the popped chunks into a gapless timeline.
    /// Returns (next write head in seconds, yield pairs of (offset, mono float block)).
    func mix(_ chunks: [AudioChunk], writeHead: Double) -> (head: Double, pieces: [(offset: Double, samples: [Float])]) {
        var pieces: [(Double, [Float])] = []
        var head = writeHead
        for chunk in chunks.sorted(by: { $0.offset < $1.offset }) {
            var samples = chunk.samples
            var offset = chunk.offset
            let rate = chunk.rate

            if rate != outputRate {
                samples = Self.resampleLinear(samples, from: rate, to: outputRate)
                // Length changes; the chunk's start stays put, its couple-ms
                // length error is invisible next to Who's 10 ms turns.
            }

            let end = offset + Double(samples.count) / outputRate
            guard end > head else { continue }             // entirely behind
            if offset < head {                             // late arrival: drop written prefix
                let drop = Int((head - offset) * outputRate)
                samples = Array(samples.dropFirst(drop))
                offset = head
            }
            if offset > head {                             // gap when neither source spoke
                pieces.append((head, [Float](repeating: 0,
                                             count: Int((offset - head) * outputRate))))
            }
            pieces.append((offset, samples))
            head = offset + Double(samples.count) / outputRate
        }
        return (head, pieces)
    }

    private static func resampleLinear(_ samples: [Float], from: Double, to: Double) -> [Float] {
        guard from > 0, to > 0, !samples.isEmpty else { return samples }
        let outputCount = Int(Double(samples.count) * to / from)
        guard outputCount > 0 else { return [] }
        var out = [Float](repeating: 0, count: outputCount)
        let step = from / to
        for i in 0..<outputCount {
            let source = Double(i) * step
            let index = Int(source)
            guard index + 1 < samples.count else {
                out[i] = samples[min(index, samples.count - 1)]
                continue
            }
            let fraction = source - Double(index)
            out[i] = samples[index] * (1 - Float(fraction)) + samples[index + 1] * Float(fraction)
        }
        return out
    }
}
