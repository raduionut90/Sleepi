//
//  SleepiApp.swift
//  Sleepi Watch WatchKit Extension
//
//  Created by Ionut Radu on 01.06.2022.
//

import SwiftUI

@main
struct SleepiApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
