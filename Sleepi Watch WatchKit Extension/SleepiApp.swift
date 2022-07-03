//
//  SleepiApp.swift
//  Sleepi Watch WatchKit Extension
//
//  Created by Ionut Radu on 01.06.2022.
//

import SwiftUI

@main
struct SleepiApp: App {
    @StateObject var service = WatchConnectivityService()

    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .environmentObject(service)
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
