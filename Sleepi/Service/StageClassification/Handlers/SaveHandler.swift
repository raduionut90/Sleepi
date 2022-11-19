//
//  SaveHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import HealthKit
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SaveHandler"
)

class SaveHandler: BaseHandler {
    private var healthStore: HealthStore?
    
    init(){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    
    override func handle(_ request: Request) -> LocalizedError? {
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    if let sleeps = request.sleeps {
                        for sleep in sleeps {
                            logger.debug(";detector;SaveHandler;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public);\(sleep.stage!.rawValue)")
                            
                            if let stage = sleep.stage {
                                try await healthStore.saveSleepStages(startTime: sleep.startDate, endTime: sleep.endDate, stage: stage.rawValue)
                            } else {
                                throw DetectionError.emptySleepStage
                            }
                        }
                    } else {
                        throw DetectionError.emptySleeps
                    }
                }
            }
        }
        return nil
    }
}
