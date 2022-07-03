//
//  SleepiApp.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import SwiftUI

@main
struct SleepiApp: App {
    @StateObject var service = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
        }
    }
}
