import SwiftUI
/// A view that guides users through the initial setup of the app, explaining key features and security options.
/// 
/// The onboarding flow consists of multiple pages shown in a TabView:
/// - Privacy: Explains local data storage and privacy focus
/// - Tracking: Introduces period and symptom tracking features  
/// - Security: Allows setting up biometric or PIN authentication
///
/// The view uses an environment object `SecurityService` to handle authentication setup
/// and a binding to track completion of the onboarding process.

struct OnboardingView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Binding var hasCompletedOnboarding: Bool
    @State private var showingPinSetup = false
    
    var body: some View {
        TabView {
            // Privacy Page
            VStack(spacing: AppTheme.Metrics.standardSpacing) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.primaryBlue)
                
                Text("Your Privacy First")
                    .font(AppTheme.Typography.headlineFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                
                Text("SafeFlow stores all your data locally on your device. No cloud storage, no data sharing.")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .cardStyle()
            .tag(0)
            
            // Tracking Page
            VStack(spacing: AppTheme.Metrics.standardSpacing) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.secondaryPink)
                
                Text("Easy Tracking")
                    .font(AppTheme.Typography.headlineFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                
                Text("Log your period, symptoms, and mood with just a few taps. Get predictions for your next cycle.")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .cardStyle()
            .tag(1)
            
            // Security Page
            VStack(spacing: AppTheme.Metrics.standardSpacing) {
                Image(systemName: securityService.canUseBiometrics ? "faceid" : "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.paleYellow)
                
                Text("Secure Your Data")
                    .font(AppTheme.Typography.headlineFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                
                Text("Set up security to protect your personal information.")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: AppTheme.Metrics.standardSpacing) {
                    if securityService.canUseBiometrics {
                        Button("Set Up Face ID/Touch ID") {
                            Task {
                                let success = await securityService.authenticateWithBiometrics()
                                if success {
                                    securityService.isAuthenticationRequired = true
                                    showingPinSetup = true // Set up PIN as fallback
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    
                    Button("Set Up PIN") {
                        showingPinSetup = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Skip for Now") {
                        hasCompletedOnboarding = true
                    }
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                .padding(.horizontal, 40)
                .padding(.top, AppTheme.Metrics.standardSpacing)
            }
            .padding()
            .cardStyle()
            .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .sheet(isPresented: $showingPinSetup) {
            PinSetupView()
                .interactiveDismissDisabled()
                .onDisappear {
                    // Check if PIN was successfully set
                    Task {
                        if await securityService.hasFallbackPin {
                            hasCompletedOnboarding = true
                        }
                    }
                }
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(SecurityServicePreview.createPreview())
} 