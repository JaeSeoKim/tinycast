import SwiftUI

/// Tinycast's own slider, because `NSSlider` would drop an Aqua control onto a surface whose whole vocabulary is white-alpha over vibrancy.
struct VolumeSlider: View {
    @ObservedObject var state: VolumeState

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Image(systemName: state.level == 0 ? "speaker.slash.fill" : "speaker.fill")
                .font(Theme.Typography.menuIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: Theme.Size.menuIcon)
            GeometryReader { geometry in
                let width = geometry.size.width
                let travel = max(width - Theme.Size.volumeKnob, 1)
                let clamped = min(max(state.level, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.controlSurface)
                        .frame(height: Theme.Size.volumeTrackHeight)
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(
                            width: Theme.Size.volumeKnob / 2 + clamped * travel,
                            height: Theme.Size.volumeTrackHeight)
                    Circle()
                        .fill(Color.white)
                        .frame(width: Theme.Size.volumeKnob, height: Theme.Size.volumeKnob)
                        .offset(x: clamped * travel)
                }
                .frame(height: Theme.Size.volumeKnob)
                // minimumDistance 0 so a plain click jumps the level, matching how a native slider's track behaves.
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let position = (value.location.x - Theme.Size.volumeKnob / 2) / travel
                            state.level = min(max(position, 0), 1)
                        }
                )
            }
            .frame(height: Theme.Size.volumeKnob)
            Text(Self.percentage(state.level))
                .font(Theme.Typography.rowTrailing)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monospacedDigit()
                // A fixed slot keeps the track from resizing as the number grows from 0% to 100%.
                .frame(width: Theme.Size.rowIcon * 2, alignment: .trailing)
        }
    }

    static func percentage(_ level: Double) -> String {
        "\(Int((min(max(level, 0), 1) * 100).rounded()))%"
    }
}
