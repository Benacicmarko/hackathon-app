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
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isAuthenticated)
        .task {
            session.start()
        }
    }
}

#Preview {
    RootView()
        .environment(AppSession())
}
