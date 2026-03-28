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

    private(set) var isLoading: Bool = false
    var errorMessage: String?

    private let api = CarpoolAPIClient(baseURL: AppConfiguration.apiBaseURL)

    init() {}

    // MARK: - Derived state

    var showsEmptyDriverHub: Bool {
        activeRide == nil && !isComposingRide
    }

    // MARK: - Form

    func startCreatingRide() {
        draft = RideDraft()
        isComposingRide = true
    }

    func abandonNewRideForm() {
        guard activeRide == nil else { return }
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

    // MARK: - Backend: create intent

    /// Publishes the ride to the backend, then stores it locally.
    func confirmRide(token: String?) async {
        isLoading = true
        defer { isLoading = false }

        let body = CreateIntentRequest(
            departureDate: APIDateFormatter.dateString(from: draft.departureTime),
            originAddress: draft.fromLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            destinationAddress: draft.toLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            passengerSeats: max(1, draft.availableSeats),
            clientTimeZone: TimeZone.current.identifier
        )

        do {
            let response = try await api.createIntent(token: token, body: body)
            let ride = ScheduledRide(
                backendId: response.id,
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
        } catch {
            errorMessage = (error as? CarpoolAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Backend: cancel intent

    func cancelRide(token: String?) async {
        guard var ride = activeRide else { return }
        isLoading = true
        defer { isLoading = false }

        if let backendId = ride.backendId {
            do {
                try await api.deleteIntent(token: token, intentId: backendId)
            } catch {
                errorMessage = (error as? CarpoolAPIError)?.errorDescription ?? error.localizedDescription
                return
            }
        }

        ride.phase = .cancelled
        activeRide = ride
        isComposingRide = false
    }

    // MARK: - Backend: load existing intents on appear

    /// Loads the driver's most recent active intent from the backend.
    /// Only runs if no local ride is already in memory.
    func loadMyIntents(token: String?) async {
        guard activeRide == nil, !isComposingRide else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let intents = try await api.getMyIntents(token: token)
            // Show the most recent non-cancelled intent
            guard let latest = intents.first(where: { $0.status != "cancelled" }) else { return }
            let phase = driverPhase(from: latest.status)
            let departure = APIDateFormatter.date(fromDateString: latest.departureDate) ?? Date()
            activeRide = ScheduledRide(
                backendId: latest.id,
                fromLocation: latest.originAddress,
                toLocation: latest.destinationAddress,
                departureTime: departure,
                availableSeats: latest.passengerSeats,
                passengers: [],
                phase: phase,
                isPublished: true
            )
        } catch {
            // Silently ignore load errors on appear — don't block driver hub
        }
    }

    // MARK: - Local-only phase transitions (boarding / in-progress / finish)

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

    // MARK: - Helpers

    private func driverPhase(from status: String) -> DriverRidePhase {
        switch status {
        case "collecting_passengers", "full_routing", "confirmed": return .scheduledRide
        case "cancelled": return .cancelled
        default: return .scheduledRide
        }
    }
}
