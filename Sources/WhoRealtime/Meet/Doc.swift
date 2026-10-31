import Foundation

/// A doc read back off disk: enough to list it in the library and render it
/// with the same rows as the live transcript. `raw` is kept so a hand-edited
/// file still shows something instead of an empty card.
public struct ParsedDoc: Identifiable, Hashable {
    public let url: URL
    public let title: String
    public let date: Date
    let lines: [Line]
    let names: [Int: String]
    let raw: String

    public var id: URL { url }

    /// Title without the "Meeting — " prefix the doc writes.
    var shortTitle: String {
        let prefix = "Meeting — "
        return title.hasPrefix(prefix) ? String(title.dropFirst(prefix.count)) : title
    }
}

/// The meeting document: fenced Markdown with timestamped, named speakers.
enum MeetingDoc {
    /// `**[00:05] Speaker 1:** text` — the one shape `markdown(title:lines:names:)`
    /// writes, and the only shape the reader has to understand.
    private static let transcriptLine = /\*\*\[([\d:]+)\] (.+?):\*\* (.*)/

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

    // MARK: - Reading a doc back

    static func parse(url: URL) -> ParsedDoc? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .now
        return parse(text: text, url: url, date: date)
    }

    static func parse(text: String, url: URL, date: Date = .now) -> ParsedDoc {
        var lines: [Line] = []
        var names: [Int: String] = [:]
        var index: [String: Int] = [:]

        for raw in text.split(separator: "\n") {
            guard let match = raw.wholeMatch(of: transcriptLine) else { continue }
            let name = String(match.2)
            let speaker: Int
            if name == "Unattributed" {
                speaker = -1
            } else if let known = index[name] {
                speaker = known
            } else {
                // Colors key off the index, so number speakers by first
                // appearance: a doc looks the same every time it is opened.
                speaker = index.count
                index[name] = speaker
                names[speaker] = name
            }
            let start = seconds(String(match.1))
            // `Line.id` is its start; a doc can hold two turns in one second,
            // so nudge each line apart. The printed stamp floors it away.
            lines.append(Line(speaker: speaker,
                              start: start + Double(lines.count) / 10_000,
                              end: start,
                              text: String(match.3)))
        }

        let title = text.split(separator: "\n").first { $0.hasPrefix("# ") }
            .map { String($0.dropFirst(2)) }
            ?? url.deletingPathExtension().lastPathComponent

        return ParsedDoc(url: url, title: title, date: date,
                         lines: lines, names: names, raw: text)
    }

    /// `12:03` or `1:02:03` → seconds.
    private static func seconds(_ stamp: String) -> TimeInterval {
        stamp.split(separator: ":").reduce(0) { $0 * 60 + (Double($1) ?? 0) }
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
