//
//  PassengerHomeView.swift
//  hackathon-app
//

import SwiftUI

struct PassengerHomeView: View {
    @Bindable var store: PassengerRideStore

    var body: some View {
        Group {
            if store.showsEmptyPassengerHub {
                emptyHub
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if store.isRequestingRide {
                RideRequestFormView(store: store)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if store.phase == .viewingAvailableRides {
                AvailableRidesView(store: store)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if store.joinedRide != nil {
                JoinedRideView(store: store)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.showsEmptyPassengerHub)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.isRequestingRide)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.phase)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.joinedRide?.id)
        .navigationTitle("Carpool")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyHub: some View {
        ContentUnavailableView {
            Label("Find a ride", systemImage: "person.3.fill")
        } description: {
            Text("Enter your departure and destination to find drivers with a matching commute.")
        } actions: {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    store.startRequestingRide()
                }
            } label: {
                Label("Search for rides", systemImage: "magnifyingglass.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Empty hub") {
    NavigationStack {
        PassengerHomeView(store: PassengerRideStore())
    }
    .environment(AppSession())
}
