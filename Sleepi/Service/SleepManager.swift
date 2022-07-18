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
    @Published var heartRateAverage: Double = 0.0
    @Published var sleeps: [Sleep] = []
    @Published var naps: [Sleep] = []
    
    init(date: Date){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func refreshSleeps(date: Date) {
        self.naps = []
        self.sleeps = []
        self.heartRateAverage = 0.0
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    var tmpSleeps: [Sleep] = []
                    let rawSleeps: [HKCategorySample] = await healthStore.sleepQuery(date: date)
                    for rawSleep in rawSleeps {
                        let heartRates = await healthStore.startHeartRateQuery(startDate: rawSleep.startDate, endDate: rawSleep.endDate)
//                        let activeEnergy = await healthStore.activeEnergyQuery(startDate: rawSleep.startDate, endDate: rawSleep.endDate)
//                        let sleep: Sleep = Sleep(rawSleep: rawSleep, heartRates: heartRates, activeEnergy: activeEnergy)
                        let activities: [Activity] = self.getActivitiesFromRawData(heartRates: heartRates)
                        let sleep: Sleep = Sleep(startDate: rawSleep.startDate, endDate: rawSleep.endDate, activities: activities)
                        updateActivityEndDate(sleep)
                        tmpSleeps.append(sleep)
                    }
                    self.sleeps = tmpSleeps
                    self.heartRateAverage = getSleepsHeartRateAverage()
                    if self.sleeps.count > 0 {
                        self.napCheck(date)
                        self.updateActivityStage()
                    }
                }
            }
        }
        
//        print("sleeps refreshSleeps: \(sleeps.count)")
//        print("naps refreshSleeps: \(naps.count)")

    }
    
    private func updateActivityStage() {
        for sleep in sleeps {
            for activity in sleep.activities {
                activity.setStage(heartRateAverage)
            }
        }
    }
    
    private func updateActivityEndDate(_ sleep: Sleep) {
        for (index, activity) in sleep.activities.enumerated() {
            activity.endDate = sleep.activities.indices.contains(index + 1) ? sleep.activities[index + 1].startDate : sleep.endDate
        }
    }
    
    private func napCheck(_ date: Date) {
        var referenceHour = Calendar.current.startOfDay(for: date)
        referenceHour = Calendar.current.date(byAdding: .hour, value: 10, to: referenceHour)!
        
        var counter = 0
        for (index, sleep) in sleeps.enumerated() {

            if sleep.startDate > referenceHour {
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
        let startDate: Date = (self.sleeps.first?.startDate)!
        let endDate: Date = (self.sleeps.last?.endDate)!
        return endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
    }
    
    func getAsleepTime() -> Double {
        var result: Double = 0.0
        if sleeps.isEmpty {
            return result
        }
        for sleep in sleeps {
            result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
        }
        return result
    }

    private func getSleepsHeartRateAverage() -> Double {
        var average: Double = 0.0
        for sleep in self.sleeps {
            average += sleep.heartRateAverage
        }
        return average / Double(self.sleeps.count)
    }
    
    private func getActivitiesFromRawData(heartRates: [HKQuantitySample]) -> [Activity] {
        var activities: [Activity] = []
        
        for heartRate in heartRates {
            let record = Activity(startDate: heartRate.startDate, hr: heartRate.quantity.doubleValue(for: HKUnit(from: "count/min")))
            activities.append(record)
        }
        
        activities = activities.sorted { a,b in
            a.startDate < b.startDate
        }
        
//      used for debug
//        for record in activities {
//            print("\(record.startDate.formatted());\(record.hr ?? 999);\(record.actEng ?? 999)")
//        }
        
        return activities
    }
}
