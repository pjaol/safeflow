import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Environment(\.dismiss) private var dismiss
    @State private var showingBiometricSetup = false
    @State private var showingPinSetup = false
    @State private var hasPin = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Security") {
                    Toggle("Require Authentication", isOn: Binding(
                        get: { securityService.isAuthenticationRequired },
                        set: { newValue in
                            if newValue {
                                // If enabling auth, decide if we show biometrics or PIN
                                if securityService.canUseBiometrics {
                                    showingBiometricSetup = true
                                } else {
                                    showingPinSetup = true
                                }
                            } else {
                                // If disabling auth, just turn it off
                                securityService.isAuthenticationRequired = false
                            }
                        }
                    ))
                    
                    if securityService.isAuthenticationRequired {
                        if securityService.canUseBiometrics {
                            Button("Test Face ID/Touch ID") {
                                Task {
                                    _ = await securityService.authenticateWithBiometrics()
                                }
                            }
                        }
                        
                        Button(hasPin ? "Change PIN" : "Set Up PIN") {
                            showingPinSetup = true
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("Privacy Policy") {
                        PrivacyView()
                    }
                }
                
                #if DEBUG
                Section("Debug") {
                    Button("Reset Onboarding", role: .destructive) {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            // Show alert to set up biometrics
            .alert("Set Up Face ID/Touch ID", isPresented: $showingBiometricSetup) {
                Button("Set Up") {
                    Task {
                        let success = await securityService.authenticateWithBiometrics()
                        if success {
                            securityService.isAuthenticationRequired = true
                            showingPinSetup = true // also set up PIN fallback
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Use Face ID or Touch ID to protect your data")
            }
            // Show sheet for PIN setup
            .sheet(isPresented: $showingPinSetup) {
                PinSetupView()
            }
            // Use a small async method (below) to fetch the hasPin value
            .task {
                await loadPinStatus()
            }
        }
    }
    
    /// Move the async logic out of the `.task` closure and into a dedicated async func.
    @MainActor
    private func loadPinStatus() async {
        hasPin = await securityService.hasFallbackPin
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .bold()
                    .padding(.bottom)
                
                Text("SafeFlow is committed to protecting your privacy. All your data is stored locally on your device and is never shared with any third parties.")
                
                Text("Data Storage")
                    .font(.headline)
                    .padding(.top)
                
                Text("• All data is stored locally on your device\n• No cloud storage or syncing\n• Protected by device encryption")
                
                Text("Security")
                    .font(.headline)
                    .padding(.top)
                
                Text("• Optional biometric authentication\n• Data is encrypted at rest\n• No analytics or tracking")
            }
            .padding()
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Example: Using your `SecurityServicePreview.shared` or a normal SecurityService
        SettingsView()
            .environmentObject(SecurityServicePreview.shared)
    }
}
#endif
