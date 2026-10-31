import AppKit
import SwiftUI

private let vozMB = 337
private let whoMB = 81

/// First-run download (≈550 MB): one row per model with its own progress and
/// byte count, so the wait reads as tracked work, not a stuck bar.
struct DownloadCard: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            modelRow("Voz", subtitle: "Speech recognition", size: vozMB, fraction: model.vozFraction)
            modelRow("Who", subtitle: "Speaker labeling", size: whoMB, fraction: model.whoFraction)
            Text("~\(vozMB + whoMB) MB once, fetched from Hugging Face. Runs fully offline on this Mac afterwards — nothing is uploaded.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .card(radius: 12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("First launch: downloading models")
                    .font(.footnote.weight(.semibold))
                Text("Everything after this is instant and offline")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func modelRow(_ name: String, subtitle: String, size: Int, fraction: Double) -> some View {
        HStack(spacing: 10) {
            if fraction >= 1 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.opacity)
            } else {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.footnote.weight(.medium))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(fraction * Double(size))) / \(size) MB")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                ProgressView(value: max(0.02, fraction))
                    .animation(.linear(duration: 0.2), value: fraction)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Failure surface: a headline, the reason, and — when the fix lives in
/// System Settings — named deep links instead of a sentence telling the user
/// to go hunting for a pane.
struct FailedCard: View {
    @Environment(SessionModel.self) private var model
    let failure: SessionModel.Failure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(failure.title, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.footnote.weight(.semibold))
            Text(failure.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if failure.permissions { permissionHelp }
            HStack(spacing: 8) {
                Button("Try again") { model.retryAfterFailure() }
                Button("Copy details") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(failure.title): \(failure.message)", forType: .string)
                }
                .controlSize(.small)
                Spacer()
            }
        }
        .padding(14)
        .card(radius: 12)
    }

    private var permissionHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Turn Who Realtime on in both panes, then try again. If it still fails, quit and reopen the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                SettingsPaneButton(title: "Microphone", pane: "Privacy_Microphone")
                if model.mode == .call {
                    SettingsPaneButton(title: "System Audio", pane: "Privacy_ScreenCapture")
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10), in: .rect(cornerRadius: 10))
    }
}

/// One Privacy & Security pane. `Privacy_ScreenCapture` is the pane System
/// Settings labels "Screen & System Audio Recording" — the one process taps
/// are gated by.
private struct SettingsPaneButton: View {
    let title: String
    let pane: String

    var body: some View {
        Button {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
            NSWorkspace.shared.open(url)
        } label: {
            Label("\(title) Settings", systemImage: "gearshape")
        }
        .controlSize(.small)
        .help("Opens System Settings → Privacy & Security")
    }
}
