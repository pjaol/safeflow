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
                Image(systemName: securityService.canUseBiometrics ? "faceid" : "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Secure Access")
                    .font(.title)
                    .bold()
                
                if securityService.canUseBiometrics {
                    Text("Protect your data with Face ID/Touch ID or a PIN code.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button(action: {
                        securityService.isAuthenticationRequired = true
                        Task {
                            if await securityService.authenticateWithBiometrics() {
                                hasCompletedOnboarding = true
                            }
                        }
                    }) {
                        Label("Set Up Face ID/Touch ID", systemImage: "faceid")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    Button("Set Up PIN Instead") {
                        securityService.isAuthenticationRequired = true
                        showingPinSetup = true
                    }
                    .padding(.top, 10)
                } else {
                    Text("Protect your data with a secure PIN code.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button(action: {
                        securityService.isAuthenticationRequired = true
                        showingPinSetup = true
                    }) {
                        Label("Set Up PIN", systemImage: "key.fill")
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
            }
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