//
//  PassengerRideStore.swift
//  hackathon-app
//

import Foundation
import Observation

@Observable
@MainActor
final class PassengerRideStore {
    private(set) var phase: PassengerRidePhase = .requestingRide
    /// True while the request form is being filled out.
    private(set) var isRequestingRide: Bool = false
    /// Bound to the request form.
    var rideRequest: RideRequest = RideRequest()
    /// Results after submitting the form.
    private(set) var availableRides: [AvailableRide] = []
    /// Set after the passenger joins a specific ride.
    private(set) var joinedRide: JoinedRide?

    init() {}

    // MARK: - Derived state

    var showsEmptyPassengerHub: Bool {
        phase == .requestingRide && !isRequestingRide
    }

    // MARK: - Request flow

    func startRequestingRide() {
        rideRequest = RideRequest()
        isRequestingRide = true
    }

    func abandonRequestForm() {
        isRequestingRide = false
    }

    /// Simulates a network call; populates mock available rides.
    func submitRequest() {
        availableRides = Self.mockRides(for: rideRequest)
        isRequestingRide = false
        phase = .viewingAvailableRides
    }

    // MARK: - Join flow

    func joinRide(_ ride: AvailableRide) {
        joinedRide = JoinedRide(
            driver: ride.driver,
            vehicle: ride.vehicle,
            pickupLocation: ride.pickupPoint,
            dropoffLocation: ride.dropoffPoint,
            departureTime: ride.departureTime,
            estimatedArrivalTime: ride.estimatedArrivalTime,
            ridePhase: .joinedRide,
            passengerStatus: .joined
        )
        phase = .joinedRide
    }

    /// Removes the passenger from the ride and returns them to the available rides list.
    func unjoinRide() {
        guard phase == .joinedRide else { return }
        joinedRide = nil
        phase = .viewingAvailableRides
    }

    func cancelJoinedRide() {
        guard var ride = joinedRide else { return }
        ride.ridePhase = .cancelled
        ride.passengerStatus = .cancelled
        joinedRide = ride
        phase = .cancelled
    }

    /// Dismisses a completed or cancelled ride and returns to the start.
    func dismissEndedRide() {
        guard phase == .completed || phase == .cancelled else { return }
        joinedRide = nil
        availableRides = []
        rideRequest = RideRequest()
        phase = .requestingRide
    }

    // MARK: - Demo: advance through ride phases

    /// Advances the joined ride through its lifecycle for demo / testing purposes.
    func advanceRidePhase() {
        guard var ride = joinedRide else { return }

        switch phase {
        case .joinedRide:
            ride.ridePhase = .boarding
            ride.passengerStatus = .waitingForBoarding
            phase = .boarding
        case .boarding:
            ride.ridePhase = .inProgress
            ride.passengerStatus = .inRide
            phase = .inProgress
        case .inProgress:
            ride.ridePhase = .completed
            ride.passengerStatus = .completed
            phase = .completed
        default:
            break
        }

        joinedRide = ride
    }

    // MARK: - Mock data

    private static func mockRides(for request: RideRequest) -> [AvailableRide] {
        let base = request.departureTime
        let drivers: [(String, Double, String, String, String)] = [
            ("Marko Kovač",   4.9, "White",  "Toyota", "Corolla"),
            ("Ana Horvat",    4.7, "Silver", "Škoda",  "Octavia"),
            ("Luka Babić",    4.5, "Black",  "VW",     "Golf"),
        ]
        let qualities: [MatchQuality] = [.bestMatch, .startsNearby, .passingBy]

        return drivers.enumerated().map { index, info in
            let (name, rating, color, make, model) = info
            let offsetMinutes = Double(index * 5)
            return AvailableRide(
                driver: DriverProfile(name: name, rating: rating),
                vehicle: VehicleInfo(make: make, model: model, color: color),
                pickupPoint: request.from.isEmpty ? "Your pickup point" : request.from,
                dropoffPoint: request.to.isEmpty ? "Your destination" : request.to,
                departureTime: base.addingTimeInterval(offsetMinutes * 60),
                estimatedArrivalTime: base.addingTimeInterval((offsetMinutes + 25) * 60),
                seatsAvailable: 3 - index,
                matchQuality: qualities[index]
            )
        }
    }
}
