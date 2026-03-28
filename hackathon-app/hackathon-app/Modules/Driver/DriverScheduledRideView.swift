//
//  DriverScheduledRideView.swift
//  hackathon-app
//

import SwiftUI

struct DriverScheduledRideView: View {
    @Bindable var store: DriverRideStore
    @Namespace private var rideTransition

    private var ride: ScheduledRide? {
        store.activeRide
    }

    var body: some View {
        if let ride {
            List {
                // Visual progress indicator (only for active phases)
                if ride.phase != .cancelled && ride.phase != .creatingRide {
                    Section {
                        RidePhaseProgressView(currentPhase: ride.phase)
                    }
                }
                
                Section {
                    rideSummaryCard(ride)
                }

                Section("Reliability") {
                    LabeledContent("Published to passengers") {
                        Text(ride.isPublished ? "Yes" : "Draft (local only)")
                    }
                    LabeledContent("Seats free") {
                        Text("\(ride.seatsRemaining) of \(ride.availableSeats)")
                            .contentTransition(.numericText())
                    }
                }

                if !ride.passengers.isEmpty {
                    Section("Passengers") {
                        ForEach(ride.passengers) { passenger in
                            passengerRow(passenger)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
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
            .animation(.default, value: ride.passengers.count)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: ride.phase)
            .navigationTitle("Your ride")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                // Show celebration overlay for completed/cancelled
                if ride.phase == .completed || ride.phase == .cancelled {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    RideCompletionCelebrationView(ride: ride)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    @ViewBuilder
    private func rideSummaryCard(_ ride: ScheduledRide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Animated compact phase badge
                CompactRidePhaseView(currentPhase: ride.phase)
                
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
                    .contentTransition(.numericText())
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
                Button("Edit ride") { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.editRide()
                    }
                }
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        store.startBoarding()
                    }
                } label: {
                    Label("Start boarding", systemImage: "person.2.wave.2")
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel ride", role: .destructive) { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.cancelRide()
                    }
                }
            } else if ride.phase == .boarding {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        store.startRide()
                    }
                } label: {
                    Label("Start ride", systemImage: "car.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel ride", role: .destructive) { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.cancelRide()
                    }
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        store.finishRide()
                    }
                } label: {
                    Label("Finish ride", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        case .completed, .cancelled:
            Button {
                withAnimation(.easeOut(duration: 0.4)) {
                    store.dismissCompletedOrCancelledRide()
                }
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
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
