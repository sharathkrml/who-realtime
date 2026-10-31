import Foundation
import Who
import Voz

/// One attributed stretch of the meeting: a run of words by one speaker.
struct Line: Identifiable, Hashable, Sendable {
    /// `0…`, or `-1` while nothing has been diarized yet.
    let speaker: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String

    /// Stable across diarization passes: SwiftUI re-keys rows by `start`, so a
    /// re-attributed row updates in place instead of tearing down the list.
    var id: TimeInterval { start }
}

enum Attribution {
    /// Best-overlap turn for a word. Ties go to the earlier speaker; a word
    /// outside every turn (head/tail silence) inherits the nearest turn's
    /// speaker so a pause doesn't orphan words.
    static func bestSpeaker(for word: Word, turns: [Turn]) -> Int? {
        guard !turns.isEmpty else { return nil }
        var best: (speaker: Int, overlap: TimeInterval)?
        for turn in turns {
            let overlap = min(word.end, turn.end) - max(word.start, turn.start)
            if overlap > 0 && (best == nil || overlap > best!.overlap) {
                best = (turn.speaker, overlap)
            }
        }
        if let best { return best.speaker }
        // Nearest turn in time.
        let nearest = turns.min {
            abs(word.start - ($0.start + $0.end) / 2) < abs(word.start - ($1.start + $1.end) / 2)
        }
        return nearest?.speaker
    }

    /// Words → lines: break on speaker change and on a pause longer than `gap`.
    static func lines(words: [Word], turns: [Turn], gap: TimeInterval = 2.0) -> [Line] {
        var lines: [Line] = []
        var buffered: [Word] = []
        var speaker: Int?

        func flush() {
            guard !buffered.isEmpty else { return }
            lines.append(Line(
                speaker: speaker ?? -1,
                start: buffered.first!.start,
                end: buffered.last!.end,
                text: buffered.map(\.text).joined(separator: " ")
            ))
        }

        for word in words {
            let thisSpeaker = bestSpeaker(for: word, turns: turns)
            let breakLine = speaker != nil && thisSpeaker != speaker
            let pause = buffered.last.map { word.start - $0.end } ?? 0
            if breakLine || (speaker != nil && thisSpeaker == speaker && pause > gap) || speaker != thisSpeaker {
                if !buffered.isEmpty { flush() }
                buffered.removeAll()
            }
            buffered.append(word)
            speaker = thisSpeaker
        }
        flush()
        return lines
    }
}
