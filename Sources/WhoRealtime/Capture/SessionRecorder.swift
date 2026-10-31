import Foundation
import Voz

/// Runs the recording: drains the mixdown timeline, writes the WAV file, and
/// feeds the live transcriber. `seal()` flushes the last samples synchronously
/// and closes the file.
nonisolated final class SessionRecorder: @unchecked Sendable {
    // @unchecked: `mixdown` is Mutex-guarded; writer and writeHead move only
    // between the drain task and synchronous seal(), never concurrently.
    let mixdown: Mixdown
    let wavURL: URL

    private let live: LiveTranscriber
    private let writer: WavWriter
    private var writeHead: Double = 0
    private var drainTask: Task<Void, Never>?

    init(wavURL: URL, outputRate: Double, live: LiveTranscriber) throws {
        self.wavURL = wavURL
        mixdown = Mixdown(outputRate: outputRate)
        writer = try WavWriter(url: wavURL, sampleRate: outputRate)
        self.live = live
    }

    func start() {
        drainTask = Task { await runDrain() }
    }

    @concurrent
    private func runDrain() async {
        while !Task.isCancelled {
            let chunks = mixdown.take()
            if !chunks.isEmpty {
                let (head, pieces) = mixdown.mix(chunks, writeHead: writeHead)
                for (_, samples) in pieces where !samples.isEmpty {
                    writer.append(samples)
                    await live.append(samples, sampleRate: mixdown.outputRate)
                }
                writeHead = max(writeHead, head)
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    /// Stop capturing, flush the queue, and close the file.
    func seal() {
        let chunks = mixdown.take()
        let (head, pieces) = mixdown.mix(chunks, writeHead: writeHead)
        for (_, samples) in pieces where !samples.isEmpty {
            writer.append(samples)
        }
        writeHead = max(writeHead, head)
        writer.close()
        drainTask?.cancel()
    }
}
