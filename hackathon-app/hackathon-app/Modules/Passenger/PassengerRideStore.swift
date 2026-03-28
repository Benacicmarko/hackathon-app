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
    /// Results after submitting the search.
    private(set) var availableRides: [AvailableRide] = []
    /// Set after the passenger joins a specific ride.
    private(set) var joinedRide: JoinedRide?

    private(set) var isLoading: Bool = false
    var errorMessage: String?

    private let api = CarpoolAPIClient(baseURL: AppConfiguration.apiBaseURL)

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

    // MARK: - Backend: search matches

    func submitRequest(token: String?) async {
        isLoading = true
        defer { isLoading = false }

        let body = MatchesRequest(
            departureDate: APIDateFormatter.dateString(from: rideRequest.departureTime),
            riderDepartureAddress: rideRequest.from,
            riderArrivalAddress: rideRequest.to,
            wantedArrivalAt: APIDateFormatter.isoString(from: rideRequest.departureTime),
            clientTimeZone: TimeZone.current.identifier
        )

        do {
            let results = try await api.searchMatches(token: token, body: body)
            availableRides = results.enumerated().map { index, match in
                Self.mapMatchResult(match, index: index)
            }
            isRequestingRide = false
            phase = .viewingAvailableRides
        } catch {
            errorMessage = (error as? CarpoolAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Backend: join ride

    func joinRide(_ ride: AvailableRide, token: String?) async {
        guard let intentId = ride.backendIntentId else {
            // Fallback for mock / offline rides (no backend ID)
            joinRideLocally(ride)
            return
        }
        isLoading = true
        defer { isLoading = false }

        let body = ApplyRequest(
            riderDepartureAddress: rideRequest.from,
            riderArrivalAddress: rideRequest.to,
            wantedArrivalAt: APIDateFormatter.isoString(from: rideRequest.departureTime),
            clientTimeZone: TimeZone.current.identifier
        )

        do {
            let response = try await api.apply(token: token, intentId: intentId, body: body)
            joinedRide = JoinedRide(
                applicationId: response.id,
                backendIntentId: intentId,
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
        } catch {
            errorMessage = (error as? CarpoolAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Backend: unjoin ride

    /// Removes the passenger's application and returns them to the available rides list.
    func unjoinRide(token: String?) async {
        guard phase == .joinedRide else { return }

        if let applicationId = joinedRide?.applicationId {
            isLoading = true
            defer { isLoading = false }
            do {
                try await api.deleteApplication(token: token, applicationId: applicationId)
            } catch {
                errorMessage = (error as? CarpoolAPIError)?.errorDescription ?? error.localizedDescription
                return
            }
        }

        joinedRide = nil
        phase = .viewingAvailableRides
    }

    // MARK: - Dismissal

    func dismissEndedRide() {
        guard phase == .completed || phase == .cancelled else { return }
        joinedRide = nil
        availableRides = []
        rideRequest = RideRequest()
        phase = .requestingRide
    }

    // MARK: - Demo: advance through ride phases

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

    // MARK: - Private helpers

    /// Used when a ride has no backendIntentId (e.g., dev / preview).
    func joinRideLocally(_ ride: AvailableRide) {
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

    private static func mapMatchResult(_ match: MatchResult, index: Int) -> AvailableRide {
        let departure = APIDateFormatter.date(fromDateString: match.departureDate) ?? Date()
        let arrival = departure.addingTimeInterval(30 * 60)

        let quality: MatchQuality
        if let score = match.score {
            quality = score > 0.65 ? .bestMatch : score > 0.35 ? .startsNearby : .passingBy
        } else {
            quality = index == 0 ? .bestMatch : index == 1 ? .startsNearby : .passingBy
        }

        return AvailableRide(
            backendIntentId: match.intentId,
            driver: DriverProfile(
                name: match.driverDisplayName ?? "Driver",
                rating: 4.5
            ),
            vehicle: VehicleInfo(make: "", model: "", color: ""),
            pickupPoint: match.originAddress,
            dropoffPoint: match.destinationAddress,
            departureTime: departure,
            estimatedArrivalTime: arrival,
            seatsAvailable: match.seatsRemaining,
            matchQuality: quality
        )
    }

    // MARK: - Preview helper

    #if DEBUG
    /// Sets up mock available rides for SwiftUI previews without hitting the API.
    func loadMockResults() {
        rideRequest.from = rideRequest.from.isEmpty ? "Trg bana Jelačića" : rideRequest.from
        rideRequest.to = rideRequest.to.isEmpty ? "Tehnološki park Zagreb" : rideRequest.to
        availableRides = Self.mockRides(for: rideRequest)
        isRequestingRide = false
        phase = .viewingAvailableRides
    }
    #endif

    // MARK: - Mock data (used in previews)

    static func mockRides(for request: RideRequest) -> [AvailableRide] {
        let base = request.departureTime
        let drivers: [(String, Double, String, String, String)] = [
            ("Marko Kovač",   4.9, "White",  "Toyota", "Corolla"),
            ("Ana Horvat",    4.7, "Silver", "Škoda",  "Octavia"),
            ("Luka Babić",    4.5, "Black",  "VW",     "Golf"),
        ]
        let qualities: [MatchQuality] = [.bestMatch, .startsNearby, .passingBy]

        return drivers.enumerated().map { index, info in
            let (name, rating, color, make, model) = info
            let offset = Double(index * 5)
            return AvailableRide(
                driver: DriverProfile(name: name, rating: rating),
                vehicle: VehicleInfo(make: make, model: model, color: color),
                pickupPoint: request.from.isEmpty ? "Your pickup point" : request.from,
                dropoffPoint: request.to.isEmpty ? "Your destination" : request.to,
                departureTime: base.addingTimeInterval(offset * 60),
                estimatedArrivalTime: base.addingTimeInterval((offset + 25) * 60),
                seatsAvailable: 3 - index,
                matchQuality: qualities[index]
            )
        }
    }
}
