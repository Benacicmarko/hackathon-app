//
//  AppSession.swift
//  hackathon-app
//
//  Firebase Auth session: Google + email/password, ID token cache + Keychain,
//  and UserDefaults metadata. Enable Google in Firebase Console and use a
//  GoogleService-Info.plist that includes CLIENT_ID; set the URL scheme in
//  GoogleSignInURLScheme.plist to the same REVERSED_CLIENT_ID from that plist.
//

import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import Observation
import UIKit

@Observable
@MainActor
final class AppSession {
    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    private(set) var firebaseUser: User?
    private(set) var lastIDToken: String?
    private(set) var tokenExpiresAt: Date?
    private(set) var authError: String?
    private(set) var isAuthBusy = false

    var isAuthenticated: Bool { firebaseUser != nil }

    var userUID: String? { firebaseUser?.uid }

    var displayEmail: String? {
        guard let user = firebaseUser else { return nil }
        return user.isAnonymous ? nil : user.email
    }

    func clearAuthError() {
        authError = nil
    }

    /// Call once from the root view. Attaches the Firebase auth state listener.
    func start() {
        guard authListenerHandle == nil else { return }
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                await self.applyFirebaseUser(user)
            }
        }
    }

    func signInWithGoogle() async {
        isAuthBusy = true
        authError = nil
        defer { isAuthBusy = false }

        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            authError =
                "Missing OAuth client ID. Download GoogleService-Info.plist from Firebase (it must include CLIENT_ID) and add the Google URL scheme."
            return
        }

        if GIDSignIn.sharedInstance.configuration?.clientID != clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        guard let presenter = UIApplication.shared.topMostViewController() else {
            authError = "Could not present Google sign-in."
            return
        }

        do {
            let gidResult = try await signInWithGooglePresenting(presenter)
            let user = gidResult.user
            guard let idToken = user.idToken?.tokenString else {
                authError = "Google did not return an ID token."
                return
            }
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            let ns = error as NSError
            if ns.domain == "com.google.GIDSignIn", ns.code == -5 {
                return
            }
            authError = error.localizedDescription
        }
    }

    func signInWithEmail(email: String, password: String) async {
        isAuthBusy = true
        authError = nil
        defer { isAuthBusy = false }
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            authError = mapAuthError(error)
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        isAuthBusy = true
        authError = nil
        defer { isAuthBusy = false }
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            authError = mapAuthError(error)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            authError = error.localizedDescription
        }
    }

    /// Refreshes the cached ID token and Keychain copy (call before API requests if needed).
    func refreshIDToken(forceRefresh: Bool = false) async {
        guard let user = Auth.auth().currentUser else { return }
        await persistTokens(for: user, forceRefresh: forceRefresh)
    }

    /// Latest Firebase ID token for your backend (`Authorization: Bearer …`). Prefer `lastIDToken` after sign-in; this falls back to Keychain.
    func bearerTokenForAPI() -> String? {
        lastIDToken ?? AuthKeychain.idToken()
    }

    // MARK: - Private

    private func applyFirebaseUser(_ user: User?) async {
        firebaseUser = user
        if let user {
            SessionMetadataStore.save(
                uid: user.uid,
                email: user.email,
                providerID: user.providerData.first?.providerID
            )
            await persistTokens(for: user, forceRefresh: false)
        } else {
            lastIDToken = nil
            tokenExpiresAt = nil
            AuthKeychain.clearIDToken()
            SessionMetadataStore.clear()
        }
    }

    private func persistTokens(for user: User, forceRefresh: Bool) async {
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: forceRefresh)
            let token = try await user.getIDToken(forcingRefresh: forceRefresh)
            lastIDToken = token
            tokenExpiresAt = result.expirationDate
            AuthKeychain.storeIDToken(token)
        } catch {
            authError = error.localizedDescription
        }
    }

    private func mapAuthError(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == AuthErrorDomain else {
            return error.localizedDescription
        }
        switch ns.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "That email is already registered. Try signing in instead."
        case AuthErrorCode.invalidEmail.rawValue:
            return "That email address does not look valid."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password is too weak. Use at least 6 characters."
        case AuthErrorCode.wrongPassword.rawValue, AuthErrorCode.invalidCredential.rawValue:
            return "Incorrect email or password."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account for that email. Try signing up."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Check your connection."
        default:
            return error.localizedDescription
        }
    }

    private func signInWithGooglePresenting(_ presenter: UIViewController) async throws -> GIDSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: NSError(
                        domain: "GoogleSignIn",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Sign-in returned no result."]
                    ))
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }
}
