import Foundation

/// Streaming 16-bit mono PCM WAV writer. The RIFF header declares real sizes
/// from the first append on, so Who can diarize the file while it is still
/// being written (that's what keeps the 2-minute live re-diarize cheap).
nonisolated final class WavWriter: @unchecked Sendable {   // @unchecked: written only from the drain task
    private let handle: FileHandle
    private let rate: Int
    private var frames: Int = 0
    private(set) var isClosed = false

    /// Bytes in the data chunk of the canonical 44-byte PCM header.
    private let dataSizeOffset: UInt64 = 40

    init(url: URL, sampleRate: Double) throws {
        rate = Int(sampleRate)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let handle = FileHandle(forWritingAtPath: url.path) else {
            throw CocoaError(.fileWriteUnknown)
        }
        self.handle = handle
        handle.write(Self.header(rate: rate, frames: 0))
    }

    func append(_ samples: [Float]) {
        guard !isClosed else { return }
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            var frame = Int16(clamped * 32767).littleEndian
            withUnsafeBytes(of: &frame) { data.append(contentsOf: $0) }
        }
        handle.write(data)
        frames += samples.count
        patch()
    }

    /// Rewrite the RIFF sizes so readers see the real length.
    func patch() {
        let header = Self.header(rate: rate, frames: frames)
        handle.seek(toFileOffset: 0)
        handle.write(header)
        handle.seek(toFileOffset: UInt64(frames) * 2 + 44)   // back to the tail
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        patch()
        try? handle.close()
    }

    var seconds: Double { Double(frames) / Double(rate) }

    private static func header(rate: Int, frames: Int) -> Data {
        var data = Data()
        let byteRate = rate * 2
        let blockAlign = 2

        func append32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }

        data.append("RIFF".data(using: .ascii)!)
        append32(UInt32(36 + frames * 2))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        append32(16)
        append16(1)                      // PCM
        append16(1)                      // mono
        append32(UInt32(rate))
        append32(UInt32(byteRate))
        append16(UInt16(blockAlign))
        append16(16)                     // bits
        data.append("data".data(using: .ascii)!)
        append32(UInt32(frames * 2))
        return data
    }
}
