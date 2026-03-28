//
//  MainView.swift
//  hackathon-app
//
//  Created by Andre Flego on 28.03.2026..
//

import SwiftUI

struct MainView: View {
    @Environment(AppSession.self) private var session
    @Environment(DriverRideStore.self) private var driverRideStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DriverHomeView(store: driverRideStore)
                    } label: {
                        Label("Schedule a ride", systemImage: "calendar.badge.plus")
                    }
                    NavigationLink {
                        CarpoolHomeView()
                    } label: {
                        Label("Carpool a ride", systemImage: "person.3.fill")
                    }
                } header: {
                    Text("Choose an option")
                } footer: {
                    Text("Schedule when you’re driving and have empty seats. Carpool when you need a ride with someone else.")
                }

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

/// Placeholder for the passenger / “need a ride” flow (matching, apply, status).
struct CarpoolHomeView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Carpool a ride", systemImage: "person.3.fill")
        } description: {
            Text("Enter where you’re going and find drivers with a matching commute. This flow will connect here next.")
        }
        .navigationTitle("Carpool")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MainView()
        .environment(AppSession())
        .environment(DriverRideStore())
}
