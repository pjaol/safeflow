import SwiftUI

struct PinSetupView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Enter PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode) // Prevents keychain suggestions
                    
                    if showingConfirmation {
                        SecureField("Confirm PIN", text: $confirmPin)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                } footer: {
                    Text("PIN must be at least 4 digits")
                        .foregroundColor(.secondary)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(showingConfirmation ? "Confirm PIN" : "Set Up PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(showingConfirmation ? "Save" : "Next") {
                        if !showingConfirmation {
                            validateFirstPin()
                        } else {
                            Task {
                                await savePin()
                            }
                        }
                    }
                    .disabled(!isPinValid || isSaving)
                }
            }
        }
    }
    
    private var isPinValid: Bool {
        if showingConfirmation {
            return pin.count >= 4 && confirmPin.count >= 4
        }
        return pin.count >= 4
    }
    
    private func validateFirstPin() {
        guard pin.count >= 4 else {
            errorMessage = "PIN must be at least 4 digits"
            return
        }
        
        showingConfirmation = true
        errorMessage = nil
    }
    
    private func savePin() async {
        guard pin == confirmPin else {
            errorMessage = "PINs don't match"
            showingConfirmation = false
            confirmPin = ""
            return
        }
        
        isSaving = true
        do {
            if try await securityService.setPin(pin) {
                dismiss()
            } else {
                errorMessage = "Failed to save PIN"
                showingConfirmation = false
                pin = ""
                confirmPin = ""
            }
        } catch {
            errorMessage = "Error saving PIN: \(error.localizedDescription)"
            showingConfirmation = false
            pin = ""
            confirmPin = ""
        }
        isSaving = false
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
                }
                
                if let error = securityService.authenticationError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
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
                }
            }
        }
    }
}

#Preview {
    PinSetupView()
        .environmentObject(SecurityServicePreview.createPreview())
} 