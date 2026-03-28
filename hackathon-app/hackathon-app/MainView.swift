//
//  MainView.swift
//  hackathon-app
//
//  Created by Andre Flego on 28.03.2026..
//

import SwiftUI

struct MainView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        NavigationStack {
            List {
                Section("Signed in") {
                    if let email = session.displayEmail {
                        LabeledContent("Email", value: email)
                    }
                    if let uid = session.userUID {
                        LabeledContent("UID", value: uid)
                    }
                }

                Section("Session") {
                    if let exp = session.tokenExpiresAt {
                        LabeledContent("ID token expires") {
                            Text(exp, style: .date)
                        }
                    }
                    Button("Refresh ID token") {
                        Task { await session.refreshIDToken(forceRefresh: true) }
                    }
                    .disabled(session.isAuthBusy)
                }

                Section {
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity)
                    Text("Hello, world!")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Zagreb Flow")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        session.signOut()
                    }
                }
            }
            .overlay {
                if session.isAuthBusy {
                    ProgressView()
                }
            }
            .task {
                await session.refreshIDToken(forceRefresh: false)
            }
        }
    }
}

#Preview {
    MainView()
        .environment(AppSession())
}
