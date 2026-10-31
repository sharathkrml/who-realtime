import SwiftUI

/// The shared meeting flow: one view per app phase; the model owns every
/// transition, so the UI never shadows state. Rented on the menu bar popover
/// and on the regular windowed app.
public struct MeetingView: View {
    @Environment(SessionModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var swap: some Transition {
        // Reduce Motion is honored by animation(_:value:) on the container:
        // a nil animation swaps content instantly instead of animating.
        .opacity.combined(with: .offset(y: 8))
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.15), value: model.phase)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Who Realtime")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if case .recording = model.phase {
                Text("REC")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red.opacity(0.14), in: .capsule)
                    .accessibilityLabel("Recording")
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .missingModels, .models:
            DownloadCard().transition(swap)
        case .idle:
            SetupCard().transition(swap)
        case .recording:
            RecordingCard().transition(swap)
        case .finishing:
            FinishingCard().transition(swap)
        case .saved(let url):
            SavedCard(docURL: url).transition(swap)
        case .failed(let failure):
            FailedCard(failure: failure).transition(swap)
        }
    }
}

private struct FinishingCard: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Finishing the transcript…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 18)
    }
}
