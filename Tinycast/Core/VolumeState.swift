import Combine
import Foundation

/// The live output level behind the Set Volume slider and the volume HUD's bar. Published so a
/// repeated volume command refreshes a HUD that is already on screen instead of rebuilding it.
/// The arithmetic lives in `VolumeLevel`; this only holds and announces.
final class VolumeState: ObservableObject {
    @Published var level: Double
    @Published var muted: Bool

    init(level: Double, muted: Bool = false) {
        self.level = level
        self.muted = muted
    }
}
