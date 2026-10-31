import SwiftUI

/// Public shell for the menu bar popover: fixed width; the shared flow view
/// pads itself, so the windowed app gets identical margins.
public struct MenuBarView: View {
    public init() {}

    public var body: some View {
        MeetingView()
            .environment(\.transcriptMaxHeight, 320)
            .frame(width: 392)
    }
}
