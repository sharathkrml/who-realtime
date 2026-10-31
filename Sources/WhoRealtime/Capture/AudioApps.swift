import AppKit
import CoreAudio
import Foundation

/// One app producing audio output on this Mac, tappable in "On this Mac" mode.
struct AudioApp: Identifiable, Hashable, Sendable {
    /// All process objects that belong to this app (a browser renders in a
    /// helper process, so it can be several); tapped together as one source.
    let processObjectIDs: [AudioObjectID]
    let pid: pid_t
    let bundleID: String
    let name: String

    var id: String { bundleID }

    /// Live icon: resolve the host app via bundle id first, so a helper-only
    /// process still shows the real app icon.
    var icon: NSImage? {
        if let host = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            return host.icon
        }
        return NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }?.icon
    }

    /// Convenience for the tap plumbing (single app → all of its objects).
    var processObjectID: AudioObjectID { processObjectIDs[0] }
}

enum AudioApps {
    /// Every process with live audio output right now. CoreAudio reads the
    /// process list without any permission prompt; the tap itself asks.
    static func producingOutput() -> [AudioApp] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
              size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var objectIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objectIDs) == noErr else { return [] }

        var apps: [AudioApp] = []
        // Group all of one host's audio processes (a browser renders in a
        // helper process, so it can be several) into a single tappable app.
        struct Group {
            var pid: pid_t
            var objects: [AudioObjectID]
        }
        var groups: [String: Group] = [:]
        for id in objectIDs {
            guard boolProperty(id, kAudioProcessPropertyIsRunningOutput) else { continue }
            let pid = intProperty(id, kAudioProcessPropertyPID) ?? 0
            let bundle = stringProperty(id, kAudioProcessPropertyBundleID) ?? ""
            // Skip ourselves so our own (none) output can never be tapped.
            if pid == ProcessInfo.processInfo.processIdentifier { continue }
            // Helper processes belong to their host app: "com.brave.Browser.helper"
            // folds into "com.brave.Browser".
            let hostBundle = bundle.hasSuffix(".helper")
                ? String(bundle.dropLast(".helper".count))
                : bundle
            var group = groups[hostBundle] ?? Group(pid: 0, objects: [])
            if group.pid == 0, pid > 0 { group.pid = pid }
            group.objects.append(id)
            groups[hostBundle] = group
        }

        for (hostBundle, group) in groups {
            let hostApp = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == hostBundle }
            let name = hostApp?.localizedName
                ?? hostBundle.split(separator: ".").last.map(String.init)
                ?? "Unknown"
            let pid = hostApp?.processIdentifier ?? group.pid
            apps.append(AudioApp(
                processObjectIDs: group.objects.sorted(),
                pid: pid,
                bundleID: hostBundle,
                name: name))
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func boolProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Bool {
        var value: UInt32 = 0
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr && value != 0
    }

    private static func intProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> pid_t? {
        var value: Int32 = 0
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<Int32>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

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
}
