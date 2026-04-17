import SwiftUI

// MARK: - LifeStage

/// The user's declared reproductive life stage. Always set by the user — never inferred from data.
/// Persisted in UserDefaults under the key `LifeStage.defaultsKey`.
/// Default on first launch is `.regular`.
enum LifeStage: String, Codable, CaseIterable {
    case regular
    case irregular
    case perimenopause
    case menopause
    case paused

    // MARK: - UserDefaults key

    static let defaultsKey = "lifeStage"

    // MARK: - Labels

    var localizedName: LocalizedStringKey {
        switch self {
        case .regular:       return "Regular cycles"
        case .irregular:     return "Irregular cycles"
        case .perimenopause: return "Perimenopause"
        case .menopause:     return "Menopause"
        case .paused:        return "Cycle paused"
        }
    }

    var localizedNameString: String {
        switch self {
        case .regular:       return String(localized: "Regular cycles")
        case .irregular:     return String(localized: "Irregular cycles")
        case .perimenopause: return String(localized: "Perimenopause")
        case .menopause:     return String(localized: "Menopause")
        case .paused:        return String(localized: "Cycle paused")
        }
    }

    /// One-line description shown in the Settings list row.
    var settingsDescription: LocalizedStringKey {
        switch self {
        case .regular:       return "Periods come roughly on schedule"
        case .irregular:     return "Periods vary — predictions show a wider range"
        case .perimenopause: return "Cycles are changing — history and symptoms take priority"
        case .menopause:     return "Periods have stopped — symptoms and summaries are the main view"
        case .paused:        return "Post-partum, breastfeeding, or taking a break"
        }
    }

    /// Two-sentence card description shown in LifeStageGuideView picker.
    /// Kept to two sentences so the card holds at XXL Dynamic Type.
    var cardDescription: LocalizedStringKey {
        switch self {
        case .regular:
            return "Periods come roughly on schedule. The app predicts your next period and tracks where you are in your cycle each day."
        case .irregular:
            return "Your cycle varies and predictions aren't always reliable. The app shows a wider range and tracks patterns over time."
        case .perimenopause:
            return "Your cycles are shifting. We track what's actually happened instead of guessing what's next, and add hot flashes, brain fog, and joint pain to your tracker."
        case .menopause:
            return "Periods have stopped. The app focuses on how you feel each day and what patterns emerge over time."
        case .paused:
            return "Post-partum, breastfeeding, or taking a break. The app skips period tracking and logs how you feel. Switch back anytime."
        }
    }

    // MARK: - Feature flags

    /// Whether the home screen should show cycle-prediction UI.
    var showsCyclePrediction: Bool {
        switch self {
        case .regular, .irregular: return true
        case .perimenopause, .menopause, .paused: return false
        }
    }

    /// Whether the home screen shows the bleed history card instead of the cycle ring.
    var showsBleedHistory: Bool {
        self == .perimenopause
    }

    /// Whether the flow slider is shown in secondary/unexpected mode.
    var flowSliderIsSecondary: Bool {
        switch self {
        case .menopause, .paused: return true
        case .regular, .irregular, .perimenopause: return false
        }
    }
}

// MARK: - PausedContext

/// Sub-context for the `paused` life stage. Affects copy tone but not the data model.
/// Persisted in UserDefaults under the key `PausedContext.defaultsKey`.
enum PausedContext: String, Codable {
    case recovering
    case notTracking

    static let defaultsKey = "pausedContext"
}
