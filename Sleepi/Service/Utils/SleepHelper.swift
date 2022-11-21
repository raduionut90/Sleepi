//
//  SleepHelper.swift
//  Sleepi
//
//  Created by Ionut Radu on 21.11.2022.
//

import Foundation
import HealthKit
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SleepManager"
)

class SleepHelper {
    private var healthStore: HealthStore?
    static let shared = SleepHelper()
        
    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func save(_ sleeps: [Sleep]) async throws {
        if sleeps.isEmpty {
            throw DetectionError.emptySleeps
        }
        for sleep in sleeps {
            try await save(sleep)
        }
    }
    
    func save(_ sleep: Sleep) async throws {
        if let healthStore = healthStore {
            let authorized: Bool = try await healthStore.requestAuthorization()
            if authorized {
                        
                logger.debug(";detector;SaveHandler;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public);\(sleep.stage!.rawValue)")
                        
                if let stage = sleep.stage {
                    try await healthStore.saveSleepStages(startTime: sleep.startDate, endTime: sleep.endDate, stage: stage.rawValue)
                } else {
                    throw DetectionError.emptySleepStage
                }
            }
        }
    }
    
    func getSleeps(date: Date) async throws -> [Sleep]? {
        var startDate = Calendar.current.startOfDay(for: date)
        startDate = Calendar.current.date(byAdding: .hour, value: -4, to: startDate)!
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        
        return try await getSleeps(startDate: startDate, endDate: endDate)
    }
    
    func getSleeps(startDate: Date, endDate: Date) async throws -> [Sleep]? {
        if let healthStore = healthStore {
            let authorized: Bool = try await healthStore.requestAuthorization()
            if authorized {
                let rawSleeps: [HKCategorySample] = await healthStore.getSleeps(startTime: startDate, endTime: endDate)
                
                var sleeps: [Sleep] = []
                for rawSleep in rawSleeps {
                    var sleep: Sleep = Sleep(startDate: rawSleep.startDate, endDate: rawSleep.endDate)
                    sleep.stage = SleepStage(rawValue: rawSleep.value)
                    sleep.origin = rawSleep.sourceRevision.source.bundleIdentifier
                    sleeps.append(sleep)
                }
                return sleeps
            }
        }
        return nil
    }
}
