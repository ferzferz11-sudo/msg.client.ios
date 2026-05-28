import Foundation
import CryptoKit

// MARK: - Crypto Errors

enum CryptoError: Error, LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case invalidCiphertext
    case invalidKeySize(expected: Int, got: Int)
    case decryptionFailed
    case serviceMarker

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate cryptographic key"
        case .encryptionFailed:
            return "Encryption operation failed"
        case .invalidCiphertext:
            return "Ciphertext is too short or malformed"
        case .invalidKeySize(let expected, let got):
            return "Invalid key size: expected \(expected) bytes, got \(got)"
        case .decryptionFailed:
            return "Decryption operation failed"
        case .serviceMarker:
            return "Service marker detected"
        }
    }
}

// MARK: - Service Markers

/// Special markers that may arrive in place of actual encrypted data.
/// These mirror the server-side crypto.go service markers.
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

// MARK: - Server-Side AES-256 Encryption (matches crypto.go)

/// Server-side encryption using AES-256-GCM.
/// This matches the Go server's crypto.go implementation:
///   - 32-byte key from CHAT_SECRET_KEY env var
///   - AES-GCM with random nonce prepended to ciphertext
final class CryptoManager {

    static let shared = CryptoManager()

    private let key: SymmetricKey

    init() {
        // Read key from environment variable CHAT_SECRET_KEY
        // Must be exactly 32 bytes for AES-256
        let keyString = ProcessInfo.processInfo.environment["CHAT_SECRET_KEY"] ?? ""
        let keyData = Data(keyString.utf8)

        if keyData.count == 32 {
            self.key = SymmetricKey(data: keyData)
        } else {
            // Fallback: derive a 32-byte key using SHA-256
            // In production, CHAT_SECRET_KEY must be set correctly
            let hash = SHA256.hash(data: keyData)
            self.key = SymmetricKey(data: hash)
        }
    }

    /// Initialize with a specific 32-byte key
    init(keyData: Data) throws {
        guard keyData.count == 32 else {
            throw CryptoError.invalidKeySize(expected: 32, got: keyData.count)
        }
        self.key = SymmetricKey(data: keyData)
    }

    // MARK: - Encrypt

    /// Encrypt plaintext using AES-256-GCM.
    /// Returns nonce + ciphertext as a single Data blob (matches Go's gcm.Seal behavior).
    func encrypt(_ plaintext: String) throws -> Data {
        let plaintextData = Data(plaintext.utf8)
        let nonce = AES.GCM.Nonce()

        do {
            let sealedBox = try AES.GCM.seal(plaintextData, using: key, nonce: nonce)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            // combined = nonce + ciphertext + tag
            return combined
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    /// Encrypt and return Base64-encoded string (for E2EE payload)
    func encryptToBase64(_ plaintext: String) throws -> String {
        let data = try encrypt(plaintext)
        return data.base64EncodedString()
    }

    // MARK: - Decrypt

    /// Decrypt ciphertext (nonce + ciphertext + tag) using AES-256-GCM.
    func decrypt(_ ciphertext: Data) throws -> String {
        // Check for service markers (raw bytes)
        if let str = String(data: ciphertext, encoding: .utf8),
           let marker = ServiceMarker(rawValue: str) {
            return marker.displayText
        }

        guard ciphertext.count > 12 else {
            throw CryptoError.invalidCiphertext
        }

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

    /// Decrypt from Base64-encoded string
    func decryptFromBase64(_ base64: String) throws -> String {
        guard let data = Data(base64Encoded: base64) else {
            throw CryptoError.invalidCiphertext
        }
        return try decrypt(data)
    }

    // MARK: - E2EE: AES-256-GCM with Shared Secret

    /// Encrypt a message for E2EE secret chat using a shared secret key.
    /// sharedSecret must be exactly 32 bytes.
    /// Returns Base64(nonce + ciphertext + tag).
    func encryptE2EE(plaintext: String, sharedSecret: Data) throws -> String {
        guard sharedSecret.count == 32 else {
            throw CryptoError.invalidKeySize(expected: 32, got: sharedSecret.count)
        }

        let e2eeKey = SymmetricKey(data: sharedSecret)
        let plaintextData = Data(plaintext.utf8)
        let nonce = AES.GCM.Nonce()

        do {
            let sealedBox = try AES.GCM.seal(plaintextData, using: e2eeKey, nonce: nonce)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined.base64EncodedString()
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    /// Decrypt an E2EE message using a shared secret key.
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

    /// Derive a 32-byte key from ECDH raw secret + chat ID (HKDF-like).
    /// Matches Android's E2EEManager deriveAndStoreSharedSecret.
    func deriveChatKey(sharedSecret: Data, chatId: String) -> Data {
        var combined = Data()
        combined.append(sharedSecret)
        combined.append(Data(chatId.utf8))
        let hash = SHA256.hash(data: combined)
        return Data(hash)
    }

    /// Compute fingerprint for key verification (SHA-256 of key, first 10 bytes as hex)
    func computeFingerprint(key: Data) -> String {
        let hash = SHA256.hash(data: key)
        let prefix = Data(hash.prefix(10))
        return prefix.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    // MARK: - ECDH Key Generation

    /// Generate an ECDH P-256 key pair for E2EE.
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

    /// Export public key as raw data (X9.63 format).
    static func exportPublicKey(_ publicKey: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            return nil
        }
        return data as Data
    }

    /// Import public key from raw data.
    static func importPublicKey(_ data: Data) -> SecKey? {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else {
            return nil
        }
        return key
    }

    // MARK: - Password Hashing (bcrypt via CommonCrypto or fallback)

    /// Hash a password using a secure algorithm.
    /// Note: bcrypt is not natively available in iOS. We use PBKDF2 as a client-side pre-hash.
    /// The server does the actual bcrypt hashing.
    func prehashPassword(_ password: String, salt: Data? = nil) -> (hash: Data, salt: Data) {
        let actualSalt = salt ?? {
            var bytes = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            return Data(bytes)
        }()

        let passwordData = Data(password.utf8)
        var derivedKey = [UInt8](repeating: 0, count: 32)

        _ = passwordData.withUnsafeBytes { passwordPtr in
            actualSalt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                    passwordData.count,
                    saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    actualSalt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    10_000,
                    &derivedKey,
                    derivedKey.count
                )
            }
        }

        return (hash: Data(derivedKey), salt: actualSalt)
    }
}

// MARK: - CommonCrypto Bridge

import CommonCrypto
