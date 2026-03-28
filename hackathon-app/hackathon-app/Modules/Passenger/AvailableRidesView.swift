//
//  AvailableRidesView.swift
//  hackathon-app
//

import SwiftUI

struct AvailableRidesView: View {
    @Bindable var store: PassengerRideStore

    var body: some View {
        List {
            Section {
                routeSummaryHeader
            }

            if store.availableRides.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No rides found",
                        systemImage: "car.fill",
                        description: Text("No drivers are heading your way at that time. Try a different departure time.")
                    )
                }
            } else {
                Section("\(store.availableRides.count) rides available") {
                    ForEach(store.availableRides) { ride in
                        AvailableRideCard(ride: ride) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                store.joinRide(ride)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Change search", role: .cancel) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        store.startRequestingRide()
                    }
                }
            }
        }
        .navigationTitle("Available rides")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var routeSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(store.rideRequest.from.isEmpty ? "Your location" : store.rideRequest.from, systemImage: "circle.fill")
                .font(.subheadline)
                .foregroundStyle(.primary)
            Label(store.rideRequest.to.isEmpty ? "Your destination" : store.rideRequest.to, systemImage: "mappin.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(store.rideRequest.departureTime.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ride card

struct AvailableRideCard: View {
    let ride: AvailableRide
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: driver info + match badge
            HStack(alignment: .top) {
                driverAvatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(ride.driver.name)
                        .font(.headline)
                    starRating(ride.driver.rating)
                }
                Spacer()
                matchQualityBadge
            }

            Divider()

            // Route
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Pickup") {
                    Text(ride.pickupPoint)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline)
                }
                LabeledContent("Drop-off") {
                    Text(ride.dropoffPoint)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline)
                }
            }

            // Times + seats + price
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label(ride.departureTime.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Arrives \(ride.estimatedArrivalTime.formatted(date: .omitted, time: .shortened))", systemImage: "flag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Label("\(ride.seatsAvailable) seat\(ride.seatsAvailable == 1 ? "" : "s")", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ride.priceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Vehicle
            Text(ride.vehicle.displayName)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Join button
            Button(action: onJoin) {
                Label("Join ride", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ride.matchQuality.color)
        }
        .padding(.vertical, 8)
    }

    private var driverAvatar: some View {
        Group {
            if let url = ride.driver.profilePhotoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
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
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func starRating(_ rating: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", rating))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var matchQualityBadge: some View {
        Text(ride.matchQuality.displayTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ride.matchQuality.color, in: Capsule())
    }
}

// MARK: - Previews

#Preview("Available rides") {
    let store = PassengerRideStore()
    store.rideRequest.from = "Trg bana Jelačića"
    store.rideRequest.to = "Tehnološki park Zagreb"
    store.submitRequest()
    return NavigationStack {
        AvailableRidesView(store: store)
    }
}

#Preview("No rides") {
    let store = PassengerRideStore()
    store.rideRequest.from = "Remote location"
    store.rideRequest.to = "Nowhere"
    // Manually set phase without adding rides
    store.submitRequest()
    return NavigationStack {
        AvailableRidesView(store: store)
    }
}
