import LocalAuthentication
import SwiftUI

@MainActor
class SecurityService: ObservableObject {
    @Published private(set) var isUnlocked = false {
        didSet {
            if isUnlocked {
                SecurityManager.shared.updateLastActiveDate()
            }
        }
    }
    
    @Published var isAuthenticationRequired: Bool {
        didSet {
            UserDefaults.standard.set(isAuthenticationRequired, forKey: "isAuthenticationRequired")
        }
    }
    
    @Published private(set) var authenticationError: String?
    
    private let context = LAContext()
    private let securityManager = SecurityManager.shared
    
    init() {
        self.isAuthenticationRequired = UserDefaults.standard.bool(forKey: "isAuthenticationRequired")
        
        NotificationCenter.default.addObserver(
            forName: .lockApp,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lock()
        }
        
        // Start a timer to check for inactivity
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isUnlocked && self.securityManager.shouldRequireAuthentication() {
                self.lock()
            }
        }
    }
    
    var canUseBiometrics: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    var hasFallbackPin: Bool {
        securityManager.hasPin()
    }
    
    func authenticateWithBiometrics() async -> Bool {
        guard canUseBiometrics else { return false }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock SafeFlow"
            )
            await MainActor.run { 
                isUnlocked = result
                authenticationError = nil
            }
            return result
        } catch {
            print("Authentication failed: \(error.localizedDescription)")
            await MainActor.run {
                authenticationError = error.localizedDescription
            }
            return false
        }
    }
    
    func authenticateWithPin(_ pin: String) -> Bool {
        do {
            let result = try securityManager.validatePin(pin)
            isUnlocked = result
            authenticationError = result ? nil : "Incorrect PIN"
            return result
        } catch {
            authenticationError = "Error validating PIN"
            return false
        }
    }
    
    func setPin(_ pin: String) -> Bool {
        do {
            try securityManager.storePin(pin)
            authenticationError = nil
            return true
        } catch {
            authenticationError = "Error saving PIN"
            return false
        }
    }
    
    func lock() {
        isUnlocked = false
    }
} 