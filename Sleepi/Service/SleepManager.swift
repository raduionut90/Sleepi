//
//  SleepManager.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.05.2022.
//

import Foundation
import HealthKit
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SleepManager"
)

class SleepManager: ObservableObject {
    
    private var healthStore: HealthStore?
    @Published var nightSleeps: [Sleep] = []
    @Published var naps: [Sleep] = []

    init(date: Date){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    fileprivate func setSleep(_ rawSleeps: [HKCategorySample]) {
        DispatchQueue.main.async {
            var tmpSleeps: [Sleep] = []
            for rawSleep in rawSleeps {
                let sleep: Sleep = Sleep(startDate: rawSleep.startDate, endDate: rawSleep.endDate, stage: SleepStage(rawValue: rawSleep.value)!)
                tmpSleeps.append(sleep)
            }
            self.nightSleeps = tmpSleeps.filter({$0.stage != .Nap})
            self.naps = tmpSleeps.filter({$0.stage == .Nap})
        }
    }
    
    func refreshSleeps(date: Date) async throws {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    var startDate = Calendar.current.startOfDay(for: date)
                    startDate = Calendar.current.date(byAdding: .hour, value: -4, to: startDate)!
                    let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
                    
                    let rawSleeps: [HKCategorySample] = await healthStore.getSleeps(startTime: startDate, endTime: endDate)
                    
                    setSleep(rawSleeps)
                }
            }
    }

    func getSleepStageDuration(stage: SleepStage) -> Double {
        return nightSleeps.filter({$0.stage == stage}).map( {$0.getDuration() }).reduce(0, +)
    }
    
    func getInBedTime() -> Double {
        if nightSleeps.isEmpty {
            return 0.0
        }
        let startDate: Date = (self.nightSleeps.first?.startDate)!
        let endDate: Date = (self.nightSleeps.last?.endDate)!
        return endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
    }
    
    func getSleepDuration(type: SleepType) -> Double {
        var result: Double = 0.0
        switch type {
        case .NightSleep:
            for sleep in self.nightSleeps.filter({$0.stage != .Awake}) {
                result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
            }
        case .Nap:
            for sleep in self.naps {
                result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
            }
        case .All:
            for sleep in self.nightSleeps {
                result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
            }
            for sleep in self.naps {
                result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
            }
        }

        return result
    }
}

enum SleepType: Double {
    case NightSleep
    case Nap
    case All
}

