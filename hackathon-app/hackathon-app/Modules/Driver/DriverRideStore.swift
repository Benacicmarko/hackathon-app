//
//  DriverRideStore.swift
//  hackathon-app
//

import Foundation
import Observation

@Observable
@MainActor
final class DriverRideStore {
    /// Current ride once confirmed; still set while editing until saved.
    private(set) var activeRide: ScheduledRide?
    /// True while showing the creation/edit form.
    private(set) var isComposingRide: Bool = false
    /// Bound to the form.
    var draft: RideDraft = RideDraft()

    init() {}

    /// No active management screen and not on the form.
    var showsEmptyDriverHub: Bool {
        activeRide == nil && !isComposingRide
    }

    func startCreatingRide() {
        draft = RideDraft()
        isComposingRide = true
    }

    /// Leave the new-ride form without saving (no active ride).
    func abandonNewRideForm() {
        guard activeRide == nil else { return }
        isComposingRide = false
    }

    /// Publishes the ride: visible to passengers once backend exists (`isPublished`).
    func confirmRide() {
        let ride = ScheduledRide(
            fromLocation: draft.fromLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            toLocation: draft.toLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            departureTime: draft.departureTime,
            availableSeats: max(1, draft.availableSeats),
            passengers: activeRide?.passengers ?? [],
            phase: .scheduledRide,
            isPublished: true,
            options: draft.options
        )
        activeRide = ride
        isComposingRide = false
    }

    func editRide() {
        guard let ride = activeRide else { return }
        draft = RideDraft(
            fromLocation: ride.fromLocation,
            toLocation: ride.toLocation,
            departureTime: ride.departureTime,
            availableSeats: ride.availableSeats,
            options: ride.options
        )
        isComposingRide = true
    }

    func cancelEditingRide() {
        isComposingRide = false
    }

    func saveEditedRide() {
        guard var ride = activeRide else { return }
        ride.fromLocation = draft.fromLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        ride.toLocation = draft.toLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        ride.departureTime = draft.departureTime
        ride.availableSeats = max(1, draft.availableSeats)
        ride.options = draft.options
        activeRide = ride
        isComposingRide = false
    }

    func cancelRide() {
        guard var ride = activeRide else { return }
        ride.phase = .cancelled
        activeRide = ride
        isComposingRide = false
    }

    func startBoarding() {
        guard var ride = activeRide, ride.phase == .scheduledRide else { return }
        ride.phase = .boarding
        activeRide = ride
    }

    func startRide() {
        guard var ride = activeRide, ride.phase == .boarding else { return }
        ride.phase = .inProgress
        activeRide = ride
    }

    func finishRide() {
        guard var ride = activeRide, ride.phase == .inProgress else { return }
        ride.phase = .completed
        activeRide = ride
    }

    func dismissCompletedOrCancelledRide() {
        if activeRide?.phase == .completed || activeRide?.phase == .cancelled {
            activeRide = nil
        }
    }

    /// Demo / future sync: replace or merge passengers from the server.
    func replacePassengers(_ passengers: [RidePassenger]) {
        guard var ride = activeRide else { return }
        ride.passengers = passengers
        activeRide = ride
    }
}
