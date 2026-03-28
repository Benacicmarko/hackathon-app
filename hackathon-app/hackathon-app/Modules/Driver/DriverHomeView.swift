//
//  DriverHomeView.swift
//  hackathon-app
//

import SwiftUI

struct DriverHomeView: View {
    @Bindable var store: DriverRideStore

    var body: some View {
        Group {
            if store.showsEmptyDriverHub {
                emptyHub
            } else if store.isComposingRide {
                DriverRideCreationView(store: store)
            } else if store.activeRide != nil {
                DriverScheduledRideView(store: store)
            }
        }
        .navigationTitle("Driving")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyHub: some View {
        ContentUnavailableView {
            Label("Driving", systemImage: "car.fill")
        } description: {
            Text("Create a ride to share your commute. Passengers will see it once you publish.")
        } actions: {
            Button("Create ride") {
                store.startCreatingRide()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Empty hub") {
    NavigationStack {
        DriverHomeView(store: DriverRideStore())
    }
}
