import SwiftUI

/// The surfaces an extension's own views paint, kept here rather than in `Theme` so a third-party
/// screen can never force a change on a launcher one. Each dark value is the literal these views
/// shipped with; `Theme.Colors.ramp` is shared as a mechanism, the values are the feature's.
enum ExtensionColors {
    /// An argument field at rest, below the shared selection and hover fills.
    static let fieldFill = Theme.Colors.ramp(dark: 0.045, light: 0.05)
    /// Focus reads as a brighter edge than the field's resting hairline.
    static let fieldFocusStroke = Theme.Colors.ramp(dark: 0.28, light: 0.24)
    static let fieldStroke = Theme.Colors.ramp(dark: 0.07, light: 0.10)
    /// An unselected tag capsule in a `Form`, and the outline its selected state gains.
    static let tagFill = Theme.Colors.ramp(dark: 0.05, light: 0.05)
    static let tagSelectedStroke = Theme.Colors.ramp(dark: 0.30, light: 0.26)
    /// A grid item at rest — fainter than a list row, since a grid tiles many of them.
    static let gridItemFill = Theme.Colors.ramp(dark: 0.03, light: 0.035)
    /// The detail pane's code blocks and image placeholders.
    static let detailCardFill = Theme.Colors.ramp(dark: 0.05, light: 0.04)
}
