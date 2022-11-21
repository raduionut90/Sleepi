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
    
    func refreshSleeps(date: Date) async throws {
        do {
            if let sleeps = try await SleepHelper.shared.getSleeps(date) {
                DispatchQueue.main.async {
                    self.nightSleeps = sleeps.filter({$0.stage != .Nap})
                    self.naps = sleeps.filter({$0.stage == .Nap})
                }
            }
        } catch {
            logger.error("\(error)")
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

