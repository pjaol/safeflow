import SwiftUI

struct PinSetupView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var isSettingPin = false
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Enter PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(AppTheme.Typography.bodyFont)
                }
                
                if showingConfirmation {
                    Section {
                        SecureField("Confirm PIN", text: $confirmPin)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(AppTheme.Typography.bodyFont)
                    }
                }
                
                if let error = securityService.authenticationError {
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(showingConfirmation ? "Save" : "Next") {
                        if showingConfirmation {
                            if pin == confirmPin {
                                Task {
                                    isSettingPin = true
                                    do {
                                        try await securityService.setFallbackPin(pin)
                                        dismiss()
                                    } catch {
                                        // Error will be shown through securityService.authenticationError
                                    }
                                    isSettingPin = false
                                }
                            } else {
                                securityService.authenticationError = "PINs do not match"
                            }
                        } else {
                            showingConfirmation = true
                        }
                    }
                    .disabled((!showingConfirmation && pin.count < 4) || 
                             (showingConfirmation && confirmPin.count < 4) ||
                             isSettingPin)
                    .foregroundColor(AppTheme.Colors.primaryBlue)
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
        NavigationView {
            Form {
                Section {
                    SecureField("Enter PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(AppTheme.Typography.bodyFont)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock") {
                        Task {
                            isAuthenticating = true
                            do {
                                if try await securityService.authenticateWithPin(pin) {
                                    // Successful authentication
                                    isPresented = false
                                }
                            } catch {
                                // Error will be shown through securityService.authenticationError
                            }
                            isAuthenticating = false
                        }
                    }
                    .disabled(pin.count < 4 || isAuthenticating)
                    .foregroundColor(AppTheme.Colors.primaryBlue)
                }
            }
        }
    }
}

#Preview {
    PinSetupView()
        .environmentObject(SecurityServicePreview.createPreview())
} 