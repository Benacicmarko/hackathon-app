//
//  AppConfiguration.swift
//  hackathon-app
//

import Foundation

enum AppConfiguration {
    /// Google Places API key for address autocomplete
    /// Get your API key from: https://console.cloud.google.com/google/maps-apis/credentials
    /// Make sure to enable the Places API for your project
    static let googlePlacesAPIKey: String = {
        // Try to load from environment or configuration first
        if let key = ProcessInfo.processInfo.environment["GOOGLE_PLACES_API_KEY"], !key.isEmpty {
            return key
        }
        
        // Fall back to hardcoded key (replace with your actual key)
        return "AIzaSyAJCjZV9CGf_sHnVt9j-hL-MdL0cKthNqA"
    }()
}
