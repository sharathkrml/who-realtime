import AVFoundation
import Foundation
import WhoTapCore

/// Microphone capture through AVAudioEngine's input tap. Delivers mono chunks
/// timestamped on the session clock. The tap handler only copies floats into
/// the mixdown's Mutex — no allocation beyond that single array.
nonisolated final class MicTap: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var installed = false

    /// Input sample rate, known before the tap is installed.
    var sampleRate: Double {
        engine.inputNode.outputFormat(forBus: 0).sampleRate
    }

    /// Installs the input tap and starts the engine.
    /// `sink` runs on the render thread; keep it allocation-free.
    func install(sessionStart: Double, sink: @escaping @Sendable (AudioChunk) -> Void) throws {
        guard !installed else { return }
        installed = true
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let anchor = HostClock.seconds() - sessionStart
        var samplesSoFar: UInt64 = 0
        let rate = format.sampleRate

        input.installTap(onBus: 0, bufferSize: 4800, format: format) { [sink] buffer, _ in
            guard let channel = buffer.floatChannelData else { return }
            let count = Int(buffer.frameLength)
            var mono = [Float](repeating: 0, count: count)
            let channels = max(1, Int(buffer.format.channelCount))
            mono.withUnsafeMutableBufferPointer { output in
                for frame in 0..<count {
                    var sum: Float = 0
                    for channelIndex in 0..<channels {
                        sum += channel[channelIndex][frame]
                    }
                    output[frame] = sum / Float(channels)
                }
            }
            let offset = anchor + Double(samplesSoFar) / rate
            samplesSoFar += UInt64(count)
            sink(AudioChunk(offset: offset, rate: rate, samples: mono))
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
