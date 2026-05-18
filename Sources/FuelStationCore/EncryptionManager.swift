import Foundation
import CryptoKit

public enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case keyMissing
}

public final class EncryptionManager: Sendable {
    public static let shared = EncryptionManager()
    
    // In a production app, this key should be stored in the Keychain.
    // For this prototype, we'll derive it from a persistent machine-specific identifier
    // or use a static salt (which is still better than plaintext).
    private let key: SymmetricKey
    
    private init() {
        // Simple key derivation for demonstration. 
        // Real apps use Keychain to store a randomly generated SymmetricKey.
        let secret = "fuelpump-station-manager-secure-salt"
        let salt = "static-salt-123".data(using: .utf8)!
        let keyData = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: secret.data(using: .utf8)!),
            salt: salt,
            outputByteCount: 32
        )
        self.key = keyData
    }
    
    public func encrypt(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else { throw EncryptionError.encryptionFailed }
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!.base64EncodedString()
    }
    
    public func decrypt(_ base64String: String) throws -> String {
        guard let data = Data(base64Encoded: base64String) else { throw EncryptionError.decryptionFailed }
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        guard let string = String(data: decryptedData, encoding: .utf8) else { throw EncryptionError.decryptionFailed }
        return string
    }
}
