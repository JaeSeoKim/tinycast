import CoreGraphics

/// Switches macOS Space by synthesising the Dock's own horizontal swipe, minus the slide.
@MainActor
enum SpaceSwitcher {
    enum Direction: Sendable {
        case previous
        case next
    }

    /// Quiet on refusal like the mover, and the grant is prompted for from this explicit gesture.
    @discardableResult
    static func switchSpace(_ direction: Direction) -> Bool {
        guard Permissions.ensureAccessibility() else { return false }
        // Three phases, not two: with two the Dock is left mid-gesture and never lands the switch.
        for phase in [Phase.began, .changed, .ended] {
            guard post(phase, direction: direction) else { return false }
        }
        return true
    }

    /// Undocumented `CGEventField`s; the open C enum lets these raw values import as-is.
    private enum Field {
        static let eventType = CGEventField(rawValue: 55)!
        static let gestureHIDType = CGEventField(rawValue: 110)!
        static let swipeMotion = CGEventField(rawValue: 123)!
        static let swipeProgress = CGEventField(rawValue: 124)!
        static let swipeVelocityX = CGEventField(rawValue: 129)!
        static let swipeVelocityY = CGEventField(rawValue: 130)!
        static let phase = CGEventField(rawValue: 132)!
    }

    private enum Phase: Int64 {
        case began = 1
        case changed = 2
        case ended = 4
    }

    private static let dockControlEventType: Int64 = 30
    private static let dockSwipeHIDEventType: Int64 = 23
    private static let horizontalMotion: Int64 = 1
    private static let velocity = 2000.0

    /// The trick: a swipe reported as already complete leaves the window server nothing to animate.
    private static let completedProgress = Double(Float.leastNonzeroMagnitude)

    private static func post(_ phase: Phase, direction: Direction) -> Bool {
        guard let event = CGEvent(source: nil) else { return false }
        let sign = direction == .next ? 1.0 : -1.0
        event.setIntegerValueField(Field.eventType, value: dockControlEventType)
        event.setIntegerValueField(Field.gestureHIDType, value: dockSwipeHIDEventType)
        event.setIntegerValueField(Field.phase, value: phase.rawValue)
        event.setIntegerValueField(Field.swipeMotion, value: horizontalMotion)
        event.setDoubleValueField(Field.swipeProgress, value: sign * completedProgress)
        event.setDoubleValueField(Field.swipeVelocityX, value: sign * velocity)
        event.setDoubleValueField(Field.swipeVelocityY, value: sign * velocity)
        event.post(tap: .cgSessionEventTap)
        return true
    }
}
