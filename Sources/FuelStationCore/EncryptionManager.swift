import Foundation
import CryptoKit
import Security

public enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case keyMissing
}

public final class EncryptionManager: Sendable {
    public static let shared = EncryptionManager()
    
    private let key: SymmetricKey
    private static let keychainService = "com.fuelstation.encryption"
    private static let keychainAccount = "aes-key"
    
    private init() {
        if let existingKey = Self.loadKeyFromKeychain() {
            self.key = existingKey
        } else {
            let newKey = SymmetricKey(size: .bits256)
            Self.saveKeyToKeychain(newKey)
            self.key = newKey
        }
    }
    
    public func encrypt(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else { throw EncryptionError.encryptionFailed }
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else { throw EncryptionError.encryptionFailed }
        return combined.base64EncodedString()
    }
    
    public func decrypt(_ base64String: String) throws -> String {
        guard let data = Data(base64Encoded: base64String) else { throw EncryptionError.decryptionFailed }
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        guard let string = String(data: decryptedData, encoding: .utf8) else { throw EncryptionError.decryptionFailed }
        return string
    }
    
    // MARK: - Keychain Helpers
    
    private static func saveKeyToKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private static func loadKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }
}
