//
//  DriverScheduledRideView.swift
//  hackathon-app
//

import SwiftUI

struct DriverScheduledRideView: View {
    @Bindable var store: DriverRideStore

    private var ride: ScheduledRide? {
        store.activeRide
    }

    var body: some View {
        if let ride {
            List {
                Section {
                    rideSummaryCard(ride)
                }

                Section("Reliability") {
                    LabeledContent("Published to passengers") {
                        Text(ride.isPublished ? "Yes" : "Draft (local only)")
                    }
                    LabeledContent("Seats free") {
                        Text("\(ride.seatsRemaining) of \(ride.availableSeats)")
                    }
                }

                if !ride.passengers.isEmpty {
                    Section("Passengers") {
                        ForEach(ride.passengers) { passenger in
                            passengerRow(passenger)
                        }
                    }
                } else {
                    Section("Passengers") {
                        Text("No passengers yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Actions") {
                    actionButtons(for: ride)
                }
            }
            .navigationTitle("Your ride")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func rideSummaryCard(_ ride: ScheduledRide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(ride.phase.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                Spacer()
            }
            LabeledContent("From") {
                Text(ride.fromLocation)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("To") {
                Text(ride.toLocation)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Departure") {
                Text(ride.departureTime.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("Seats") {
                Text("\(ride.availableSeats) offered · \(ride.seatsRemaining) free")
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func passengerRow(_ passenger: RidePassenger) -> some View {
        HStack(alignment: .top, spacing: 12) {
            passengerAvatar(passenger)
            VStack(alignment: .leading, spacing: 4) {
                Text(passenger.name)
                    .font(.headline)
                Text(passenger.status.displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Pickup") {
                    Text(passenger.pickupLocation)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Drop-off") {
                    Text(passenger.dropoffLocation)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func passengerAvatar(_ passenger: RidePassenger) -> some View {
        Group {
            if let url = passenger.profilePhotoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    @ViewBuilder
    private func actionButtons(for ride: ScheduledRide) -> some View {
        switch ride.phase {
        case .scheduledRide, .boarding, .inProgress:
            if ride.phase == .scheduledRide {
                Button("Edit ride") { store.editRide() }
                Button("Start boarding") { store.startBoarding() }
                Button("Cancel ride", role: .destructive) { store.cancelRide() }
            } else if ride.phase == .boarding {
                Button("Start ride") { store.startRide() }
                Button("Cancel ride", role: .destructive) { store.cancelRide() }
            } else {
                Button("Finish ride") { store.finishRide() }
            }
        case .completed, .cancelled:
            Button("Done") { store.dismissCompletedOrCancelledRide() }
        case .creatingRide:
            EmptyView()
        }
    }
}

#Preview("Scheduled + passengers") {
    let store = DriverRideStore()
    store.startCreatingRide()
    store.draft.fromLocation = "Home"
    store.draft.toLocation = "Office"
    store.confirmRide()
    store.replacePassengers([
        RidePassenger(
            name: "Alex",
            pickupLocation: "Trg bana Jelačića",
            dropoffLocation: "Zagreb West",
            status: .confirmed
        ),
        RidePassenger(
            name: "Jamie",
            pickupLocation: "Main station",
            dropoffLocation: "Tech park",
            status: .waitingForCheckIn
        ),
    ])
    return NavigationStack {
        DriverScheduledRideView(store: store)
    }
}
