import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Environment(\.dismiss) private var dismiss
    @State private var showingBiometricSetup = false
    @State private var showingPinSetup = false
    @State private var hasPin = false
    @State private var showingDeleteConfirmation = false

    var cycleStore: CycleStore? = nil
    
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
                    .tint(AppTheme.Colors.primaryBlue)
                    
                    if securityService.isAuthenticationRequired {
                        if securityService.canUseBiometrics {
                            Button("Test Face ID/Touch ID") {
                                Task {
                                    _ = await securityService.authenticateWithBiometrics()
                                }
                            }
                            .foregroundColor(AppTheme.Colors.primaryBlue)
                        }
                        
                        Button(hasPin ? "Change PIN" : "Set Up PIN") {
                            showingPinSetup = true
                        }
                        .foregroundColor(AppTheme.Colors.secondaryPink)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your data stays on this device", systemImage: "lock.shield.fill")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                        Text("Clio Daye stores everything on your device only. Nothing is sent to any server, cloud, or third party — ever. No one else can access your cycle data remotely.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("If you need to remove all data from this device, use the delete button below.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Your Data & Privacy")
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete All My Data", systemImage: "trash")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                    }
                    
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Text("Privacy Policy")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
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
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
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
                .foregroundColor(AppTheme.Colors.primaryBlue)
                
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Use Face ID or Touch ID to protect your data")
            }
            // Show sheet for PIN setup
            .sheet(isPresented: $showingPinSetup) {
                PinSetupView()
            }
            .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    cycleStore?.clearAllData()
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your cycle logs, symptoms, and notes. This cannot be undone.")
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
            VStack(alignment: .leading, spacing: AppTheme.Metrics.standardSpacing) {
                Text("Privacy Policy")
                    .font(AppTheme.Typography.headlineFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                    .padding(.bottom)
                
                Text("Clio Daye is committed to protecting your privacy. All your data is stored locally on your device and is never shared with any third parties.")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                
                Text("Data Storage")
                    .font(AppTheme.Typography.headlineFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                    .padding(.top)
                
                Text("• All data is stored locally on your device\n• No cloud storage or syncing")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                
                Text("Security")
                    .font(AppTheme.Typography.headlineFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                    .padding(.top)
                
                Text("• Optional biometric authentication\n• No analytics or tracking")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
            }
            .padding()
            .cardStyle()
        }
        .background(AppTheme.Colors.background)
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
