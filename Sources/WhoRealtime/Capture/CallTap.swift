import CoreAudio
import Foundation
import WhoTapCore

/// Call audio capture via a CoreAudio process tap that mirrors the chosen
/// meeting app's output, mixed down to mono. The system shows its own consent
/// prompt the first time an app taps other processes' audio.
nonisolated final class CallTap: @unchecked Sendable {
    private var tapID: AudioObjectID = kAudioObjectUnknown
    private var aggregateID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private var installed = false

    /// The tap's mixdown rate, known right after the tap is created.
    private(set) var sampleRate: Double = 48_000

    init(processObjectIDs: [NSNumber], name: String) throws {
        var error: NSError?
        tapID = WhoTapCreateMonoProcessTap(processObjectIDs, name, &error)
        guard tapID != kAudioObjectUnknown, error == nil else {
            throw error ?? AudioError(status: -1, action: "creating the process tap")
        }
        if let (format, count) = Self.itemProperty(tapID, kAudioTapPropertyDescription), count > 0 {
            let rate = format.pointee.mSampleRate
            if rate > 0 { sampleRate = rate }
        }
    }

    /// Builds the aggregate device that carries the tap and starts its IOProc.
    /// `sink` runs on the HAL IO thread; keep it allocation-free.
    func install(sessionStart: Double, sink: @escaping @Sendable (AudioChunk) -> Void) throws {
        guard !installed, tapID != kAudioObjectUnknown else { return }
        installed = true

        guard let tapUID = Self.stringProperty(tapID, kAudioTapPropertyUID) else {
            throw AudioError(status: -1, action: "reading the tap UID")
        }
        // A tap belongs in the tap list. Listed as a subdevice instead, the
        // aggregate has no clock and AudioDeviceStart fails with 'nope'
        // (kAudioHardwareIllegalOperationError).
        let aggregateDict: [String: Any] = [
            "name": "Who Realtime call tap",
            "uid": "com.whorealtime.tap.\(UUID().uuidString)",
            "private": true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tapUID,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        var status = AudioHardwareCreateAggregateDevice(aggregateDict as CFDictionary, &aggregateID)
        guard status == noErr else { throw AudioError(status: status, action: "creating the tap aggregate device") }

        let rate = sampleRate
        let block: AudioDeviceIOBlock = { [sink] _, inputData, inputTime, _, _ in
            guard inputData.pointee.mNumberBuffers > 0 else { return }
            // A C `[1]` array imports as the element type: mBuffers IS the first buffer.
            let buffer = inputData.pointee.mBuffers
            // Mono mixdown: one buffer, one channel.
            guard let data = buffer.mData, buffer.mNumberChannels <= 1 else { return }
            let frames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
            guard frames > 0 else { return }
            let samples = [Float](UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: frames))
            let hostTime = inputTime.pointee.mHostTime
            let offset = hostTime > 0
                ? HostClock.seconds(fromTicks: hostTime) - sessionStart
                : HostClock.seconds() - sessionStart
            sink(AudioChunk(offset: offset, rate: rate, samples: samples))
        }
        var ioProc: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregateID, nil, block)
        guard status == noErr, ioProc != nil else { throw AudioError(status: status, action: "registering the tap IOProc") }
        ioProcID = ioProc
        status = AudioDeviceStart(aggregateID, ioProc)
        guard status == noErr else { throw AudioError(status: status, action: "starting the tap") }
    }

    func stop() {
        guard installed else { return }
        installed = false
        if let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyProcessTap(tapID)
            tapID = kAudioObjectUnknown
        }
    }

    deinit { stop() }

    private struct AudioError: LocalizedError {
        let status: OSStatus
        let action: String
        var errorDescription: String? { "\(action) failed (OSStatus \(status))." }
    }

    // MARK: - Property plumbing

    private static func stringProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString? = nil
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let string = value else { return nil }
        return string as String
    }

    private static func itemProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector)
        -> (UnsafeMutablePointer<AudioStreamBasicDescription>, Int)? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return nil }
        let count = Int(size) / MemoryLayout<AudioStreamBasicDescription>.size
        let pointer = UnsafeMutablePointer<AudioStreamBasicDescription>.allocate(capacity: count)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else {
            pointer.deallocate()
            return nil
        }
        return (pointer, count)
    }
}
