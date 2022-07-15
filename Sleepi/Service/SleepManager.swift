//
//  SleepManager.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.05.2022.
//

import Foundation
import HealthKit

@MainActor
class SleepManager: ObservableObject {
    private var healthStore: HealthStore?
    @Published var sleeps: [Sleep] = []
    @Published var naps: [Sleep] = []
    
    init(){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func refreshSleeps(date: Date) {
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    var tmpSleeps: [Sleep] = []
                    let rawSleeps: [HKCategorySample] = await healthStore.sleepQuery(date: date)
                    for rawSleep in rawSleeps {
                        let heartRates = await healthStore.startHeartRateQuery(startDate: rawSleep.startDate, endDate: rawSleep.endDate)
                        let activeEnergy = await healthStore.activeEnergyQuery(startDate: rawSleep.startDate, endDate: rawSleep.endDate)
                        let sleep: Sleep = Sleep(rawSleep: rawSleep, heartRates: heartRates, activeEnergy: activeEnergy)
                        tmpSleeps.append(sleep)
                    }
                    self.sleeps = tmpSleeps
                    self.napCheck(date)
                }
            }
        }
        
//        print("sleeps refreshSleeps: \(sleeps.count)")
//        print("naps refreshSleeps: \(naps.count)")

    }
    
    private func napCheck(_ date: Date) {
        self.naps = []
        var counter = 0
        var referenceHour = Calendar.current.startOfDay(for: date)
        referenceHour = Calendar.current.date(byAdding: .hour, value: 12, to: referenceHour)!
        
        for (index, sleep) in sleeps.enumerated() {
            if sleeps.count >= 2 && index > 0 {
                let timeUntilNextSleep = sleep.rawSleep.startDate.timeIntervalSinceReferenceDate - sleeps[index - 1].rawSleep.endDate.timeIntervalSinceReferenceDate

                if timeUntilNextSleep > 10800 {  // 4h 60 * 60 * 4
                    self.naps.append(sleep)
                    self.sleeps.remove(at: index - counter)
                    counter += 1
                }
            } else if sleep.rawSleep.startDate > referenceHour {
                self.naps.append(sleep)
                self.sleeps.remove(at: index - counter)
                counter += 1

            }
        }

    }
    
    func getInBedTime() -> Double {
        if sleeps.isEmpty {
            return 0.0
        }
        let startDate: Date = (self.sleeps.first?.rawSleep.startDate)!
        let endDate: Date = (self.sleeps.last?.rawSleep.endDate)!
        return endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
    }
    
    func getAsleepTime() -> Double {
        var result: Double = 0.0
        if sleeps.isEmpty {
            return result
        }
        for sleep in sleeps {
            result += sleep.rawSleep.endDate.timeIntervalSinceReferenceDate - sleep.rawSleep.startDate.timeIntervalSinceReferenceDate
        }
        return result
    }

    func getSleepsHeartRateAverage() -> Double {
        var average: Double = 0.0
        for sleep in sleeps {
            average += sleep.getHeartRateAverage()
        }
        return average / Double(sleeps.count)
    }
}
