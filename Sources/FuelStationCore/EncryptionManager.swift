import Foundation
import CryptoKit
import Security

public enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case keyMissing
    /// The key exists only in memory, so anything encrypted with it would be
    /// unreadable on the next launch.
    case keyNotPersisted
}

public final class EncryptionManager: Sendable {
    public static let shared = EncryptionManager()

    private let key: SymmetricKey
    private let keyIsPersisted: Bool
    private static let keychainService = "com.fuelstation.encryption"
    private static let keychainAccount = "aes-key"

    private enum KeychainLookup {
        case found(SymmetricKey)
        case notFound
        case failed(OSStatus)
    }
    
    private init() {
        switch Self.lookupKey() {
        case .found(let existingKey):
            self.key = existingKey
            self.keyIsPersisted = true
        case .notFound:
            let newKey = SymmetricKey(size: .bits256)
            if Self.saveKeyToKeychain(newKey) {
                self.key = newKey
                self.keyIsPersisted = true
            } else if case .found(let stored) = Self.lookupKey() {
                // Another instance already stored a key: reuse it instead of
                // writing with an incompatible one.
                self.key = stored
                self.keyIsPersisted = true
            } else {
                logger.error("Keychain key could not be stored; encryption is unavailable this session")
                self.key = newKey
                self.keyIsPersisted = false
            }
        case .failed(let status):
            // Never replace a key we merely failed to read: doing so would make
            // every previously stored record permanently undecryptable.
            logger.error("Keychain read failed (status \(status)); encryption is unavailable this session")
            self.key = SymmetricKey(size: .bits256)
            self.keyIsPersisted = false
        }
    }

    public func encrypt(_ string: String) throws -> String {
        // Refuse to produce ciphertext that could never be decrypted again.
        guard keyIsPersisted else { throw EncryptionError.keyNotPersisted }
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
    
    @discardableResult
    private static func saveKeyToKeychain(_ key: SymmetricKey) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        // Only remove an item that we know is absent-safe to replace.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            logger.error("Keychain delete failed (status \(deleteStatus))")
            return false
        }
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            logger.error("Keychain add failed (status \(addStatus))")
            return false
        }
        return true
    }
    
    private static func lookupKey() -> KeychainLookup {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return .failed(errSecDecode) }
            return .found(SymmetricKey(data: data))
        case errSecItemNotFound:
            return .notFound
        default:
            return .failed(status)
        }
    }
}
