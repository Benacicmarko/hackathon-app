//
//  DriverRideCreationView.swift
//  hackathon-app
//

import SwiftUI

struct DriverRideCreationView: View {
    @Bindable var store: DriverRideStore
    @Environment(GooglePlacesService.self) private var placesService
    @Environment(AppSession.self) private var session

    private var isEditingExistingRide: Bool {
        store.activeRide != nil
    }

    private var canSubmit: Bool {
        !store.draft.fromLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.draft.toLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.isLoading
    }

    var body: some View {
        Form {
            Section("Route") {
                AddressAutocompleteField(
                    title: "From",
                    text: $store.draft.fromLocation,
                    placesService: placesService
                )

                AddressAutocompleteField(
                    title: "To",
                    text: $store.draft.toLocation,
                    placesService: placesService
                )

                DatePicker("Departure", selection: $store.draft.departureTime, displayedComponents: [.date, .hourAndMinute])
                Stepper(value: $store.draft.availableSeats, in: 1...8) {
                    Text("Passenger seats: \(store.draft.availableSeats)")
                }
            }

            Section("Optional") {
                Stepper(value: Binding(
                    get: { store.draft.options.maxDetourMinutes ?? 0 },
                    set: { store.draft.options.maxDetourMinutes = $0 == 0 ? nil : $0 }
                ), in: 0...60, step: 5) {
                    if let m = store.draft.options.maxDetourMinutes, m > 0 {
                        Text("Max detour: \(m) min")
                    } else {
                        Text("Max detour: none")
                    }
                }
                Toggle("Recurring ride", isOn: $store.draft.options.isRecurring)
                TextField("Notes for passengers", text: Binding(
                    get: { store.draft.options.notesForPassengers ?? "" },
                    set: { store.draft.options.notesForPassengers = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            Section {
                if store.isLoading {
                    HStack {
                        ProgressView()
                        Text(isEditingExistingRide ? "Saving…" : "Publishing…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button(isEditingExistingRide ? "Save changes" : "Publish ride") {
                        if isEditingExistingRide {
                            store.saveEditedRide()
                        } else {
                            Task {
                                await store.confirmRide(token: await session.freshBearerToken())
                            }
                        }
                    }
                    .disabled(!canSubmit)
                }

                Button("Cancel", role: .cancel) {
                    if isEditingExistingRide {
                        store.cancelEditingRide()
                    } else {
                        store.abandonNewRideForm()
                    }
                }
                .disabled(store.isLoading)
            }
        }
        .navigationTitle(isEditingExistingRide ? "Edit ride" : "New ride")
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

#Preview("New ride") {
    NavigationStack {
        DriverRideCreationView(store: DriverRideStore())
    }
    .environment(GooglePlacesService(apiKey: "YOUR_API_KEY_HERE"))
    .environment(AppSession())
}
