import Testing
import Voz
import Who
@testable import WhoRealtime

@Suite
struct AttributionTests {
    private func word(_ text: String, _ start: Double, _ end: Double) -> Word {
        Word(text: text, start: start, end: end)
    }

    @Test func breaksLinesOnSpeakerChange() {
        let turns = [
            Turn(start: 0, end: 10, speaker: 0),
            Turn(start: 20, end: 30, speaker: 1),
        ]
        let lines = Attribution.lines(words: [
            word("Hey", 1.0, 1.4), word("Ada", 1.5, 1.9),
            word("Hello", 22.0, 22.4), word("there", 22.5, 23.0),
        ], turns: turns)
        #expect(lines.count == 2)
        #expect(lines[0].speaker == 0)
        #expect(lines[0].text == "Hey Ada")
        #expect(lines[1].speaker == 1)
        #expect(lines[1].start == 22.0)
    }

    @Test func breaksLinesOnLongPausesFromTheSameSpeaker() {
        let lines = Attribution.lines(words: [
            word("First", 1.0, 1.5),
            word("Second", 6.0, 6.5),
        ], turns: [Turn(start: 0, end: 10, speaker: 3)])
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.speaker == 3 })
    }

    @Test func overlappingWordsGoToTheBestOverlappingTurn() {
        let turns = [
            Turn(start: 0, end: 10, speaker: 0),
            Turn(start: 9.5, end: 20, speaker: 1),
        ]
        let lines = Attribution.lines(words: [word("mixed", 9.8, 10.4)], turns: turns)
        #expect(lines.count == 1)
        #expect(lines[0].speaker == 1)   // 0.6s overlap vs 0.2s
    }

    @Test func wordsOutsideEveryTurnTakeTheNearestSpeaker() {
        let turns = [
            Turn(start: 40, end: 45, speaker: 2),
            Turn(start: 80, end: 90, speaker: 1),
        ]
        let lines = Attribution.lines(words: [word("stray", 50, 50.4)], turns: turns)
        #expect(lines[0].speaker == 2)   // centers 42.5 vs 85.0
    }

    @Test func emptyTurnsLeaveWordsUnattributed() {
        let lines = Attribution.lines(words: [word("only", 0, 0.3)], turns: [])
        #expect(lines[0].speaker == -1)
    }

    @Test func timestampsFormatAsClockTimes() {
        #expect(MeetingDoc.timestamp(0) == "00:00")
        #expect(MeetingDoc.timestamp(62) == "01:02")
        #expect(MeetingDoc.timestamp(3723) == "1:02:03")
    }

    @Test func markdownNamesSpeakersAndTimes() {
        let lines = Attribution.lines(words: [
            word("Hi", 1.0, 1.3), word("team", 1.4, 1.8),
        ], turns: [Turn(start: 0, end: 10, speaker: 0)])
        let markdown = MeetingDoc.markdown(
            title: "Meeting", lines: lines, names: [0: "Ada"])
        #expect(markdown.contains("**[00:01] Ada:** Hi team"))
        #expect(markdown.contains("# Meeting"))
    }
}
