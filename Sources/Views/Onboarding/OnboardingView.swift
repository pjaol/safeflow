import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Binding var hasCompletedOnboarding: Bool
    
    var body: some View {
        TabView {
            // Privacy Page
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Your Privacy First")
                    .font(.title)
                    .bold()
                
                Text("SafeFlow stores all your data locally on your device. No cloud storage, no data sharing.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .tag(0)
            
            // Tracking Page
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Easy Tracking")
                    .font(.title)
                    .bold()
                
                Text("Log your period, symptoms, and mood with just a few taps. Get predictions for your next cycle.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .tag(1)
            
            // Security Page
            VStack(spacing: 20) {
                Image(systemName: "faceid")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Secure Access")
                    .font(.title)
                    .bold()
                
                Text("Protect your data with Face ID or Touch ID.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button(action: {
                    Task {
                        if await securityService.authenticateWithBiometrics() {
                            hasCompletedOnboarding = true
                        }
                    }
                }) {
                    Text("Set Up Security")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
            .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(SecurityService())
} 