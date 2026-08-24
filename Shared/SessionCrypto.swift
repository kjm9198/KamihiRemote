import Foundation
import Security
import CryptoKit

enum KeychainStore {
    static func save(account: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.kamihi.remote",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.kamihi.remote",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.kamihi.remote",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct DeviceKeyPair {
    let privateKey: Curve25519.KeyAgreement.PrivateKey
    var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    static func loadOrCreate(account: String) -> DeviceKeyPair {
        if let data = KeychainStore.load(account: account),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) {
            return DeviceKeyPair(privateKey: key)
        }
        let key = Curve25519.KeyAgreement.PrivateKey()
        KeychainStore.save(account: account, data: key.rawRepresentation)
        return DeviceKeyPair(privateKey: key)
    }
}

enum SessionCrypto {
    static func deriveSessionKey(ourPrivate: Curve25519.KeyAgreement.PrivateKey, peerPublic: Data, salt: Data) throws -> SymmetricKey {
        let pub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublic)
        let shared = try ourPrivate.sharedSecretFromKeyAgreement(with: pub)
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data("kamihi.v3.session".utf8),
            outputByteCount: 32
        )
    }

    static func seal(plaintext: Data, key: SymmetricKey, nonceData: Data) throws -> Data {
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let box = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        return box.ciphertext + box.tag
    }

    static func open(ciphertextAndTag: Data, key: SymmetricKey, nonceData: Data) throws -> Data {
        guard ciphertextAndTag.count > 16 else { throw CryptoError.short }
        let cipher = ciphertextAndTag.dropLast(16)
        let tag = ciphertextAndTag.suffix(16)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipher, tag: tag)
        return try AES.GCM.open(box, using: key)
    }

    static func randomNonce() -> Data {
        var bytes = [UInt8](repeating: 0, count: 12)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    @discardableResult
    static func runSelfChecks() -> Bool {
        let a = Curve25519.KeyAgreement.PrivateKey()
        let b = Curve25519.KeyAgreement.PrivateKey()
        let salt = Data("kamihi-test".utf8)
        let keyA = try! deriveSessionKey(ourPrivate: a, peerPublic: b.publicKey.rawRepresentation, salt: salt)
        let keyB = try! deriveSessionKey(ourPrivate: b, peerPublic: a.publicKey.rawRepresentation, salt: salt)
        let nonce = randomNonce()
        let sealed = try! seal(plaintext: Data("MOVE 1 2".utf8), key: keyA, nonceData: nonce)
        let opened = try! open(ciphertextAndTag: sealed, key: keyB, nonceData: nonce)
        precondition(opened == Data("MOVE 1 2".utf8))
        do {
            var bad = sealed
            bad[0] ^= 0xFF
            _ = try open(ciphertextAndTag: bad, key: keyB, nonceData: nonce)
            preconditionFailure("tampered packet must fail")
        } catch {
            // fail closed
        }
        return true
    }

    enum CryptoError: Error { case short }
}

struct TrustedPeer: Codable, Equatable, Identifiable {
    var id: String { deviceID }
    var deviceID: String
    var displayName: String
    var publicKey: Data
    var lastUsed: Date
}

enum TrustedPeerStore {
    private static let account = "trusted-peers"

    static func load() -> [TrustedPeer] {
        guard let data = KeychainStore.load(account: account) else { return [] }
        return (try? JSONDecoder().decode([TrustedPeer].self, from: data)) ?? []
    }

    static func save(_ peers: [TrustedPeer]) {
        if let data = try? JSONEncoder().encode(peers) {
            KeychainStore.save(account: account, data: data)
        }
    }

    static func upsert(_ peer: TrustedPeer) {
        var peers = load().filter { $0.deviceID != peer.deviceID }
        peers.insert(peer, at: 0)
        save(peers)
    }

    static func revoke(_ deviceID: String) {
        save(load().filter { $0.deviceID != deviceID })
        KeychainStore.delete(account: "session-\(deviceID)")
    }

    static func contains(_ deviceID: String) -> Bool {
        load().contains { $0.deviceID == deviceID }
    }
}
