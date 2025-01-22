import Foundation
import Security
import SwiftUI

class SecurityManager {
    private enum KeychainKey: String {
        case pin = "com.thevgergroup.safeflow.pin"
    }
    
    static let shared = SecurityManager()
    
    private let defaults = UserDefaults.standard
    private let inactivityTimeout: TimeInterval = 600 // 10 minutes
    private let backgroundTimeout: TimeInterval = 120 // 2 minutes
    
    private var lastActiveDate: Date?
    private var backgroundDate: Date?
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.backgroundDate = Date()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkBackgroundTimeout()
        }
    }
    
    func updateLastActiveDate() {
        lastActiveDate = Date()
    }
    
    func shouldRequireAuthentication() -> Bool {
        guard let lastActive = lastActiveDate else { return true }
        return Date().timeIntervalSince(lastActive) >= inactivityTimeout
    }
    
    private func checkBackgroundTimeout() {
        guard let backgroundDate = backgroundDate else { return }
        if Date().timeIntervalSince(backgroundDate) >= backgroundTimeout {
            NotificationCenter.default.post(name: .lockApp, object: nil)
        }
    }
    
    func storePin(_ pin: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeychainKey.pin.rawValue,
            kSecValueData as String: pin.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            try updatePin(pin)
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func updatePin(_ pin: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeychainKey.pin.rawValue
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: pin.data(using: .utf8)!
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func validatePin(_ pin: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeychainKey.pin.rawValue,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let storedPin = String(data: data, encoding: .utf8)
        else {
            return false
        }
        
        return pin == storedPin
    }
    
    func hasPin() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeychainKey.pin.rawValue,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }
}

enum KeychainError: Error {
    case unhandledError(status: OSStatus)
}

extension Notification.Name {
    static let lockApp = Notification.Name("com.thevgergroup.safeflow.lockApp")
} 