import SwiftUI

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Metrics.cardPadding)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.Metrics.cornerRadius)
            .shadow(radius: 2)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.bodyFont)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                AppTheme.Colors.primaryBlue
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .foregroundColor(.white)
            .cornerRadius(AppTheme.Metrics.buttonCornerRadius)
            .shadow(radius: configuration.isPressed ? 1 : 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.bodyFont)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                AppTheme.Colors.secondaryPink
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .foregroundColor(.white)
            .cornerRadius(AppTheme.Metrics.buttonCornerRadius)
            .shadow(radius: configuration.isPressed ? 1 : 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
} 