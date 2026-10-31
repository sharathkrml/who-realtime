import Foundation
import Testing
@testable import WhoRealtime

/// The library reads docs back out of `~/Documents/Meetings`, so the writer and
/// the reader have to agree on the one format `MeetingDoc.markdown` emits.
@Suite
struct MeetingDocParseTests {
    private let url = URL(fileURLWithPath: "/tmp/Meeting 2026-10-31 16.18.md")

    @Test func roundTripsAWrittenDoc() throws {
        let lines = [
            Line(speaker: 0, start: 5, end: 7, text: "Hey Ada"),
            Line(speaker: 1, start: 3723, end: 3729, text: "Nothing to report."),
        ]
        let text = MeetingDoc.markdown(title: "Meeting — October 31, 2026 16:18",
                                       lines: lines,
                                       names: [0: "Ada", 1: "Grace"])

        let doc = try #require(MeetingDoc.parse(text: text, url: url))

        #expect(doc.title == "Meeting — October 31, 2026 16:18")
        #expect(doc.lines.count == 2)
        #expect(doc.names == [0: "Ada", 1: "Grace"])
        #expect(doc.lines[0].text == "Hey Ada")
        #expect(doc.lines[0].speaker == 0)
        // Timestamps survive the sub-millisecond nudge used for row identity.
        #expect(MeetingDoc.timestamp(doc.lines[1].start) == "1:02:03")
        #expect(doc.lines[1].text == "Nothing to report.")
    }

    @Test func keepsSameSecondTurnsDistinct() throws {
        // `Line.id` is its start, so two turns in one second must not collide
        // or SwiftUI re-keys the list and drops rows.
        let lines = [
            Line(speaker: 0, start: 5, end: 6, text: "One"),
            Line(speaker: 1, start: 5, end: 6, text: "Two"),
        ]
        let text = MeetingDoc.markdown(title: "Me", lines: lines, names: [:])
        let doc = try #require(MeetingDoc.parse(text: text, url: url))

        #expect(doc.lines.count == 2)
        #expect(doc.lines[0].id != doc.lines[1].id)
        #expect(MeetingDoc.timestamp(doc.lines[1].start) == "00:05")
    }

    @Test func unattributedSpeechStaysUnattributed() throws {
        let lines = [Line(speaker: -1, start: 3, end: 4, text: "Who was that?")]
        let text = MeetingDoc.markdown(title: "Me", lines: lines, names: [:])
        let doc = try #require(MeetingDoc.parse(text: text, url: url))

        #expect(doc.lines.first?.speaker == -1)
        #expect(doc.names.isEmpty)
    }

    @Test func keepsRawTextWhenThereIsNothingToParse() throws {
        let text = "# Hand written\n\nNo transcript here.\n"
        let doc = try #require(MeetingDoc.parse(text: text, url: url))

        #expect(doc.lines.isEmpty)
        #expect(doc.title == "Hand written")
        #expect(doc.raw == text)
    }

    @Test func fallsBackToTheFileNameWithoutATitle() throws {
        let doc = try #require(MeetingDoc.parse(text: "nothing", url: url))
        #expect(doc.title == "Meeting 2026-10-31 16.18")
        #expect(doc.shortTitle == "Meeting 2026-10-31 16.18")
    }

    @Test func missingFileIsNil() {
        #expect(MeetingDoc.parse(url: URL(fileURLWithPath: "/tmp/does-not-exist.md")) == nil)
    }
}
