import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case invalidData
    }
    
    private let service = "com.rubenreut.momentum"
    
    // MARK: - Save to Keychain
    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Try to save
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - Retrieve from Keychain
    func retrieve(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    // MARK: - Delete from Keychain
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - API Key Management
    private let apiKeyAccount = "cloudflare-worker-api-key"
    
    var apiKey: String? {
        get {
            // Only check Keychain - no fallback to avoid circular dependency
            return retrieve(for: apiKeyAccount)
        }
        set {
            if let newValue = newValue {
                try? save(newValue, for: apiKeyAccount)
            } else {
                try? delete(for: apiKeyAccount)
            }
        }
    }
    
    // Store API key on first launch
    func setupAPIKeyIfNeeded() {
        if retrieve(for: apiKeyAccount) == nil {
            // Use environment variable or hardcoded value for development
            #if DEBUG
            // Try environment variable first, then fall back to development key
            let initialSecret = ProcessInfo.processInfo.environment["MOMENTUM_API_SECRET"] ?? "vvfKIj+7lsvmuTEmxtcNo0hKT7dakkn5vR/2UWkc1to="
            apiKey = initialSecret
            #else
            // In production, this should be set via CI/CD or manually
            // For now, use the existing secret
            let productionSecret = "vvfKIj+7lsvmuTEmxtcNo0hKT7dakkn5vR/2UWkc1to="
            apiKey = productionSecret
            #endif
        }
    }
}