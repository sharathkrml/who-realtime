import SwiftUI

/// The windowed flavor's shell: sidebar with the live flow plus everything
/// already in `~/Documents/Meetings`, detail on the right. The menu bar app
/// never sees this — it keeps `MenuBarView`.
public struct MeetingWindowView: View {
    @Environment(SessionModel.self) private var model
    @Environment(MeetingStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: Destination? = .record
    @State private var query = ""

    private enum Destination: Hashable {
        case record
        case meeting(URL)
    }

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 340)
        } detail: {
            detail
        }
        .searchable(text: $query, placement: .sidebar, prompt: "Search meetings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Sounds.tap()
                    model.toggleSession()
                } label: {
                    Label(model.isRecording ? "Stop" : "Listen",
                          systemImage: model.isRecording ? "stop.fill" : "record.circle")
                }
                .disabled(!model.canToggle)
                .help(model.isRecording ? "End the session and build the doc (⌘R)"
                                        : "Start listening (⌘R)")
            }
        }
        .onAppear { store.reload() }
        // The menu bar app can record while this window is closed, so the list
        // refreshes whenever the app comes back to the front.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reload() }
        }
        .onChange(of: model.phase) { _, phase in
            if case .saved = phase { store.reload() }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Label("Record", systemImage: "record.circle")
                .tag(Destination.record)
            Section("Meetings") {
                if store.meetings.isEmpty {
                    Text("Nothing yet — recorded meetings land in ~/Documents/Meetings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .selectionDisabled()
                }
                ForEach(filtered) { doc in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(doc.shortTitle)
                            .lineLimit(1)
                        Text(doc.lines.isEmpty ? "No speech" : "\(doc.lines.count) turns")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tag(Destination.meeting(doc.url))
                }
            }
        }
    }

    private var filtered: [ParsedDoc] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return store.meetings }
        return store.meetings.filter {
            $0.title.localizedCaseInsensitiveContains(needle)
                || $0.raw.localizedCaseInsensitiveContains(needle)
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .meeting(let url):
            if let doc = store.meetings.first(where: { $0.url == url }) {
                MeetingDetailView(doc: doc) {
                    store.delete(doc)
                    selection = .record
                }
            } else {
                ContentUnavailableView("Meeting not found", systemImage: "doc.questionmark",
                                       description: Text("It may have been moved or deleted."))
            }
        case .record, .none:
            MeetingView(showsHeader: false)
        }
    }
}
