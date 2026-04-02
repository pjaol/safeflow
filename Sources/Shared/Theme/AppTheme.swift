import SwiftUI

/// Main theme configuration for the app
enum AppTheme {
    /// Color palette for the app
    enum Colors {
        static let primaryBlue = Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.30, green: 0.55, blue: 0.72, alpha: 1) // muted dark blue
                : UIColor(red: 0.66, green: 0.87, blue: 0.97, alpha: 1) // #A8DFF7
        })
        static let secondaryPink = Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.72, green: 0.38, blue: 0.50, alpha: 1) // muted dark pink
                : UIColor(red: 0.996, green: 0.784, blue: 0.847, alpha: 1) // #FEC8D8
        })
        static let paleYellow = Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.45, green: 0.40, blue: 0.18, alpha: 1) // muted dark yellow
                : UIColor(red: 1.0, green: 0.961, blue: 0.765, alpha: 1) // #FFF5C3
        })
        static let neutralGray = Color(UIColor.systemGray6)
        static let deepGrayText = Color(UIColor.label)
        static let mediumGrayText = Color(UIColor.secondaryLabel)
        
        // Adaptive system background — warm near-white in light mode, proper dark in dark mode
        static let accentBlue = Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.35, green: 0.62, blue: 0.82, alpha: 1) // muted dark accent
                : UIColor(red: 0.498, green: 0.808, blue: 0.961, alpha: 1) // #7FCEF5
        })

        // Nudge card backgrounds — tinted surfaces that work in both modes
        static let nudgeHealthBackground = Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.30, green: 0.27, blue: 0.12, alpha: 1) // warm dark amber tint
                : UIColor(red: 0.996, green: 0.953, blue: 0.784, alpha: 1) // #FEF3C7
        })
        static let nudgeComfortBackground = Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.38, green: 0.18, blue: 0.24, alpha: 1) // warm dark pink tint
                : UIColor(red: 0.992, green: 0.910, blue: 0.937, alpha: 1) // #FDE8EF
        })

        static let background = Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor.systemBackground                                      // near-black in dark
                : UIColor(red: 0.894, green: 0.965, blue: 0.992, alpha: 1)    // #E4F6FD light pastel blue
        })
        static let secondaryBackground = Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor.secondarySystemBackground
                : UIColor.white
        })

        // Dartboard — four clearly distinct saturated colors, legible on light bg
        // Chosen for maximum hue separation: red / blue / violet / green
        static let dartPain   = Color(hex: "D94F5C")  // strong rose-red
        static let dartEnergy = Color(hex: "2E86C1")  // deep sky blue
        static let dartMood   = Color(hex: "7B5EA7")  // rich violet
        static let dartGut    = Color(hex: "2E9E6B")  // forest green

        // Forecast grid — semantically named, independent of phase colors
        static let forecastPeriod  = Color(hex: "E8707A")  // warm coral
        static let forecastFertile = Color(hex: "3DB8C5")  // saturated teal
        static let forecastMood    = Color(hex: "B45309")  // deep amber — WCAG AA on all app backgrounds
        static let forecastSymptom = Color(hex: "9B6FD4")  // muted purple

        /// Accessible amber — replaces all previous #E6A817 / #F5A623 uses.
        /// Contrast: 5.02:1 on white, 4.52:1 on app blue, 4.51:1 on pale yellow nudge bg.
        static let amber = Color(hex: "B45309")

        // Ring colours — saturated, legible on white card background at small stroke widths
        static let ringMenstrual  = Color(hex: "E8707A")  // warm coral
        static let ringFollicular = Color(hex: "3DB8C5")  // saturated teal
        static let ringOvulatory  = Color(hex: "2E86C1")  // deep sky blue
        static let ringLuteal     = Color(hex: "9B6FD4")  // muted purple

        /// Resolves a `CyclePhase.themeColorName` string to the matching Color.
        static func forPhase(_ colorName: String) -> Color {
            switch colorName {
            case "secondaryPink": return secondaryPink
            case "primaryBlue":   return primaryBlue
            case "accentBlue":    return accentBlue
            case "paleYellow":    return amber  // paleYellow is too light for icons/text; use accessible amber
            default:              return primaryBlue
            }
        }

        /// Saturated ring colour for the cycle arc — distinct per phase, legible on white.
        static func ringColor(for colorName: String) -> Color {
            switch colorName {
            case "secondaryPink": return ringMenstrual
            case "primaryBlue":   return ringFollicular
            case "accentBlue":    return ringOvulatory
            case "paleYellow":    return ringLuteal
            default:              return ringFollicular
            }
        }
    }
    
    /// Typography definitions
    enum Typography {
        static let headlineFont = Font.system(.title, design: .rounded, weight: .bold)
        static let bodyFont = Font.system(.body, design: .rounded)
        static let captionFont = Font.system(.caption, design: .rounded, weight: .light)
    }
    
    /// Common dimensions and metrics
    enum Metrics {
        static let cornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 25
        static let cardPadding: CGFloat = 16
        static let standardSpacing: CGFloat = 20
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 