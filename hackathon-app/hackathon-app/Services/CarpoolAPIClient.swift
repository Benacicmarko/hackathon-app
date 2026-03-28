//
//  CarpoolAPIClient.swift
//  hackathon-app
//
//  URLSession-based client for the Carpool Fastify backend.
//  Endpoints match docs/IOS_BACKEND_INTEGRATION.md §3.
//

import Foundation

// MARK: - Shared date helpers

enum APIDateFormatter {
    /// "YYYY-MM-DD" calendar date (used by rider date search).
    static func dateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    /// Full ISO-8601 instant with fractional seconds (wanted_arrival_at field).
    static func isoString(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    /// Parse either "YYYY-MM-DD" or full ISO-8601 instant.
    static func date(fromDateString string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }

        let isoNoFractional = ISO8601DateFormatter()
        isoNoFractional.formatOptions = [.withInternetDateTime]
        if let d = isoNoFractional.date(from: string) { return d }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.date(from: string)
    }
}

// MARK: - Request bodies

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

struct DeleteApplicationBody: Encodable {
    let clientTimeZone: String
}

// MARK: - Response bodies

struct MeResponse: Decodable {
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

struct DriverIntentSummary: Decodable, Identifiable {
    let id: String
    let departureDate: String
    let originAddress: String
    let destinationAddress: String
    let passengerSeats: Int
    let status: String
    let seatsFilled: Int
    let seatsRemaining: Int
}

struct DriverIntentsListResponse: Decodable {
    let intents: [DriverIntentSummary]
}

struct MatchResult: Decodable, Identifiable {
    let intentId: String
    let score: Double?
    let driverDisplayName: String?
    let seatsRemaining: Int
    let departureDate: String
    let originAddress: String
    let destinationAddress: String
    var id: String { intentId }
}

struct MatchesResponse: Decodable {
    let matches: [MatchResult]
}

struct ApplicationResponse: Decodable {
    let id: String
    let intentId: String
    let seatsFilled: Int
    let seatsTotal: Int
    let status: String
    let routingStatus: String?
}

struct RideStopDTO: Decodable {
    let sequence: Int
    let kind: String
    let userId: String?
    let placeLabel: String
    let latitude: Double
    let longitude: Double
    let scheduledAt: String?
}

struct ApplicationDetailDTO: Decodable {
    let id: String
    let riderId: String
    let riderDisplayName: String?
    let departureAddress: String
    let arrivalAddress: String
    let wantedArrivalAt: String
    let createdAt: String
}

struct IntentDetailResponse: Decodable {
    struct DriverInfo: Decodable {
        let id: String
        let displayName: String?
    }
    let id: String
    let status: String
    let departureDate: String
    let originAddress: String
    let destinationAddress: String
    let passengerSeats: Int
    let driver: DriverInfo
    let applications: [ApplicationDetailDTO]
    let stops: [RideStopDTO]
}

// MARK: - Error

struct APIErrorBody: Decodable {
    let error: String
    let message: String?
}

enum CarpoolAPIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case conflict(code: String, message: String?)
    case badRequest(String)
    case serverError(Int)
    case decodingFailure(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .forbidden:
            return "You don't have permission for that action."
        case .notFound:
            return "Not found."
        case .conflict(let code, let message):
            return message ?? humanMessage(for: code)
        case .badRequest(let detail):
            return "Invalid request: \(detail)"
        case .serverError(let code):
            return "Server error (\(code)). Try again in a moment."
        case .decodingFailure:
            return "Unexpected response from the server."
        case .network(let err):
            return err.localizedDescription
        }
    }

    private func humanMessage(for code: String) -> String {
        switch code {
        case "intent_full":                         return "This ride is now full."
        case "already_applied":                     return "You already joined this ride."
        case "application_cutoff_passed":           return "Booking is closed for this departure date."
        case "cannot_apply_to_own_intent":          return "You can't join your own ride."
        case "intent_cancelled":                    return "This ride has been cancelled."
        case "intent_not_accepting_applications":   return "This ride is no longer accepting passengers."
        case "routing_failed":                      return "No feasible route for this group. Try a different ride."
        case "cancel_not_allowed_day_before_rule":  return "Cancellation is only allowed the day before the trip."
        default:                                    return "Action not allowed."
        }
    }
}

// MARK: - Client

/// Stateless, `Sendable` HTTP client. One instance per store is fine.
final class CarpoolAPIClient: Sendable {

    private let baseURL: URL

    /// Fallback token for local dev when Firebase Admin is disabled on the server.
    /// Different strings produce different synthetic users on the backend.
    static let devToken = "dev-token-ios"

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    // MARK: Profile

    func getMe(token: String?) async throws -> MeResponse {
        let req = request("/me", method: "GET", token: token)
        return try await decode(req)
    }

    // MARK: Driver intents

    func createIntent(token: String?, body: CreateIntentRequest) async throws -> CreateIntentResponse {
        var req = request("/driver-intents", method: "POST", token: token)
        req.httpBody = try encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await decode(req)
    }

    func getMyIntents(token: String?) async throws -> [DriverIntentSummary] {
        let req = request("/driver-intents/mine", method: "GET", token: token)
        let res: DriverIntentsListResponse = try await decode(req)
        return res.intents
    }

    func deleteIntent(token: String?, intentId: String) async throws {
        let req = request("/driver-intents/\(intentId)", method: "DELETE", token: token)
        try await send(req)
    }

    func getIntentDetail(token: String?, intentId: String) async throws -> IntentDetailResponse {
        let req = request("/driver-intents/\(intentId)/detail", method: "GET", token: token)
        return try await decode(req)
    }

    // MARK: Matches

    func searchMatches(token: String?, body: MatchesRequest) async throws -> [MatchResult] {
        var req = request("/driver-intents/matches", method: "POST", token: token)
        req.httpBody = try encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let res: MatchesResponse = try await decode(req)
        return res.matches
    }

    // MARK: Applications

    func apply(token: String?, intentId: String, body: ApplyRequest) async throws -> ApplicationResponse {
        var req = request("/driver-intents/\(intentId)/applications", method: "POST", token: token)
        req.httpBody = try encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await decode(req)
    }

    func deleteApplication(token: String?, applicationId: String) async throws {
        var req = request("/applications/\(applicationId)", method: "DELETE", token: token)
        req.httpBody = try encode(DeleteApplicationBody(clientTimeZone: TimeZone.current.identifier))
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await send(req)
    }

    // MARK: - Private helpers

    private func request(_ path: String, method: String, token: String?) -> URLRequest {
        let url = URL(string: baseURL.absoluteString + path)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token ?? Self.devToken)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func decode<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await fetch(request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CarpoolAPIError.decodingFailure(error)
        }
    }

    private func send(_ request: URLRequest) async throws {
        _ = try await fetch(request)
    }

    @discardableResult
    private func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CarpoolAPIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CarpoolAPIError.serverError(0)
        }
        switch http.statusCode {
        case 200...204:
            return (data, http)
        case 401:
            throw CarpoolAPIError.unauthorized
        case 403:
            throw CarpoolAPIError.forbidden
        case 404:
            throw CarpoolAPIError.notFound
        case 409:
            let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw CarpoolAPIError.conflict(code: body?.error ?? "unknown", message: body?.message)
        case 400:
            let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw CarpoolAPIError.badRequest(body?.error ?? "validation_error")
        default:
            throw CarpoolAPIError.serverError(http.statusCode)
        }
    }
}
