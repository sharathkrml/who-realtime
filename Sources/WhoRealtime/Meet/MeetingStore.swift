import Foundation
import Observation

/// The library behind the windowed app's sidebar: whatever is in
/// `~/Documents/Meetings` right now. The menu bar app writes docs there, so
/// this is the one list both flavors share.
@Observable
public final class MeetingStore {
    public private(set) var meetings: [ParsedDoc] = []

    public init() {}

    public func reload() {
        // shortcut: reads every doc whole on each call — fine for a few hundred
        // meetings; swap for cached headers if a library ever gets huge.
        let files = (try? FileManager.default.contentsOfDirectory(
            at: MeetingDoc.directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])) ?? []
        meetings = files
            .filter { $0.pathExtension == "md" }
            .compactMap(MeetingDoc.parse(url:))
            .sorted { $0.date > $1.date }
    }

    /// Doc and its recording go to the Trash together — nothing is unlinked,
    /// so a misclick is undoable in Finder.
    public func delete(_ doc: ParsedDoc) {
        let fm = FileManager.default
        try? fm.trashItem(at: doc.url, resultingItemURL: nil)
        try? fm.trashItem(at: doc.url.deletingPathExtension().appendingPathExtension("wav"),
                          resultingItemURL: nil)
        reload()
    }
}
