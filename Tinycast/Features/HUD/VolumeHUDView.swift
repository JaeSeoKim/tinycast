import SwiftUI

/// The transient volume readout shown after a volume or mute command, since macOS only draws its own HUD for real media keys. A success/info confirmation for every other command is `HUDWindowController`'s pill instead, not this box, because that one has an actual level to show. Glass, because it is a floating control rather than a surface with content.
struct VolumeHUDView: View {
    @ObservedObject var state: VolumeState

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: symbol)
                .font(.system(size: Theme.Size.dialogIcon, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.primary)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Colors.controlSurface)
                Capsule()
                    .fill(Color.white.opacity(state.muted ? 0.35 : 0.85))
                    .frame(width: fill(level: state.muted ? 0 : state.level))
            }
            .frame(height: Theme.Size.volumeTrackHeight)
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: Theme.Size.hudWidth, height: Theme.Size.hudHeight)
        .frosted(in: RoundedRectangle(cornerRadius: Theme.Radius.dialog, style: .continuous))
    }

    private var symbol: String {
        if state.muted || state.level == 0 { return "speaker.slash.fill" }
        return state.level < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill"
    }

    private func fill(level: Double) -> CGFloat {
        let track = Theme.Size.hudWidth - Theme.Spacing.xxl * 2
        return track * min(max(level, 0), 1)
    }
}
