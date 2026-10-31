import SwiftUI

/// Live view: the transcript is the hero, the record bar (timer + meters +
/// Stop) sits below, and the whole card reads "something is happening" at a
/// glance — audio meters, pulsing dot, monospaced timer.
struct RecordingCard: View {
    @Environment(SessionModel.self) private var model
    @Environment(\.transcriptMaxHeight) private var transcriptMax

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            warnings
            TranscriptList(lines: model.lines,
                           tailText: model.tailText,
                           names: model.speakerNames,
                           live: true)
                .clipShape(.rect(cornerRadius: 12))
                .card(radius: 12)
                .frame(minHeight: 290, maxHeight: transcriptMax ?? .infinity)
                .overlay {
                    // The first seconds are an empty card; say what is happening
                    // instead of showing nothing.
                    if model.lines.isEmpty, model.tailText.isEmpty {
                        ContentUnavailableView {
                            Label("Listening", systemImage: "waveform")
                        } description: {
                            Text("The first line appears when someone speaks.")
                        }
                        .allowsHitTesting(false)
                    }
                }
            recordBar
        }
    }

    // MARK: Signal warnings (pending permissions mostly)

    @ViewBuilder private var warnings: some View {
        if model.elapsed > 2.5, needsAttention {
            VStack(alignment: .leading, spacing: 4) {
                if !model.micLive {
                    Label("Mic is silent — approve the microphone prompt if one is showing.",
                          systemImage: "mic.slash")
                }
                if model.mode == .call, !model.callLive {
                    Label("No sound from \(model.selectedApp?.name ?? "the app") — approve the audio tap prompt.",
                          systemImage: "speaker.slash")
                }
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.12), in: .rect(cornerRadius: 10))
        }
    }

    private var needsAttention: Bool {
        !model.micLive || (model.mode == .call && !model.callLive)
    }

    // MARK: Record bar

    private var recordBar: some View {
        HStack(spacing: 10) {
            RecDot()
            Text(MeetingDoc.timestamp(model.elapsed))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())
            Spacer()
            meterColumn
            stopButton
        }
        .animation(.linear(duration: 0.3), value: model.elapsed)
    }

    @ViewBuilder private var meterColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if model.mode == .call {
                LevelBar(icon: "speaker.wave.2",
                         activeIcon: "speaker.wave.2.fill",
                         level: model.callLevel,
                         color: .purple,
                         accessibilityLabel: "Call audio level")
            }
            LevelBar(icon: "mic",
                     activeIcon: "mic.fill",
                     level: model.micLevel,
                     color: .blue,
                     accessibilityLabel: "Microphone level")
        }
    }

    private var stopButton: some View {
        Button {
            Sounds.tap()
            model.stop()
        } label: {
            Label("Stop", systemImage: "stop.fill").frame(minWidth: 52)
        }
        .heroStyle()
        .tint(.red)
        .controlSize(.regular)
        .help("End the session and build the doc")
    }
}
