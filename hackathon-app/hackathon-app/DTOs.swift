import Foundation

// MARK: - Request Bodies

struct CreateIntentRequest: Encodable {
    let departureDate: String
    let originAddress: String
    let destinationAddress: String
    let passengerSeats: Int
    let clientTimeZone: String
}

struct MatchesRequest: Encodable {
    let departureDate: String
    let riderDepartureAddress: String
    let riderArrivalAddress: String
    let wantedArrivalAt: String
    let clientTimeZone: String
}

struct ApplyRequest: Encodable {
    let riderDepartureAddress: String
    let riderArrivalAddress: String
    let wantedArrivalAt: String
    let clientTimeZone: String
}

struct CancelApplicationRequest: Encodable {
    let clientTimeZone: String
}

// MARK: - Response Bodies

struct UserResponse: Decodable {
    let id: String
    let displayName: String?
    let email: String?
}

struct CreateIntentResponse: Decodable {
    let id: String
    let status: String
    let departureDate: String
    let passengerSeats: Int
}

struct IntentListResponse: Decodable {
    let intents: [IntentSummary]
}

struct IntentSummary: Decodable, Identifiable, Hashable {
    let id: String
    let departureDate: String
    let originAddress: String
    let destinationAddress: String
    let passengerSeats: Int
    let status: String
    let seatsFilled: Int
    let seatsRemaining: Int
}

struct MatchesResponse: Decodable {
    let matches: [MatchResult]
}

struct MatchResult: Decodable, Identifiable, Hashable {
    let intentId: String
    let score: Double
    let driverDisplayName: String?
    let seatsRemaining: Int
    let departureDate: String
    let originAddress: String
    let destinationAddress: String

    var id: String { intentId }
}

struct ApplicationResponse: Decodable {
    let id: String
    let intentId: String
    let seatsFilled: Int
    let seatsTotal: Int
    let status: String
    let routingStatus: String?
}

struct IntentDetailResponse: Decodable, Equatable {
    let id: String
    let status: String
    let departureDate: String
    let originAddress: String
    let destinationAddress: String
    let passengerSeats: Int
    let routePolyline: String?
    let driver: DriverInfo
    let applications: [ApplicationInfo]
    let stops: [StopInfo]
}

struct DriverInfo: Decodable, Equatable {
    let id: String
    let displayName: String?
}

struct ApplicationInfo: Decodable, Identifiable, Equatable {
    let id: String
    let riderId: String
    let riderDisplayName: String?
    let departureAddress: String
    let arrivalAddress: String
    let wantedArrivalAt: String
    let createdAt: String
}

struct StopInfo: Decodable, Identifiable, Equatable {
    let sequence: Int
    let kind: String
    let userId: String?
    let placeLabel: String
    let latitude: Double
    let longitude: Double
    let scheduledAt: String

    var id: Int { sequence }

    var isPickup: Bool { kind == "pickup" }
}

// MARK: - API Error

struct APIErrorBody: Decodable, Sendable {
    let error: String
    let message: String?
}

// MARK: - Intent Status

enum IntentStatus: String {
    case collectingPassengers = "collecting_passengers"
    case fullRouting = "full_routing"
    case confirmed = "confirmed"
    case cancelled = "cancelled"

    var label: String {
        switch self {
        case .collectingPassengers: return "Collecting Riders"
        case .fullRouting: return "Building Route…"
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        }
    }

    var isActive: Bool {
        self == .collectingPassengers || self == .fullRouting || self == .confirmed
    }
}

// MARK: - Helpers

extension IntentSummary {
    var intentStatus: IntentStatus? { IntentStatus(rawValue: status) }
}

extension IntentDetailResponse {
    var intentStatus: IntentStatus? { IntentStatus(rawValue: status) }
}
