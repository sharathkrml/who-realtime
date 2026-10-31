import Foundation

/// The meeting document: fenced Markdown with timestamped, named speakers.
enum MeetingDoc {
    /// `12:03`, or `1:02:03` once the meeting passes an hour.
    static func timestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600, minutes = total % 3600 / 60, secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func title(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy HH:mm"
        return "Meeting — " + formatter.string(from: date)
    }

    static func fileName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "Meeting " + formatter.string(from: date)
    }

    static func markdown(title: String, lines: [Line], names: [Int: String]) -> String {
        var out = "# \(title)\n\n"
        out += "_\(lines.count) attributed turns._\n\n"
        var lastSpeaker: Int?
        for line in lines {
            if line.speaker != lastSpeaker { out += "\n" }
            lastSpeaker = line.speaker
            let name = names[line.speaker] ?? (line.speaker >= 0 ? "Speaker \(line.speaker + 1)" : "Unattributed")
            out += "**[\(timestamp(line.start))] \(name):** \(line.text)\n\n"
        }
        if lines.isEmpty { out += "_No speech was detected._\n" }
        return out
    }

    static var directory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let meetings = home.appendingPathComponent("Documents/Meetings", isDirectory: true)
        try? FileManager.default.createDirectory(at: meetings, withIntermediateDirectories: true)
        return meetings
    }

    /// Writes the Markdown next to the recording and returns the doc URL.
    static func save(title: String, lines: [Line], names: [Int: String], wavURL: URL) throws -> URL {
        let docURL = directory.appendingPathComponent(fileName(for: Date()) + ".md")
        let content = markdown(title: title, lines: lines, names: names)
        try Data(content.utf8).write(to: docURL)
        // Keep the recording next to the doc, named identically.
        let audioDestination = directory.appendingPathComponent((docURL.deletingPathExtension().lastPathComponent) + ".wav")
        try? FileManager.default.removeItem(at: audioDestination)
        try? FileManager.default.moveItem(at: wavURL, to: audioDestination)
        return docURL
    }
}
