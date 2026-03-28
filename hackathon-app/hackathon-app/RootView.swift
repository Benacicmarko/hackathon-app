//
//  RootView.swift
//  hackathon-app
//
//  App shell: login until authenticated, then main experience.
//

import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainView()
            } else {
                LoginView(
                    onGoogleSignIn: { session.completeSignIn() },
                    onEmailContinue: { _ in session.completeSignIn() },
                    onSignUp: { session.completeSignIn() }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isAuthenticated)
    }
}

#Preview {
    RootView()
        .environment(AppSession())
}
