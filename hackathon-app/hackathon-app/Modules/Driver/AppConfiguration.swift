//
//  AppConfiguration.swift
//  hackathon-app
//

import Foundation

enum AppConfiguration {
    /// Google Places API key for address autocomplete.
    /// Enable the Places API in Google Cloud Console and restrict to this app's bundle ID.
    static let googlePlacesAPIKey: String = {
        if let key = ProcessInfo.processInfo.environment["GOOGLE_PLACES_API_KEY"], !key.isEmpty {
            return key
        }
        return "AIzaSyAJCjZV9CGf_sHnVt9j-hL-MdL0cKthNqA"
    }()

    /// Backend base URL **including** the `/v1` path prefix, no trailing slash.
    /// Simulator default: http://127.0.0.1:3000/v1
    /// Device on same Wi-Fi: http://<mac-lan-ip>:3000/v1
    /// Production: https://<your-host>/v1
    static let apiBaseURL: URL = {
        if let raw = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://10.123.223.206:3000/v1")!
    }()
}
