import Foundation

/// The output level as a number: the grid the volume commands move on, and how a level reads.
/// Pure and Foundation-only so `Tools/volume-test.swift` can compile it standalone — every CoreAudio
/// call lives in `SystemCommandRunner`, every observation in `VolumeState`.
enum VolumeLevel {
    /// 20 steps of 5%, so every level lands on a round number and the preset commands
    /// (0/25/50/75/100) sit on the grid rather than between two of its lines.
    static let steps = 20
    static let step = 1 / Double(steps)

    static func clamped(_ level: Double) -> Double {
        min(max(level, 0), 1)
    }

    /// Moves to the next grid line rather than past it: from an off-grid 37%, up lands on 40% and
    /// down on 35%. A level already on the grid moves a full step.
    static func stepped(_ level: Double, up: Bool) -> Double {
        let exact = clamped(level) * Double(steps)
        // The nudge absorbs binary error — 0.4 * 20 is 8.000000000000002, which would otherwise
        // round up to 9 and leave a downward step standing still.
        let line =
            up ? (exact + tolerance).rounded(.down) + 1 : (exact - tolerance).rounded(.up) - 1
        return clamped(line / Double(steps))
    }

    static func percentage(_ level: Double) -> String {
        "\(Int((clamped(level) * 100).rounded()))%"
    }

    /// The speaker glyph for a level. Shared by the HUD and the Set Volume slider so one level never
    /// draws two different icons. It stops at two waves: three reads as a different, louder state
    /// than the half-full bar beside it.
    static func symbol(level: Double, muted: Bool = false) -> String {
        let level = clamped(level)
        if muted || level == 0 { return "speaker.slash.fill" }
        return level < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"
    }

    private static let tolerance = 1e-6
}
