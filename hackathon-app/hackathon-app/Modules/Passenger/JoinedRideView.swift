//
//  JoinedRideView.swift
//  hackathon-app
//

import SwiftUI

struct JoinedRideView: View {
    @Bindable var store: PassengerRideStore
    @Environment(AppSession.self) private var session

    private var ride: JoinedRide? { store.joinedRide }

    var body: some View {
        if let ride {
            List {
                // Ride phase progress (scheduled → boarding → in progress → completed)
                if store.phase != .cancelled {
                    Section {
                        PassengerRidePhaseProgressView(currentPhase: store.phase)
                    }
                }

                // Route summary
                Section {
                    rideSummaryCard(ride)
                }

                // Driver & vehicle
                Section("Driver") {
                    driverRow(ride.driver)
                    LabeledContent("Vehicle") {
                        Text(ride.vehicle.displayName)
                    }
                    if let plate = ride.vehicle.licensePlate {
                        LabeledContent("Plate") {
                            Text(plate)
                        }
                    }
                }

                // Payment
                Section("Payment") {
                    LabeledContent("Status") {
                        Text(ride.paymentStatus)
                            .foregroundStyle(.secondary)
                    }
                }

                // Actions
                Section("Actions") {
                    actionButtons(for: ride)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: store.phase)
            .navigationTitle("Your ride")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
            .overlay {
                if store.isLoading {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                }
            }
            .overlay {
                if store.phase == .completed || store.phase == .cancelled {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    PassengerRideEndedView(phase: store.phase) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            store.dismissEndedRide()
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func rideSummaryCard(_ ride: JoinedRide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CompactPassengerStatusView(status: ride.passengerStatus)
                Spacer()
            }

            LabeledContent("Pickup") {
                Text(ride.pickupLocation)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Drop-off") {
                Text(ride.dropoffLocation)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Departure") {
                Text(ride.departureTime.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("Est. arrival") {
                Text(ride.estimatedArrivalTime.formatted(date: .omitted, time: .shortened))
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func driverRow(_ driver: DriverProfile) -> some View {
        HStack(spacing: 12) {
            driverAvatar(driver)
            VStack(alignment: .leading, spacing: 2) {
                Text(driver.name)
                    .font(.headline)
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", driver.rating))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func driverAvatar(_ driver: DriverProfile) -> some View {
        Group {
            if let url = driver.profilePhotoURL {
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

    @ViewBuilder
    private func actionButtons(for ride: JoinedRide) -> some View {
        switch store.phase {
        case .joinedRide, .boarding, .inProgress:
            if store.phase == .joinedRide {
                Button("Remove join", role: .destructive) {
                    Task {
                        await store.unjoinRide(token: await session.freshBearerToken())
                    }
                }
                .disabled(store.isLoading)
            }
            // Demo-only button to step through phases
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    store.advanceRidePhase()
                }
            } label: {
                Label("Advance phase (demo)", systemImage: "chevron.right.circle")
            }
            .foregroundStyle(.secondary)

        case .completed, .cancelled:
            Button {
                withAnimation(.easeOut(duration: 0.4)) {
                    store.dismissEndedRide()
                }
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)

        default:
            EmptyView()
        }
    }
}

// MARK: - Ride phase progress (passenger's view of the overall lifecycle)

struct PassengerRidePhaseProgressView: View {
    let currentPhase: PassengerRidePhase

    private let progressPhases: [PassengerRidePhase] = [
        .joinedRide, .boarding, .inProgress, .completed
    ]

    private var currentIndex: Int {
        progressPhases.firstIndex(of: currentPhase) ?? 0
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(Array(progressPhases.enumerated()), id: \.offset) { index, phase in
                    progressSegment(for: phase, at: index)
                    if index < progressPhases.count - 1 {
                        connector(isActive: index < currentIndex)
                    }
                }
            }
            HStack {
                Image(systemName: currentPhase.icon)
                    .font(.title2)
                Text(currentPhase.displayTitle)
                    .font(.headline)
            }
            .foregroundStyle(currentPhase.accentColor)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPhase)
        }
        .padding()
    }

    @ViewBuilder
    private func progressSegment(for phase: PassengerRidePhase, at index: Int) -> some View {
        let isActive = index <= currentIndex
        let isCurrent = index == currentIndex

        Circle()
            .fill(isActive ? phase.accentColor : Color.gray.opacity(0.3))
            .frame(width: isCurrent ? 32 : 24, height: isCurrent ? 32 : 24)
            .overlay {
                if isActive {
                    Image(systemName: isCurrent ? phase.icon : "checkmark")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPhase)
    }

    @ViewBuilder
    private func connector(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? Color.green : Color.gray.opacity(0.3))
            .frame(height: 3)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.4), value: isActive)
    }
}

// MARK: - Compact passenger status badge

struct CompactPassengerStatusView: View {
    let status: PassengerStatus
    @State private var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.caption)
                .scaleEffect(scale)
            Text(status.displayTitle)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor, in: Capsule())
        .onChange(of: status) { _, _ in
            withAnimation(.easeOut(duration: 0.2)) { scale = 1.3 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) { scale = 1.0 }
        }
    }

    private var statusColor: Color {
        switch status {
        case .joined, .confirmed: .blue
        case .waitingForBoarding: .orange
        case .checkedIn: .teal
        case .inRide: .green
        case .completed: .green
        case .cancelled: .red
        }
    }
}

// MARK: - End-of-ride overlay

struct PassengerRideEndedView: View {
    let phase: PassengerRidePhase
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: phase == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(phase == .completed ? .green : .red)

            Text(phase == .completed ? "Ride completed!" : "Ride cancelled")
                .font(.title.bold())

            Text(phase == .completed
                 ? "You have arrived at your destination. Have a great day!"
                 : "This ride has been cancelled.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button(action: onDismiss) {
                Label("Done", systemImage: "checkmark")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .tint(phase == .completed ? .green : .primary)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}

// MARK: - Previews

#Preview("Joined — scheduled") {
    let store = PassengerRideStore()
    store.loadMockResults()
    if let first = store.availableRides.first {
        store.joinRideLocally(first)
    }
    return NavigationStack {
        JoinedRideView(store: store)
    }
    .environment(AppSession())
}

#Preview("Joined — boarding") {
    let store = PassengerRideStore()
    store.loadMockResults()
    if let first = store.availableRides.first {
        store.joinRideLocally(first)
    }
    store.advanceRidePhase()
    return NavigationStack {
        JoinedRideView(store: store)
    }
    .environment(AppSession())
}

#Preview("Completed") {
    let store = PassengerRideStore()
    store.loadMockResults()
    if let first = store.availableRides.first {
        store.joinRideLocally(first)
    }
    store.advanceRidePhase()
    store.advanceRidePhase()
    store.advanceRidePhase()
    return NavigationStack {
        JoinedRideView(store: store)
    }
    .environment(AppSession())
}
