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

struct FailedCard: View {
    @Environment(SessionModel.self) private var model
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Something went wrong", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.footnote.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack {
                Button("Try again") { model.retryAfterFailure() }
                Button("Copy details") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message, forType: .string)
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .card(radius: 12)
    }
}
