import Testing
import Voz
import Who
@testable import WhoRealtime

@Suite
struct LevelMeterTests {
    @Test func drainReturnsPeakAndClears() {
        let meter = LevelMeter()
        #expect(!meter.drain().hasSignal)
        meter.record([0.1, -0.9, 0.4])
        let drained = meter.drain()
        #expect(abs(drained.peak - 0.9) < 0.001)
        #expect(drained.hasSignal)
        #expect(meter.drain().peak == 0)
    }

    @Test func exactZerosAreNotSignal() {
        let meter = LevelMeter()
        meter.record([0, 0, 0])
        #expect(!meter.drain().hasSignal)
    }

    @Test func displayDecaysTowardZeroAtTheWindowPeak() {
        #expect(LevelMeter.display(previous: 0.5, peak: 0.9) == 0.9)   // rise is instant
        var previous = 1.0
        for _ in 0..<40 {                                              // silence decays monotonically
            let now = LevelMeter.display(previous: previous, peak: 0)
            #expect(now < previous)
            previous = now
        }
        #expect(previous < 0.01)
    }
}

@Suite
struct LineIdentityTests {
    @Test func lineIdentityIsStableAcrossReattribution() {
        func make() -> [Line] {
            Attribution.lines(
                words: [Word(text: "Hi", start: 1.0, end: 1.3), Word(text: "team", start: 1.4, end: 1.8)],
                turns: [Turn(start: 0, end: 10, speaker: 0)])
        }
        // Every diarization pass rebuilds lines; ids must match so SwiftUI
        // re-keys rows in place instead of tearing the list down.
        #expect(make()[0].id == make()[0].id)
    }
}
