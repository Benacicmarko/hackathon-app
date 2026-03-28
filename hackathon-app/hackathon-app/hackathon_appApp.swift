//
//  hackathon_appApp.swift
//  hackathon-app
//
//  Created by Andre Flego on 28.03.2026..
//

import GoogleSignIn
import SwiftUI

@main
struct hackathon_appApp: App {
    // Connect AppDelegate for Firebase initialization
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appSession = AppSession()
    @State private var driverRideStore = DriverRideStore()
    @State private var passengerRideStore = PassengerRideStore()
    @State private var googlePlacesService = GooglePlacesService(apiKey: AppConfiguration.googlePlacesAPIKey)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appSession)
                .environment(driverRideStore)
                .environment(passengerRideStore)
                .environment(googlePlacesService)
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}
