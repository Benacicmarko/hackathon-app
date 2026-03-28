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
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if store.isComposingRide {
                DriverRideCreationView(store: store)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if store.activeRide != nil {
                DriverScheduledRideView(store: store)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.showsEmptyDriverHub)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.isComposingRide)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.activeRide?.id)
        .navigationTitle("Driving")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyHub: some View {
        ContentUnavailableView {
            Label("Driving", systemImage: "car.fill")
        } description: {
            Text("Create a ride to share your commute. Passengers will see it once you publish.")
        } actions: {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    store.startCreatingRide()
                }
            } label: {
                Label("Create ride", systemImage: "plus.circle.fill")
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
