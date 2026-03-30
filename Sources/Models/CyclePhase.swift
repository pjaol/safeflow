import Foundation

enum CyclePhase: String, CaseIterable {
    case menstrual
    case follicular
    case ovulatory
    case luteal

    var displayName: String {
        switch self {
        case .menstrual: return NSLocalizedString("Menstrual", comment: "")
        case .follicular: return NSLocalizedString("Follicular", comment: "")
        case .ovulatory: return NSLocalizedString("Ovulation Window", comment: "")
        case .luteal: return NSLocalizedString("Luteal", comment: "")
        }
    }

    /// One-line description shown on the cycle phase card.
    var phaseDescription: String {
        switch self {
        case .menstrual:
            return NSLocalizedString("Rest if you can. Your body is doing real work.", comment: "")
        case .follicular:
            return NSLocalizedString("Energy typically builds. Good time for new projects.", comment: "")
        case .ovulatory:
            return NSLocalizedString("Often the highest-energy point of your cycle.", comment: "")
        case .luteal:
            return NSLocalizedString("Energy may dip toward the end of this phase.", comment: "")
        }
    }

    /// Raw hex color string — resolved to SwiftUI Color in the view layer via AppTheme.
    var themeColorName: String {
        switch self {
        case .menstrual: return "secondaryPink"
        case .follicular: return "primaryBlue"
        case .ovulatory: return "accentBlue"
        case .luteal: return "paleYellow"
        }
    }
}
