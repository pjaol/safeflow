import SwiftUI

struct PinSetupView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    
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
            .navigationTitle("Set Up PIN")
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
                            savePin()
                        }
                    }
                    .disabled(!isPinValid)
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
    
    private func savePin() {
        guard pin == confirmPin else {
            errorMessage = "PINs don't match"
            return
        }
        
        if securityService.setPin(pin) {
            dismiss()
        }
    }
}

struct PinEntryView: View {
    @EnvironmentObject private var securityService: SecurityService
    @Binding var isPresented: Bool
    @State private var pin = ""
    
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
                        if securityService.authenticateWithPin(pin) {
                            isPresented = false
                        }
                    }
                    .disabled(pin.count < 4)
                }
            }
        }
    }
}

#Preview {
    PinSetupView()
        .environmentObject(SecurityService())
} 