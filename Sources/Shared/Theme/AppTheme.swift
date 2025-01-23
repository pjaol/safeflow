import SwiftUI

/// Main theme configuration for the app
enum AppTheme {
    /// Color palette for the app
    enum Colors {
        static let primaryBlue = Color(hex: "A8DFF7")  // Soft sky blue
        static let secondaryPink = Color(hex: "FEC8D8") // Soft pink
        static let paleYellow = Color(hex: "FFF5C3")   // Pale yellow
        static let neutralGray = Color(hex: "F5F5F5")
        static let deepGrayText = Color(hex: "333333")
        static let mediumGrayText = Color(hex: "666666")
        
        // New colors matching the concept
        static let backgroundBlue = Color(hex: "E4F6FD") // Lighter blue for backgrounds
        static let accentBlue = Color(hex: "7FCEF5")    // Brighter blue for accents
        
        // System colors with our theme
        static let background = backgroundBlue
        static let secondaryBackground = Color.white
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