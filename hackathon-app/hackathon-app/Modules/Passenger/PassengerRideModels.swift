//
//  PassengerRideModels.swift
//  hackathon-app
//

import Foundation
import SwiftUI

// MARK: - Ride phase (overall lifecycle visible to the passenger)

enum PassengerRidePhase: String, Codable, Sendable, CaseIterable {
    case requestingRide
    case viewingAvailableRides
    case joinedRide
    case boarding
    case inProgress
    case completed
    case cancelled
}

// MARK: - Per-participant status (passenger's own spot on the ride)

enum PassengerStatus: String, Codable, Sendable, CaseIterable {
    case joined
    case confirmed
    case waitingForBoarding
    case checkedIn
    case inRide
    case completed
    case cancelled
}

// MARK: - Match quality badge

enum MatchQuality: String, Codable, Sendable {
    case bestMatch
    case startsNearby
    case passingBy
}

// MARK: - Request draft (form state)

struct RideRequest: Sendable, Equatable {
    var from: String
    var to: String
    var departureTime: Date
    var pickupRadiusMeters: Int?
    var maxWalkingMinutes: Int?

    init(
        from: String = "",
        to: String = "",
        departureTime: Date = .now,
        pickupRadiusMeters: Int? = nil,
        maxWalkingMinutes: Int? = nil
    ) {
        self.from = from
        self.to = to
        self.departureTime = departureTime
        self.pickupRadiusMeters = pickupRadiusMeters
        self.maxWalkingMinutes = maxWalkingMinutes
    }
}

// MARK: - Available ride (one match returned from search)

struct DriverProfile: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var name: String
    var rating: Double
    var profilePhotoURL: URL?

    init(id: UUID = UUID(), name: String, rating: Double, profilePhotoURL: URL? = nil) {
        self.id = id
        self.name = name
        self.rating = rating
        self.profilePhotoURL = profilePhotoURL
    }
}

struct VehicleInfo: Codable, Sendable, Equatable {
    var make: String
    var model: String
    var color: String
    var licensePlate: String?

    var displayName: String { "\(color) \(make) \(model)" }
}

struct AvailableRide: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var driver: DriverProfile
    var vehicle: VehicleInfo
    var pickupPoint: String
    var dropoffPoint: String
    var departureTime: Date
    var estimatedArrivalTime: Date
    var seatsAvailable: Int
    var priceDescription: String
    var matchQuality: MatchQuality

    init(
        id: UUID = UUID(),
        driver: DriverProfile,
        vehicle: VehicleInfo,
        pickupPoint: String,
        dropoffPoint: String,
        departureTime: Date,
        estimatedArrivalTime: Date,
        seatsAvailable: Int,
        priceDescription: String = "Settle offline",
        matchQuality: MatchQuality = .bestMatch
    ) {
        self.id = id
        self.driver = driver
        self.vehicle = vehicle
        self.pickupPoint = pickupPoint
        self.dropoffPoint = dropoffPoint
        self.departureTime = departureTime
        self.estimatedArrivalTime = estimatedArrivalTime
        self.seatsAvailable = seatsAvailable
        self.priceDescription = priceDescription
        self.matchQuality = matchQuality
    }
}

// MARK: - Joined ride (after the passenger applies to a ride)

struct JoinedRide: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var driver: DriverProfile
    var vehicle: VehicleInfo
    var pickupLocation: String
    var dropoffLocation: String
    var departureTime: Date
    var estimatedArrivalTime: Date
    var ridePhase: PassengerRidePhase
    var passengerStatus: PassengerStatus
    var paymentStatus: String

    init(
        id: UUID = UUID(),
        driver: DriverProfile,
        vehicle: VehicleInfo,
        pickupLocation: String,
        dropoffLocation: String,
        departureTime: Date,
        estimatedArrivalTime: Date,
        ridePhase: PassengerRidePhase = .joinedRide,
        passengerStatus: PassengerStatus = .joined,
        paymentStatus: String = "Settle offline"
    ) {
        self.id = id
        self.driver = driver
        self.vehicle = vehicle
        self.pickupLocation = pickupLocation
        self.dropoffLocation = dropoffLocation
        self.departureTime = departureTime
        self.estimatedArrivalTime = estimatedArrivalTime
        self.ridePhase = ridePhase
        self.passengerStatus = passengerStatus
        self.paymentStatus = paymentStatus
    }
}

// MARK: - Display strings

extension PassengerRidePhase {
    var displayTitle: String {
        switch self {
        case .requestingRide: "Finding a ride"
        case .viewingAvailableRides: "Choose a ride"
        case .joinedRide: "Scheduled"
        case .boarding: "Boarding"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .requestingRide: "magnifyingglass.circle"
        case .viewingAvailableRides: "list.bullet.circle"
        case .joinedRide: "calendar.badge.clock"
        case .boarding: "person.wave.2"
        case .inProgress: "car.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .requestingRide: .blue
        case .viewingAvailableRides: .blue
        case .joinedRide: .blue
        case .boarding: .orange
        case .inProgress: .green
        case .completed: .green
        case .cancelled: .red
        }
    }
}

extension PassengerStatus {
    var displayTitle: String {
        switch self {
        case .joined: "Joined"
        case .confirmed: "Confirmed"
        case .waitingForBoarding: "Waiting for boarding"
        case .checkedIn: "Checked in"
        case .inRide: "In ride"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .joined: "person.badge.plus"
        case .confirmed: "checkmark.seal"
        case .waitingForBoarding: "clock"
        case .checkedIn: "qrcode.viewfinder"
        case .inRide: "car.fill"
        case .completed: "flag.checkered"
        case .cancelled: "xmark.circle"
        }
    }
}

extension MatchQuality {
    var displayTitle: String {
        switch self {
        case .bestMatch: "Best match"
        case .startsNearby: "Starts nearby"
        case .passingBy: "Passing by"
        }
    }

    var color: Color {
        switch self {
        case .bestMatch: .green
        case .startsNearby: .blue
        case .passingBy: .orange
        }
    }
}
