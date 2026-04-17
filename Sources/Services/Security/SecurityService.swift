import LocalAuthentication
import SwiftUI

@MainActor
class SecurityService: ObservableObject {
    /// The current authentication state
    @Published private(set) var isUnlocked = false {
        didSet {
            if isUnlocked {
                securityManager.updateLastActiveDate()
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
    private let securityManager: SecurityManager
    private var backgroundTask: Task<Void, Never>?
    
    // Consider moving this to a configuration object
    private let backgroundCheckInterval: TimeInterval = 1.0
    
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
            UserDefaults.standard.set(false, forKey: "isAuthenticationRequired")
        }
        #endif
        self.isAuthenticationRequired = UserDefaults.standard.bool(forKey: "isAuthenticationRequired")
        self.securityManager = SecurityManager.shared
        
        NotificationCenter.default.addObserver(
            forName: .lockApp,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }
    
    func configure() async {
        // Set up initial authentication if required
        if isAuthenticationRequired {
            if canUseBiometrics {
                _ = await authenticateWithBiometrics()
            } else if await hasFallbackPin {
                // Don't auto-authenticate with PIN, let user enter it
                authenticationError = nil
            } else {
                // No authentication method set up yet — treat as no security
                isAuthenticationRequired = false
                isUnlocked = true
            }
        } else {
            // No security configured, app is accessible
            isUnlocked = true
        }
        setupBackgroundCheck()
    }
    
    private func setupBackgroundCheck() {
        backgroundTask?.cancel()
        backgroundTask = Task(priority: .background)  { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                do {
                    try await Task.sleep(for: .seconds(self.backgroundCheckInterval))
                    self.checkAuthenticationStatus()
                }catch {
                    print("Error during background check: \(error)")
                    break
                }
            }
        }
    }
    
    @MainActor
    private func checkAuthenticationStatus() {
        if isUnlocked && securityManager.shouldRequireAuthentication() {
            lock()
        }
    }
    
    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if let error = error {
            print("Biometrics error: \(error.localizedDescription)")
        }
        
        return canEvaluate
    }
    
    var hasFallbackPin: Bool {
        get async  {
            securityManager.hasPin()
        }
    }
    
    func authenticateWithBiometrics() async -> Bool {
        guard canUseBiometrics else { return false }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Clio Daye"
            )
            isUnlocked = result
            authenticationError = nil
            return result
        } catch {
            print("Authentication failed: \(error.localizedDescription)")
            authenticationError = error.localizedDescription
            return false
        }
    }
    
    func authenticateWithPin(_ pin: String) async throws -> Bool {
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
    
    func setPin(_ pin: String) async throws -> Bool {
        do {
            try securityManager.storePin(pin)
            authenticationError = nil
            isUnlocked = true  // Auto-unlock after setting PIN
            return true
        } catch {
            authenticationError = "Error saving PIN"
            return false
        }
    }
    
    func lock() {
        isUnlocked = false
    }

    func skipSecurity() {
        isAuthenticationRequired = false
        isUnlocked = true
    }
}

// MARK: - Preview Subclass

#if DEBUG || BETA
@MainActor
class SecurityServicePreview: SecurityService {
    override func configure() async {
        // Call the real configure
        await super.configure()
        // Set something for preview
        self.isAuthenticationRequired = true
    }
    
    /// An example shared instance for SwiftUI Previews
    static let shared = SecurityServicePreview()
    
    static func createPreview() -> SecurityServicePreview {
        SecurityServicePreview()
    }
}
#endif

// MARK: - Task.sync using @unchecked Sendable reference type

#if DEBUG
/// A simple reference type that we mark as @unchecked Sendable,
/// meaning we (the developers) promise to handle thread safety.
final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}

enum TaskError: Error {
    case timeout
}

/**
 Bridges an async/throws operation back to a synchronous call using a semaphore.

 **Warning**: This can block threads, including the main thread,
 which can lead to deadlocks if the async code also needs the main actor.
 It is here only for special scenarios (like certain SwiftUI previews or test code).
 Do *not* use in normal production code.
 */
extension Task where Success == Never, Failure == Never {
    static func sync<T>(
        operation: @escaping @Sendable () async throws -> T,
        timeout: TimeInterval = 30
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = Box<T?>(nil)
        let errorBox = Box<Error?>(nil)
        
        let task = Task {
            do {
                resultBox.value = try await operation()
            } catch {
                errorBox.value = error
            }
            semaphore.signal()
            
            // Keep the task alive without throwing
            while true {
                do {
                    try await Task.sleep(nanoseconds: UInt64.max)
                } catch {
                    continue // If cancelled, just continue the loop
                }
            }
        }
        
        switch semaphore.wait(timeout: .now() + timeout) {
        case .success:
            if let error = errorBox.value {
                throw error
            }
            if let result = resultBox.value {
                return result
            }
            throw TaskError.timeout
        case .timedOut:
            task.cancel()
            throw TaskError.timeout
        }
    }
}
#endif
