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
    
    override func handle(_ request: Request) -> LocalizedError? {
   
        if let sleeps = request.sleeps {
            Task(priority: .high) {
                try await SleepHelper.shared.save(sleeps)
            }
        }
        return nil
    }

}
