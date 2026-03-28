//
//  GooglePlacesService.swift
//  hackathon-app
//

import Foundation
import Observation

@MainActor
@Observable
final class GooglePlacesService {
    private let apiKey: String
    private let session = URLSession.shared
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Fetches autocomplete predictions from Google Places API
    func fetchPredictions(for query: String) async throws -> [PlacePrediction] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/autocomplete/json")
        components?.queryItems = [
            URLQueryItem(name: "input", value: query),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "types", value: "geocode") // Restrict to addresses
        ]
        
        guard let url = components?.url else {
            throw PlacesError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlacesError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(PlacesAutocompleteResponse.self, from: data)
        
        guard result.status == "OK" || result.status == "ZERO_RESULTS" else {
            throw PlacesError.apiError(result.status)
        }
        
        return result.predictions
    }
}

// MARK: - Models

struct PlacePrediction: Identifiable, Codable {
    let placeId: String
    let description: String
    
    var id: String { placeId }
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case description
    }
}

struct PlacesAutocompleteResponse: Codable {
    let predictions: [PlacePrediction]
    let status: String
}

enum PlacesError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let status):
            return "API error: \(status)"
        }
    }
}
