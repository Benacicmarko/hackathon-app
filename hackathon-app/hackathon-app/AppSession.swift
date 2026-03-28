//
//  AppSession.swift
//  hackathon-app
//
//  Tracks signed-in state for root → login → main flow. Replace `completeSignIn`
//  with real Firebase Auth when wiring sign-in.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppSession {
    private(set) var isAuthenticated = false

    func completeSignIn() {
        isAuthenticated = true
    }

    func signOut() {
        isAuthenticated = false
    }
}
