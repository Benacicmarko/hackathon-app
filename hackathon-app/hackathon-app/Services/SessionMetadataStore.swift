//
//  SessionMetadataStore.swift
//  hackathon-app
//
//  Lightweight UserDefaults metadata (no secrets). Tokens live in Keychain via
//  AuthKeychain and in Firebase Auth’s own Keychain storage.
//

import Foundation

enum SessionMetadataStore {
    private static let uidKey = "session.firebase_uid"
    private static let emailKey = "session.email"
    private static let providerKey = "session.provider_id"

    static func save(uid: String, email: String?, providerID: String?) {
        let d = UserDefaults.standard
        d.set(uid, forKey: uidKey)
        d.set(email, forKey: emailKey)
        d.set(providerID, forKey: providerKey)
    }

    static func clear() {
        let d = UserDefaults.standard
        d.removeObject(forKey: uidKey)
        d.removeObject(forKey: emailKey)
        d.removeObject(forKey: providerKey)
    }
}
