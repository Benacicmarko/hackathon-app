//
//  DriverRideModels.swift
//  hackathon-app
//

import Foundation

// MARK: - Phase & passenger status

enum DriverRidePhase: String, Codable, Sendable, CaseIterable {
    case creatingRide
    case scheduledRide
    case boarding
    case inProgress
    case completed
    case cancelled
}

enum PassengerRideStatus: String, Codable, Sendable, CaseIterable {
    case confirmed
    case waitingForCheckIn
    case checkedIn
    case cancelled
}

// MARK: - Options & draft

struct RideOptions: Codable, Sendable, Equatable {
    var maxDetourMinutes: Int?
    var isRecurring: Bool
    var notesForPassengers: String?

    init(
        maxDetourMinutes: Int? = nil,
        isRecurring: Bool = false,
        notesForPassengers: String? = nil
    ) {
        self.maxDetourMinutes = maxDetourMinutes
        self.isRecurring = isRecurring
        self.notesForPassengers = notesForPassengers
    }
}

struct RideDraft: Sendable, Equatable {
    var fromLocation: String
    var toLocation: String
    var departureTime: Date
    var availableSeats: Int
    var options: RideOptions

    init(
        fromLocation: String = "",
        toLocation: String = "",
        departureTime: Date = .now,
        availableSeats: Int = 1,
        options: RideOptions = RideOptions()
    ) {
        self.fromLocation = fromLocation
        self.toLocation = toLocation
        self.departureTime = departureTime
        self.availableSeats = availableSeats
        self.options = options
    }
}

// MARK: - Passenger & ride

struct RidePassenger: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var name: String
    var profilePhotoURL: URL?
    var pickupLocation: String
    var dropoffLocation: String
    var status: PassengerRideStatus

    init(
        id: UUID = UUID(),
        name: String,
        profilePhotoURL: URL? = nil,
        pickupLocation: String,
        dropoffLocation: String,
        status: PassengerRideStatus = .confirmed
    ) {
        self.id = id
        self.name = name
        self.profilePhotoURL = profilePhotoURL
        self.pickupLocation = pickupLocation
        self.dropoffLocation = dropoffLocation
        self.status = status
    }
}

struct ScheduledRide: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var fromLocation: String
    var toLocation: String
    var departureTime: Date
    /// Total passenger seats offered (not including driver).
    var availableSeats: Int
    var passengers: [RidePassenger]
    var phase: DriverRidePhase
    /// When false, the ride is a local draft and would not be shown to passengers (future backend).
    var isPublished: Bool
    var options: RideOptions

    init(
        id: UUID = UUID(),
        fromLocation: String,
        toLocation: String,
        departureTime: Date,
        availableSeats: Int,
        passengers: [RidePassenger] = [],
        phase: DriverRidePhase = .scheduledRide,
        isPublished: Bool = true,
        options: RideOptions = RideOptions()
    ) {
        self.id = id
        self.fromLocation = fromLocation
        self.toLocation = toLocation
        self.departureTime = departureTime
        self.availableSeats = availableSeats
        self.passengers = passengers
        self.phase = phase
        self.isPublished = isPublished
        self.options = options
    }

    /// Passengers counted against capacity (cancelled riders free a seat).
    var activePassengerCount: Int {
        passengers.filter { $0.status != .cancelled }.count
    }

    var seatsRemaining: Int {
        max(0, availableSeats - activePassengerCount)
    }

    var isFull: Bool {
        seatsRemaining == 0
    }
}

// MARK: - Display strings

extension DriverRidePhase {
    var displayTitle: String {
        switch self {
        case .creatingRide: "Creating ride"
        case .scheduledRide: "Scheduled"
        case .boarding: "Boarding soon"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }
}

extension PassengerRideStatus {
    var displayTitle: String {
        switch self {
        case .confirmed: "Confirmed"
        case .waitingForCheckIn: "Waiting for check-in"
        case .checkedIn: "Checked in"
        case .cancelled: "Cancelled"
        }
    }
}
