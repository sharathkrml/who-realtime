import SwiftUI

/// Just-saved state: a real summary (duration, lines, speakers), inline name
/// editing with the same hue coding as the transcript, and the doc preview.
struct SavedCard: View {
    @Environment(SessionModel.self) private var model
    @Environment(\.transcriptMaxHeight) private var transcriptMax
    let docURL: URL

    @FocusState private var focusedSpeaker: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summary
            if let speakers = distinctSpeakers {
                namingPanel(speakers)
            }
            TranscriptList(lines: model.lines,
                           tailText: "",
                           names: model.speakerNames,
                           live: false)
                .clipShape(.rect(cornerRadius: 12))
                .card(radius: 12)
                .frame(minHeight: 200, maxHeight: transcriptMax ?? .infinity)
            actions
        }
        .onAppear {
            focusedSpeaker = distinctSpeakers?.first
        }
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("Transcript saved to ~/Documents/Meetings")
                    .font(.footnote.weight(.semibold))
                Text("\(MeetingDoc.timestamp(model.elapsed)) · \(model.lines.count) lines · \(max(model.speakerCount, distinctSpeakers?.count ?? 0)) speakers")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func namingPanel(_ speakers: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name the speakers — the doc rewrites as you type")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(speakers, id: \.self) { speaker in
                HStack(spacing: 8) {
                    SpeakerChip(label: chipLabel(for: speaker),
                                color: Color.speaker(speaker))
                    TextField("Speaker \(speaker + 1)",
                              text: Binding(
                                get: { model.speakerNames[speaker] ?? "" },
                                set: { model.setSpeakerName($0, for: speaker) }))
                        .textFieldStyle(.roundedBorder)
                        .font(.footnote)
                        .focused($focusedSpeaker, equals: speaker)
                        .onSubmit { focusNext(after: speaker, in: speakers) }
                        .help("Renaming rewrites the saved Markdown immediately")
                }
            }
        }
    }

    private var actions: some View {
        HStack {
            Button("New recording") { model.newSession() }
            Spacer()
            Button("Reveal") {
                NSWorkspace.shared.activateFileViewerSelecting([docURL])
            }
            .help("Show the Markdown in Finder")
            Button("Open") {
                NSWorkspace.shared.open(docURL)
            }
            .keyboardShortcut(.defaultAction)
            .help("Open the doc (⏎)")
        }
        .controlSize(.regular)
    }

    // MARK: helpers

    private var distinctSpeakers: [Int]? {
        let real = Array(Set(model.lines.map(\.speaker))).filter { $0 >= 0 }.sorted()
        return real.isEmpty ? nil : real
    }

    private func chipLabel(for speaker: Int) -> String {
        let name = model.speakerNames[speaker] ?? ""
        if !name.isEmpty {
            let initials = name.split(separator: " ").prefix(2)
                .map { String($0.prefix(1)).uppercased() }.joined()
            if !initials.isEmpty { return initials }
        }
        return "S\(speaker + 1)"
    }

    private func focusNext(after speaker: Int, in speakers: [Int]) {
        if let index = speakers.firstIndex(of: speaker),
           speakers.indices.contains(index + 1) {
            focusedSpeaker = speakers[index + 1]
        } else {
            focusedSpeaker = nil
        }
    }
}
