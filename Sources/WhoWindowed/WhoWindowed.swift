import SwiftUI
import WhoRealtime

/// The regular windowed flavor: Dock app with a resizable window and a
/// Session menu (⌘R toggles listening) for keyboard-first use.
@main
struct WhoWindowedApp: App {
    @State private var model = SessionModel()

    var body: some Scene {
        Window("Who Realtime", id: "meeting") {
            MeetingView()
                .environment(model)
                .onAppear { model.bootstrapIfNeeded() }
                .frame(minWidth: 420, minHeight: 520)
        }
        .defaultSize(width: 520, height: 640)
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
