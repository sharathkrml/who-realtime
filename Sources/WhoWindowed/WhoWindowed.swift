import SwiftUI
import WhoRealtime

/// The full desktop flavor: a regular Dock app with a sidebar of past meetings
/// and a resizable window. ⌘R toggles listening from anywhere in the app.
@main
struct WhoWindowedApp: App {
    @State private var model = SessionModel()
    @State private var store = MeetingStore()

    var body: some Scene {
        Window("Who Realtime", id: "meeting") {
            MeetingWindowView()
                .environment(model)
                .environment(store)
                .onAppear { model.bootstrapIfNeeded() }
        }
        .defaultSize(width: 940, height: 700)
        .commands {
            CommandMenu("Session") {
                Button {
                    model.toggleSession()
                } label: {
                    Text(model.isRecording ? "Stop & Make the Doc" : "Listen")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!model.canToggle)
            }
        }
    }
}
