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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appSession)
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}
