import SwiftUI
import WhoRealtime

/// The menu bar flavor: popover-driven, no Dock icon. The menu bar label
/// flips to a record circle while a session is active, so state is visible
/// even with the popover closed.
@main
struct WhoMenuBarApp: App {
    @State private var model = SessionModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(model)
                .onAppear { model.bootstrapIfNeeded() }
            Divider()
            Button("Quit Who Realtime") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            if model.isRecording {
                Image(systemName: "record.circle")
                    .foregroundStyle(.red)
                    .font(.system(size: 15, weight: .semibold))
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 15))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
