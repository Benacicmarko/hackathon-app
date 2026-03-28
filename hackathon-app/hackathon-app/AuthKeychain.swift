//
//  AuthKeychain.swift
//  hackathon-app
//
//  Stores the latest Firebase ID token for your own API calls. Firebase Auth
//  already persists credentials in the Keychain; this is an app-level copy for
//  attaching Authorization headers. Cleared on sign-out.
//

import Foundation
import Security

enum AuthKeychain {
    private static let service = "com.andreflego.hackathon-app.auth"
    private static let idTokenAccount = "firebase_id_token"

    static func storeIDToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: idTokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func idToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: idTokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clearIDToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: idTokenAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
