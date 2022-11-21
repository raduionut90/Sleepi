//
//  SaveHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SaveHandler"
)

class SaveHandler: BaseHandler {
    
    override func handle(_ request: Request) async throws {
        if let sleeps = request.sleeps {
                try await SleepHelper.shared.save(sleeps)
        }
    }

}
