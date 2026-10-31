import AppKit
import SwiftUI

/// A meeting already on disk: the same rows as the live transcript, read out of
/// the saved Markdown. Read-only — renaming speakers exists in the saved card
/// right after a session, where the doc is being handed off.
public struct MeetingDetailView: View {
    @State private var confirmDelete = false

    private let doc: ParsedDoc
    private let onDelete: () -> Void

    public init(doc: ParsedDoc, onDelete: @escaping () -> Void) {
        self.doc = doc
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            transcript
            actions
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(doc.title)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        let speakers = Set(doc.lines.map(\.speaker)).filter { $0 >= 0 }.count
        let turns = doc.lines.isEmpty ? "No speech" : "\(doc.lines.count) turns"
        return "\(turns) · \(speakers) \(speakers == 1 ? "speaker" : "speakers")"
    }

    @ViewBuilder private var transcript: some View {
        if doc.lines.isEmpty {
            // Unattributed or hand-edited doc: the raw Markdown beats a blank pane.
            ScrollView {
                Text(doc.raw)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .card(radius: 12)
        } else {
            TranscriptList(lines: doc.lines, tailText: "", names: doc.names, live: false)
                .clipShape(.rect(cornerRadius: 12))
                .card(radius: 12)
                .frame(maxHeight: .infinity)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Copy Markdown", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(doc.raw, forType: .string)
            }
            .help("Copy the whole transcript")
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([doc.url])
            }
            Button("Open") {
                NSWorkspace.shared.open(doc.url)
            }
            .help("Open the Markdown in your editor")
            Spacer()
            Button("Move to Trash", role: .destructive) { confirmDelete = true }
                .help("Sends the transcript and its recording to the Trash")
        }
        .confirmationDialog("Move this meeting to the Trash?", isPresented: $confirmDelete) {
            Button("Move to Trash", role: .destructive, action: onDelete)
        } message: {
            Text("The transcript and its recording both go to the Trash.")
        }
    }
}
