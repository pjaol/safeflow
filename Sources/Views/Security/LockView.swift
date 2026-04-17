import SwiftUI
import os

struct LockView: View {
    @EnvironmentObject private var securityService: SecurityService
    @State private var isAuthenticating = false
    @State private var showingPinEntry = false
    @State private var hasPin = false
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "LockView")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: AppTheme.Metrics.standardSpacing) {
                    Spacer()
                    
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.primaryBlue)
                        .accessibilityHidden(true)
                    
                    Text("Clio Daye is Locked")
                        .font(AppTheme.Typography.headlineFont)
                        .foregroundColor(AppTheme.Colors.deepGrayText)
                    
                    if !securityService.isAuthenticationRequired {
                        // Show setup buttons if authentication is not required
                        Button("Set Up Security") {
                            securityService.isAuthenticationRequired = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityLabel("Set Up Security")
                        .accessibilityHint("Enable Face ID, Touch ID, or PIN to protect your data")
                    } else if securityService.canUseBiometrics {
                        // Show Face ID/Touch ID button
                        Button {
                            authenticate()
                        } label: {
                            Label(
                                "Unlock with Face ID/Touch ID",
                                systemImage: "faceid"
                            )
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityLabel("Unlock with Face ID or Touch ID")
                        .accessibilityHint("Authenticate using biometrics to open the app")

                        if hasPin {
                            Button("Use PIN Instead") {
                                showingPinEntry = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityLabel("Use PIN Instead")
                            .accessibilityHint("Enter your PIN to unlock the app")
                        }
                    } else if hasPin {
                        // Show PIN entry button
                        Button("Enter PIN") {
                            showingPinEntry = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityLabel("Enter PIN")
                        .accessibilityHint("Enter your PIN to unlock the app")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                logger.debug("Screen size changed to: \(newSize.width) x \(newSize.height)")
            }
            .sheet(isPresented: $showingPinEntry) {
                PinEntryView(isPresented: $showingPinEntry)
                    .interactiveDismissDisabled()
            }
            .task {
                hasPin = await securityService.hasFallbackPin
                if securityService.canUseBiometrics && securityService.isAuthenticationRequired {
                    authenticate()
                } else if hasPin && securityService.isAuthenticationRequired {
                    showingPinEntry = true
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func authenticate() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        Task {
            let success = await securityService.authenticateWithBiometrics()
            isAuthenticating = false
            
            if !success {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
}

#if DEBUG || BETA
struct LockView_Previews: PreviewProvider {
    static var previews: some View {
        LockView()
            .environmentObject(SecurityServicePreview.shared)
    }
}
#endif 