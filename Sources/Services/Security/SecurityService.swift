import LocalAuthentication
import SwiftUI

@MainActor
class SecurityService: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published var isAuthenticationRequired: Bool {
        didSet {
            UserDefaults.standard.set(isAuthenticationRequired, forKey: "isAuthenticationRequired")
        }
    }
    
    private let context = LAContext()
    
    init() {
        self.isAuthenticationRequired = UserDefaults.standard.bool(forKey: "isAuthenticationRequired")
    }
    
    var canUseBiometrics: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticateWithBiometrics() async -> Bool {
        guard canUseBiometrics else { return false }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock SafeFlow"
            )
            await MainActor.run { isUnlocked = result }
            return result
        } catch {
            print("Authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func lock() {
        isUnlocked = false
    }
} 