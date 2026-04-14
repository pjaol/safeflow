import SwiftUI

enum CyclePhase: String, CaseIterable {
    case menstrual
    case follicular
    case ovulatory
    case luteal

    var displayName: LocalizedStringKey {
        switch self {
        case .menstrual: return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulatory: return "Ovulation Window"
        case .luteal: return "Luteal"
        }
    }

    /// Plain String variant for use in string interpolation and concatenation contexts.
    var displayNameString: String {
        switch self {
        case .menstrual: return String(localized: "Menstrual")
        case .follicular: return String(localized: "Follicular")
        case .ovulatory: return String(localized: "Ovulation Window")
        case .luteal: return String(localized: "Luteal")
        }
    }

    /// One-line description shown on the cycle phase card.
    var phaseDescription: LocalizedStringKey {
        switch self {
        case .menstrual:
            return "Rest if you can. Your body is doing real work."
        case .follicular:
            return "Energy typically builds. Good time for new projects."
        case .ovulatory:
            return "Often the highest-energy point of your cycle."
        case .luteal:
            return "Energy may dip toward the end of this phase."
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

    var sfSymbol: String {
        switch self {
        case .menstrual:  return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulatory:  return "sun.max.fill"
        case .luteal:     return "moon.fill"
        }
    }
}
