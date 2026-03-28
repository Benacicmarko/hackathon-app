//
//  RideRequestFormView.swift
//  hackathon-app
//

import SwiftUI

struct RideRequestFormView: View {
    @Bindable var store: PassengerRideStore
    @Environment(GooglePlacesService.self) private var placesService
    @Environment(AppSession.self) private var session

    private var canSubmit: Bool {
        !store.rideRequest.from.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.rideRequest.to.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.isLoading
    }

    var body: some View {
        Form {
            Section("Where are you going?") {
                AddressAutocompleteField(
                    title: "From",
                    text: $store.rideRequest.from,
                    placesService: placesService
                )
                AddressAutocompleteField(
                    title: "To",
                    text: $store.rideRequest.to,
                    placesService: placesService
                )
                DatePicker(
                    "Wanted arrival time",
                    selection: $store.rideRequest.departureTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section {
                Stepper(value: Binding(
                    get: { store.rideRequest.pickupRadiusMeters ?? 0 },
                    set: { store.rideRequest.pickupRadiusMeters = $0 == 0 ? nil : $0 }
                ), in: 0...2000, step: 100) {
                    if let radius = store.rideRequest.pickupRadiusMeters, radius > 0 {
                        Text("Pickup radius: \(radius) m")
                    } else {
                        Text("Pickup radius: any")
                    }
                }

                Stepper(value: Binding(
                    get: { store.rideRequest.maxWalkingMinutes ?? 0 },
                    set: { store.rideRequest.maxWalkingMinutes = $0 == 0 ? nil : $0 }
                ), in: 0...30) {
                    if let walk = store.rideRequest.maxWalkingMinutes, walk > 0 {
                        Text("Max walking: \(walk) min")
                    } else {
                        Text("Max walking: any")
                    }
                }
            } header: {
                Text("Optional preferences")
            }

            Section {
                if store.isLoading {
                    HStack {
                        ProgressView()
                        Text("Searching…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Search rides") {
                        Task {
                            await store.submitRequest(token: await session.freshBearerToken())
                        }
                    }
                    .disabled(!canSubmit)
                }

                Button("Cancel", role: .cancel) {
                    store.abandonRequestForm()
                }
                .disabled(store.isLoading)
            }
        }
        .navigationTitle("Find a ride")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        RideRequestFormView(store: PassengerRideStore())
    }
    .environment(GooglePlacesService(apiKey: "YOUR_API_KEY_HERE"))
    .environment(AppSession())
}
