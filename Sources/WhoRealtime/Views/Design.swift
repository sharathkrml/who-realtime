import SwiftUI

// MARK: - Palette

extension Color {
    /// One hue per diarized speaker; stable per session, readable in both
    /// appearances. Unattributed speech gets gray.
    static func speaker(_ index: Int) -> Color {
        guard index >= 0 else { return .gray }
        let palette: [Color] = [.blue, .mint, .orange, .purple, .pink, .teal, .indigo, .green, .cyan, .red]
        return palette[index % palette.count]
    }
}

// MARK: - Surfaces

/// Card surface: Liquid Glass on macOS 26+, plain tinted fill below, and a
/// solid window background when the user turned Reduce Transparency on.
private struct GlassCard: ViewModifier {
    let radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var opaque

    func body(content: Content) -> some View {
        if opaque {
            content.background(Color(nsColor: .windowBackgroundColor),
                               in: .rect(cornerRadius: radius))
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            content.background(.quinary.opacity(0.45), in: .rect(cornerRadius: radius))
        }
    }
}

/// Primary action button: glass-prominent on 26+, standard below.
private struct HeroButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

extension View {
    func card(radius: CGFloat = 12) -> some View { modifier(GlassCard(radius: radius)) }
    func heroStyle() -> some View { modifier(HeroButton()) }
}

// MARK: - Transcript height budget

private struct TranscriptMaxHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    /// Caps the transcript; the popover shell sets it, windows leave it open.
    var transcriptMaxHeight: CGFloat? {
        get { self[TranscriptMaxHeightKey.self] }
        set { self[TranscriptMaxHeightKey.self] = newValue }
    }
}

// MARK: - Speaker identity

/// Small round label showing who is talking ("S2" or name initials).
struct SpeakerChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(color.opacity(0.16), in: Circle())
    }
}

// MARK: - Live meters

/// One horizontal level bar + source icon, redrawn at the model's tick rate.
struct LevelBar: View {
    let icon: String            // idle symbol, e.g. "mic"
    let activeIcon: String      // filled symbol while signal is coming in
    let level: Double           // already smoothed by the model
    let color: Color
    let accessibilityLabel: String

    private let barWidth: CGFloat = 52

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: level > 0.01 ? activeIcon : icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(level > 0.01 ? color : Color(nsColor: .tertiaryLabelColor))
                .frame(width: 14)
                .accessibilityHidden(true)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: max(3, barWidth * CGFloat(sqrt(level))))
            }
            .frame(width: barWidth, height: 4)
        }
        .animation(.linear(duration: 0.06), value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(level > 0.7 ? "Loud" : level > 0.1 ? "Present" : "Silent")
        .help("Shows the input is actually coming through")
    }
}

// MARK: - Recording pulse

/// Red dot with a slow radar ripple; static when Reduce Motion is on.
struct RecDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .fill(.red)
                    .frame(width: 9, height: 9)
                    .scaleEffect(pulse ? 1.9 : 1)
                    .opacity(pulse ? 0 : 0.45)
            }
            Circle()
                .fill(.red)
                .frame(width: 9, height: 9)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}
