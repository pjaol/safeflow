import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LifeStage.defaultsKey) private var lifeStage: LifeStage = .regular
    @AppStorage(LifeStage.intimateHealthHiddenKey) private var intimateHealthHidden: Bool = false
    @State private var showingLifeStageGuide = false
    @State private var showingBiometricSetup = false
    @State private var showingPinSetup = false
    @State private var hasPin = false
    @State private var showingDeleteConfirmation = false

    var cycleStore: CycleStore? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Experience") {
                    Button {
                        showingLifeStageGuide = true
                    } label: {
                        HStack {
                            Text("Life Stage")
                                .foregroundColor(AppTheme.Colors.deepGrayText)
                            Spacer()
                            Text(lifeStage.localizedName)
                                .foregroundColor(AppTheme.Colors.mediumGrayText)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.mediumGrayText.opacity(0.5))
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Life Stage, \(lifeStage.localizedNameString)")
                    .accessibilityHint("Opens life stage selector")
                    .accessibilityIdentifier("settings.lifeStageButton")
                }

                if lifeStage == .menopause {
                    Section {
                        Toggle("Intimate Health", isOn: Binding(
                            get: { !intimateHealthHidden },
                            set: { intimateHealthHidden = !$0 }
                        ))
                        .tint(AppTheme.Colors.dartMood)
                        .accessibilityLabel("Intimate Health category")
                        .accessibilityHint("Show or hide vaginal dryness, urinary urgency, and pain during sex in your daily log")
                        .accessibilityIdentifier("settings.intimateHealthToggle")
                    } header: {
                        Text("Logging")
                    } footer: {
                        Text("Vaginal dryness, urinary urgency, and pain during sex. You can hide this category if you prefer not to track it.")
                    }
                }

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
                    .accessibilityLabel("Require Authentication")
                    .accessibilityHint("When enabled, you must authenticate with Face ID, Touch ID, or PIN to open the app")
                    .accessibilityIdentifier("settings.requireAuthToggle")

                    if securityService.isAuthenticationRequired {
                        if securityService.canUseBiometrics {
                            Button("Test Face ID/Touch ID") {
                                Task {
                                    _ = await securityService.authenticateWithBiometrics()
                                }
                            }
                            .foregroundColor(AppTheme.Colors.primaryBlue)
                            .accessibilityLabel("Test Face ID or Touch ID")
                            .accessibilityHint("Verify that biometric authentication is working correctly")
                            .accessibilityIdentifier("settings.testBiometricButton")
                        }

                        Button(hasPin ? "Change PIN" : "Set Up PIN") {
                            showingPinSetup = true
                        }
                        .foregroundColor(AppTheme.Colors.secondaryPink)
                        .accessibilityLabel(hasPin ? "Change PIN" : "Set Up PIN")
                        .accessibilityHint(hasPin ? "Replace your existing PIN with a new one" : "Create a PIN as a fallback to biometric authentication")
                        .accessibilityIdentifier("settings.pinButton")
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
                    
                    Link("Privacy Policy", destination: URL(string: "https://pjaol.github.io/safeflow/privacy")!)
                        .foregroundColor(AppTheme.Colors.deepGrayText)
                }
                
                #if DEBUG || BETA
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
                    .accessibilityIdentifier("settings.doneButton")
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
            .sheet(isPresented: $showingLifeStageGuide) {
                LifeStageGuideView(currentStage: $lifeStage)
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


#if DEBUG || BETA
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Example: Using your `SecurityServicePreview.shared` or a normal SecurityService
        SettingsView()
            .environmentObject(SecurityServicePreview.shared)
    }
}
#endif
