import SwiftUI

/// Idle prompt: pick a mode + app, then Listen. Real app icons in the capture
/// menu so the target is unmistakable before any prompt appears.
struct SetupCard: View {
    @Environment(SessionModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: Binding(
                get: { model.mode },
                set: { model.mode = $0 })) {
                Text("On this Mac").tag(SessionModel.Mode.call)
                Text("In a room").tag(SessionModel.Mode.room)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: model.mode)

            if model.mode == .call {
                appPicker
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6)))
                if model.apps.isEmpty {
                    HStack(spacing: 6) {
                        Label("Waiting for audio — the list fills as the meeting plays sound.",
                              systemImage: "waveform.path.ecg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reload") { model.reloadApps() }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                    }
                    .transition(reduceMotion ? .opacity : .opacity)
                }
            }

            Button {
                Sounds.tap()
                model.start()
            } label: {
                Label(model.launching ? "Starting…" : "Listen", systemImage: "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .heroStyle()
            .tint(.red)
            .controlSize(.large)
            .disabled(model.launching)
            .keyboardShortcut(.defaultAction)
            .help("Start listening and transcribing (⏎)")

            VStack(alignment: .leading, spacing: 4) {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label("Everything runs on this Mac — nothing leaves the room.",
                      systemImage: "lock.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appPicker: some View {
        Menu {
            ForEach(model.apps) { app in
                Button {
                    model.selectedApp = app
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon).resizable().frame(width: 15, height: 15)
                        } else {
                            Image(systemName: "app")
                        }
                        Text(app.name)
                    }
                }
            }
            Divider()
            Button("Reload list", systemImage: "arrow.clockwise") { model.reloadApps() }
        } label: {
            HStack(spacing: 8) {
                appIconView(size: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Capture from")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(model.selectedApp?.name ?? "None")
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .frame(maxWidth: .infinity)
        .help("Apps only appear while they're actually outputting sound")
    }

    private func appIconView(size: CGFloat) -> some View {
        Group {
            if let icon = model.selectedApp?.icon {
                Image(nsImage: icon).resizable().frame(width: size, height: size)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: size - 2))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
            }
        }
    }

    private var footnote: String {
        switch model.mode {
        case .call:
            "Captures the call app's audio plus your microphone, so what you say lands in the doc too. The first tap shows a system consent prompt."
        case .room:
            "Uses only the Mac's microphone. Best with the Mac at the center of the table."
        }
    }
}
