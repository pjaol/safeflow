import SwiftUI

struct PinSetupView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var isSettingPin = false
    @State private var showingConfirmation = false
    @State private var localError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Enter PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(AppTheme.Typography.bodyFont)
                        .accessibilityLabel("PIN")
                        .accessibilityHint("Enter a numeric PIN of at least 4 digits")
                        .accessibilityIdentifier("pinSetup.pinField")
                }

                if showingConfirmation {
                    Section {
                        SecureField("Confirm PIN", text: $confirmPin)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(AppTheme.Typography.bodyFont)
                            .accessibilityLabel("Confirm PIN")
                            .accessibilityHint("Re-enter your PIN to confirm it")
                            .accessibilityIdentifier("pinSetup.confirmPinField")
                    }
                }
                
                if let error = securityService.authenticationError ?? localError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(AppTheme.Typography.captionFont)
                    }
                }
            }
            .navigationTitle("Set Up PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showingConfirmation ? "Save" : "Next") {
                        if showingConfirmation {
                            if pin == confirmPin {
                                Task {
                                    isSettingPin = true
                                    localError = nil
                                    do {
                                        if try await securityService.setPin(pin) {
                                            dismiss()
                                        }
                                    } catch {
                                        localError = error.localizedDescription
                                    }
                                    isSettingPin = false
                                }
                            } else {
                                localError = "PINs do not match"
                            }
                        } else {
                            if pin.count >= 4 {
                                showingConfirmation = true
                                localError = nil
                            } else {
                                localError = "PIN must be at least 4 digits"
                            }
                        }
                    }
                    .disabled((!showingConfirmation && pin.count < 4) ||
                             (showingConfirmation && confirmPin.count < 4) ||
                             isSettingPin)
                    .foregroundColor(AppTheme.Colors.primaryBlue)
                    .accessibilityLabel(showingConfirmation ? "Save PIN" : "Next")
                    .accessibilityHint(showingConfirmation ? "Save your PIN and enable lock protection" : "Proceed to confirm your PIN")
                    .accessibilityIdentifier(showingConfirmation ? "pinSetup.saveButton" : "pinSetup.nextButton")
                }
            }
        }
    }
}

struct PinEntryView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Binding var isPresented: Bool
    @State private var pin = ""
    @State private var isAuthenticating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Enter PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(AppTheme.Typography.bodyFont)
                        .accessibilityLabel("PIN")
                        .accessibilityHint("Enter your PIN to unlock the app")
                        .accessibilityIdentifier("pinEntry.pinField")
                }

                if let error = securityService.authenticationError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(AppTheme.Typography.captionFont)
                    }
                }
            }
            .navigationTitle("Enter PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Unlock") {
                        Task {
                            isAuthenticating = true
                            do {
                                if try await securityService.authenticateWithPin(pin) {
                                    isPresented = false
                                }
                            } catch {
                                // Error shown via securityService.authenticationError
                            }
                            isAuthenticating = false
                        }
                    }
                    .disabled(pin.count < 4 || isAuthenticating)
                    .foregroundColor(AppTheme.Colors.primaryBlue)
                    .accessibilityLabel("Unlock")
                    .accessibilityHint("Submit your PIN to unlock the app")
                    .accessibilityIdentifier("pinEntry.unlockButton")
                }
            }
        }
    }
}

#if DEBUG || BETA
#Preview {
    PinSetupView()
        .environmentObject(SecurityServicePreview.createPreview())
}
#endif 