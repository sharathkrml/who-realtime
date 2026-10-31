import SwiftUI

/// Live or saved transcript. `live` turns on sticky-bottom auto-scroll
/// (scrolling up to read is never yanked back down), row-in animation, and a
/// jump-back-to-live button while the user is reading above the tail.
struct TranscriptList: View {
    let lines: [Line]
    let tailText: String
    let names: [Int: String]
    let live: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pinnedToBottom = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 9) {
                    ForEach(lines) { line in
                        TranscriptRow(line: line, name: names[line.speaker])
                    }
                    if !tailText.isEmpty {
                        HStack(alignment: .center, spacing: 4) {
                            Text(tailText)
                                .font(.callout.italic())
                                .foregroundStyle(.secondary)
                            if live {
                                TimelineView(.periodic(from: .now, by: 0.53)) { _ in
                                    Text("▍")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.leading, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("tail")
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.1),
                           value: live ? lines.count : 0)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let maxOffset = geometry.contentSize.height - geometry.containerSize.height
                return geometry.contentOffset.y >= maxOffset - 24
            } action: { _, pinned in
                pinnedToBottom = pinned
            }
            .onChange(of: lines.count) { _, _ in
                guard live, pinnedToBottom else { return }
                if let last = lines.last?.id {
                    proxy.scrollTo(last, anchor: .bottom)
                } else if !tailText.isEmpty {
                    proxy.scrollTo("tail", anchor: .bottom)
                }
            }
            .onChange(of: tailText) { _, _ in
                guard live, pinnedToBottom else { return }
                proxy.scrollTo("tail", anchor: .bottom)
            }
            .overlay(alignment: .bottom) {
                if live, !pinnedToBottom {
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                            if let last = lines.last?.id {
                                proxy.scrollTo(last, anchor: .bottom)
                            } else if !tailText.isEmpty {
                                proxy.scrollTo("tail", anchor: .bottom)
                            }
                        }
                    } label: {
                        Label("Live", systemImage: "arrow.down.circle")
                            .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.15), value: pinnedToBottom)
        }
    }
}

/// One attributed line: hue-coded speaker chip + name in the header, plain
/// readable text below, thin color bar in the gutter.
struct TranscriptRow: View {
    let line: Line
    let name: String?

    private var color: Color { Color.speaker(line.speaker) }

    private var chipLabel: String {
        if let name, !name.isEmpty {
            let initials = name.split(separator: " ").prefix(2)
                .map { String($0.prefix(1)).uppercased() }.joined()
            return initials.isEmpty ? "?" : initials
        }
        return line.speaker >= 0 ? "S\(line.speaker + 1)" : "?"
    }

    private var displayName: String {
        if let name, !name.isEmpty { return name }
        return line.speaker >= 0 ? "Speaker \(line.speaker + 1)" : "Unattributed"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.6))
                .frame(width: 3)
                .clipShape(.capsule)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    SpeakerChip(label: chipLabel, color: color)
                    Text(displayName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(MeetingDoc.timestamp(line.start))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Text(line.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }
}
