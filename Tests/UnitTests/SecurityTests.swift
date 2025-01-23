import XCTest
@testable import safeflow

final class SecurityTests: XCTestCase {
    var securityService: SecurityService!
    var securityManager: SecurityManager!
    
    override func setUp() async throws {
        securityService = await SecurityService()
        securityManager = SecurityManager.shared
    }
    
    override func tearDown() async throws {
        // Clear any stored PIN
        try? clearKeychainData()
        UserDefaults.standard.removeObject(forKey: "isAuthenticationRequired")
        securityService = nil
    }
    
    @MainActor
    func testPINManagement() async throws {
        // Test PIN storage
        let storedPinResult = try await securityService.setPin("1234")
        XCTAssertTrue(storedPinResult, "Should successfully store PIN")
        
        let hasPinResult = try await securityManager.hasPin()
        XCTAssertTrue(hasPinResult, "Should have PIN stored")
        
        // Test PIN validation
        let authSuccess = try await securityService.authenticateWithPin("1234")
        XCTAssertTrue(authSuccess, "Should authenticate with correct PIN")
        
        let authFail = try await securityService.authenticateWithPin("4321")
        XCTAssertFalse(authFail, "Should not authenticate with incorrect PIN")
        
        // Test PIN update
        let updateResult = try await securityService.setPin("5678")
        XCTAssertTrue(updateResult, "Should successfully update PIN")
        
        let newPinAuth = try await securityService.authenticateWithPin("5678")
        XCTAssertTrue(newPinAuth, "Should authenticate with new PIN")
        
        let oldPinAuth = try await securityService.authenticateWithPin("1234")
        XCTAssertFalse(oldPinAuth, "Should not authenticate with old PIN")
    }
    
    @MainActor
    func testAuthenticationState() async throws {
        XCTAssertFalse(securityService.isUnlocked, "Should start in locked state")
        
        // Test PIN authentication
        let setPinResult = try await securityService.setPin("1234")
        XCTAssertTrue(setPinResult, "Should set up PIN")
        
        let authResult = try await securityService.authenticateWithPin("1234")
        XCTAssertTrue(authResult, "Should unlock with correct PIN")
        XCTAssertTrue(securityService.isUnlocked, "Should be unlocked after successful authentication")
        
        securityService.lock()
        XCTAssertFalse(securityService.isUnlocked, "Should be locked after calling lock()")
    }
    
    @MainActor
    func testAuthenticationRequirement() async throws {
        XCTAssertFalse(securityService.isAuthenticationRequired, "Should not require authentication by default")
        
        securityService.isAuthenticationRequired = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "isAuthenticationRequired"), "Should persist authentication requirement")
        
        // Create new instance to test persistence
        let newService = await SecurityService()
        XCTAssertTrue(newService.isAuthenticationRequired, "Should load persisted authentication requirement")
    }
    
    @MainActor
    func testSessionTimeout() async throws {
        // Set up authentication
        securityService.isAuthenticationRequired = true
        let setPinResult = try await securityService.setPin("1234")
        XCTAssertTrue(setPinResult, "Should set up PIN")
        
        let authResult = try await securityService.authenticateWithPin("1234")
        XCTAssertTrue(authResult, "Should authenticate")
        
        // Fast-forward time to simulate inactivity
        try await Task.sleep(for: .seconds(605)) // Just over 10 minutes
        
        let shouldAuth = securityManager.shouldRequireAuthentication()
        XCTAssertTrue(shouldAuth, "Should require authentication after timeout")
    }
    
    // MARK: - Helper Methods
    
    private func clearKeychainData() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "com.thevgergroup.safeflow.pin"
        ]
        SecItemDelete(query as CFDictionary)
    }
} 