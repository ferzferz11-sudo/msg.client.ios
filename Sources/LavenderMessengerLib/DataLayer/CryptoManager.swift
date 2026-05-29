import Foundation
import CryptoKit

// MARK: - Crypto Errors

enum CryptoError: Error, LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case invalidCiphertext
    case invalidKeySize(expected: Int, got: Int)
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Failed to generate cryptographic key"
        case .encryptionFailed: return "Encryption operation failed"
        case .invalidCiphertext: return "Ciphertext is too short or malformed"
        case .invalidKeySize(let expected, let got): return "Invalid key size: expected \(expected), got \(got)"
        case .decryptionFailed: return "Decryption operation failed"
        }
    }
}

// MARK: - Service Markers

enum ServiceMarker: String {
    case voiceMessage = "SERVICE_VOICE_MSG"
    case mediaMessage = "SERVICE_MEDIA_MSG"
    case fixedByMaintenance = "FIXED_BY_MAINTENANCE"
    case corruptedFix = "CORRUPTED_FIX"
    case emptyFix = "EMPTY_FIX"

    var displayText: String {
        switch self {
        case .voiceMessage: return "Voice message"
        case .mediaMessage: return "Image"
        case .fixedByMaintenance, .corruptedFix, .emptyFix: return "Message"
        }
    }
}

// MARK: - Crypto Manager

final class CryptoManager: @unchecked Sendable {

    static let shared = CryptoManager()

    private let key: SymmetricKey

    init() {
        let keyString = ProcessInfo.processInfo.environment["CHAT_SECRET_KEY"] ?? ""
        let keyData = Data(keyString.utf8)
        if keyData.count == 32 {
            self.key = SymmetricKey(data: keyData)
        } else {
            let hash = SHA256.hash(data: keyData)
            self.key = SymmetricKey(data: hash)
        }
    }

    init(keyData: Data) throws {
        guard keyData.count == 32 else {
            throw CryptoError.invalidKeySize(expected: 32, got: keyData.count)
        }
        self.key = SymmetricKey(data: keyData)
    }

    // MARK: - Encrypt

    func encrypt(_ plaintext: String) throws -> Data {
        let plaintextData = Data(plaintext.utf8)
        let nonce = AES.GCM.Nonce()
        do {
            let sealedBox = try AES.GCM.seal(plaintextData, using: key, nonce: nonce)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    func encryptToBase64(_ plaintext: String) throws -> String {
        try encrypt(plaintext).base64EncodedString()
    }

    // MARK: - Decrypt

    func decrypt(_ ciphertext: Data) throws -> String {
        if let str = String(data: ciphertext, encoding: .utf8),
           let marker = ServiceMarker(rawValue: str) {
            return marker.displayText
        }
        guard ciphertext.count > 12 else { throw CryptoError.invalidCiphertext }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
            let plaintextData = try AES.GCM.open(sealedBox, using: key)
            guard let plaintext = String(data: plaintextData, encoding: .utf8) else {
                throw CryptoError.decryptionFailed
            }
            return plaintext
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    func decryptFromBase64(_ base64: String) throws -> String {
        guard let data = Data(base64Encoded: base64) else {
            throw CryptoError.invalidCiphertext
        }
        return try decrypt(data)
    }

    // MARK: - E2EE

    func encryptE2EE(plaintext: String, sharedSecret: Data) throws -> String {
        guard sharedSecret.count == 32 else {
            throw CryptoError.invalidKeySize(expected: 32, got: sharedSecret.count)
        }
        let e2eeKey = SymmetricKey(data: sharedSecret)
        let plaintextData = Data(plaintext.utf8)
        let nonce = AES.GCM.Nonce()
        do {
            let sealedBox = try AES.GCM.seal(plaintextData, using: e2eeKey, nonce: nonce)
            guard let combined = sealedBox.combined else { throw CryptoError.encryptionFailed }
            return combined.base64EncodedString()
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    func decryptE2EE(encryptedBase64: String, sharedSecret: Data) throws -> String {
        guard sharedSecret.count == 32 else {
            throw CryptoError.invalidKeySize(expected: 32, got: sharedSecret.count)
        }
        guard let combined = Data(base64Encoded: encryptedBase64), combined.count > 12 else {
            throw CryptoError.invalidCiphertext
        }
        let e2eeKey = SymmetricKey(data: sharedSecret)
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let plaintextData = try AES.GCM.open(sealedBox, using: e2eeKey)
            guard let plaintext = String(data: plaintextData, encoding: .utf8) else {
                throw CryptoError.decryptionFailed
            }
            return plaintext
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    // MARK: - Key Derivation

    func deriveChatKey(sharedSecret: Data, chatId: String) -> Data {
        var combined = Data()
        combined.append(sharedSecret)
        combined.append(Data(chatId.utf8))
        return Data(SHA256.hash(data: combined))
    }

    func computeFingerprint(key: Data) -> String {
        let hash = SHA256.hash(data: key)
        return Data(hash.prefix(10)).map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    // MARK: - ECDH

    static func generateECDHKeyPair() -> (privateKey: SecKey, publicKey: SecKey) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            fatalError("Failed to generate ECDH key pair: \(error!.takeRetainedValue())")
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            fatalError("Failed to extract public key")
        }
        return (privateKey: privateKey, publicKey: publicKey)
    }

    static func exportPublicKey(_ publicKey: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        return SecKeyCopyExternalRepresentation(publicKey, &error) as Data?
    }

    static func importPublicKey(_ data: Data) -> SecKey? {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]
        var error: Unmanaged<CFError>?
        return SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error)
    }
}
