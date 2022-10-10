//
//  SleepDetector.swift
//  Sleepi
//
//  Created by Ionut Radu on 05.07.2022.
//

import Foundation
import HealthKit
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SleepDetector"
)


class SleepDetector: ObservableObject {

    private var healthStore: HealthStore?
    init(){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func whenFirstimeRunning() async throws {
        if let healthStore = healthStore {
            let authorized: Bool = try await healthStore.requestAuthorization()
            if authorized {
                logger.log("firstTimeRunning true")
                let startDate = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
                let sleeps = await healthStore.getSleeps(startTime: startDate, endTime: Date())
                
                for sleep in sleeps {
                    try await healthStore.deleteSleep(sleep: sleep)
                    logger.log("Sleep; \(sleep.startDate.formatted());\(sleep.endDate.formatted()); has been deleted")
                }
            }
        }
    }
    
    func performSleepDetection() async throws {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    
                    let currentDate = Date()
                    var startDate: Date = Calendar.current.date(byAdding: .day, value: -14, to: currentDate)!
                    var endDate: Date = Calendar.current.date(byAdding: .hour, value: 24, to: startDate)!
                    let sleeps: [HKCategorySample] = await healthStore.getSleeps(startTime: startDate, endTime: currentDate)
                    
                    if !sleeps.isEmpty {
                        startDate = sleeps.last!.startDate > Calendar.current.date(byAdding: .hour, value: -24, to: currentDate)! ?
                                Calendar.current.date(byAdding: .hour, value: -24, to: currentDate)! : sleeps.last!.startDate
                        endDate = Calendar.current.date(byAdding: .hour, value: 24, to: startDate)! >= currentDate ? currentDate : Calendar.current.date(byAdding: .hour, value: 24, to: startDate)!
                    }
                    
                    while true {
     
                        let heartRates = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .heartRate)
                        let activeEnergy = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .activeEnergyBurned)
                        let steps = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .stepCount)
                        
                        if !activeEnergy.isEmpty && !heartRates.isEmpty && !steps.isEmpty{

                            try await processActivities(activeEnergy, heartRates, sleeps, startDate, endDate, steps, healthStore)
                            
                        } else {
                            logger.log("no activities; \(startDate) - \(endDate)")
                        }
                        
                        startDate = Calendar.current.date(byAdding: .hour, value: -2, to: endDate)!
                        endDate = Calendar.current.date(byAdding: .hour, value: 24, to: endDate)!
                        if endDate > currentDate {
                            break
                        }
                    }
                }
            }        
    }
    
    
    fileprivate func getInBedSleeps(_ potentialSleeps: [Sleep]) -> [Sleep] {
        var inBedSleeps: [Sleep] = []
        var lastIndexUsed: Int = 0
        for (index, sleep) in potentialSleeps.enumerated() {
            if potentialSleeps.indices.contains(index - 1){
                if sleep.startDate.timeIntervalSinceReferenceDate - potentialSleeps[index - 1].endDate.timeIntervalSinceReferenceDate > 10800 {
                    inBedSleeps.append(Sleep(startDate: potentialSleeps[lastIndexUsed].startDate, endDate: potentialSleeps[index - 1].endDate, epochs: []))
                    lastIndexUsed = index
                }
                if sleep.hashValue == potentialSleeps.last!.hashValue {
                    
                    inBedSleeps.append(Sleep(startDate: potentialSleeps[lastIndexUsed].startDate, endDate: potentialSleeps.last!.endDate, epochs: []))
                }
            }
        }
        
        if !inBedSleeps.isEmpty {
            return inBedSleeps.filter { $0.getDuration() > 1200 }
        }
        return potentialSleeps
    }
    
    fileprivate func processActivities(_ activeEnergy: [HKQuantitySample], _ heartRates: [HKQuantitySample], _ sleeps: [HKCategorySample], _ startDate: Date, _ endDate: Date, _ steps: [HKQuantitySample], _ healthStore: HealthStore) async throws {
        var shortSleeps = identifyShortSleeps(activities: activeEnergy, existingSleep: sleeps)
        
        if !shortSleeps.isEmpty {
            
            if !sleeps.isEmpty {
                shortSleeps = shortSleeps.filter({$0.startDate > sleeps.last!.endDate})
            }
            
            let inBedSleeps: [Sleep] = getInBedSleeps(shortSleeps)
            
            var processedSleeps: [Sleep] = getSleepsFromInBedTime(inBedSleeps: inBedSleeps, activeEnergy: activeEnergy, steps: steps)
            
            for sleep in processedSleeps {
                if !heartRates.contains(where: { $0.startDate > sleep.startDate && $0.endDate < sleep.endDate } ) {
                    try await healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                    logger.log(";zip;saved;\(sleep.startDate.formatted());\(sleep.endDate.formatted())")
                } else {
                    logger.log(";zip;ignored-gap;\(sleep.startDate.formatted());\(sleep.endDate.formatted())")
                }
            }

        }
    }
    
    private func getSleepsFromInBedTime(inBedSleeps: [Sleep], activeEnergy: [HKQuantitySample], steps: [HKQuantitySample]) -> [Sleep] {
        var result: [Sleep] = []
        
        for sleep in inBedSleeps {
            let filteredActiveEnergy = activeEnergy.filter { $0.startDate >= sleep.startDate && $0.endDate <= sleep.endDate}
            let filteredSteps = steps.filter { $0.startDate >= sleep.startDate && $0.endDate <= sleep.endDate}
            var activities = filteredActiveEnergy
            activities.append(contentsOf: filteredSteps)
            activities = activities.sorted(by: { (a,b) in a.startDate < b.startDate })
            
            if activities.isEmpty {
                result.append(sleep)
                continue
            }
            var startDate: Date? = sleep.startDate

            let threshold = sleep.getDuration() < 3600 ? 0.02 : 0.1

            for activity in activities {
                logger.log(";getSleepsFromInBedTime;\(activity.startDate.formatted(), privacy: .public);\(activity.endDate.formatted(), privacy: .public);\(activity.quantity)")
                
//                if activity.startDate.formatted() == "07/10/2022, 1:51" {
//                    print("x")
//                }
                
                let kcal = activity.quantityType == HKSampleType.quantityType(forIdentifier: .activeEnergyBurned) ? activity.quantity.doubleValue(for: .kilocalorie()) : 0
                let step = activity.quantityType == HKSampleType.quantityType(forIdentifier: .stepCount) ? activity.quantity.doubleValue(for: .count()) : 0

                
//                if threshold != 0.2 {
//                    print("x")
//                }
                
                if (kcal > threshold || step > 0)  {
                    if startDate != nil {
                        if activity.startDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > 300 {
                            // ignore awake < 2 min
                            if !result.isEmpty && startDate!.timeIntervalSinceReferenceDate - result.last!.endDate.timeIntervalSinceReferenceDate < 180 {
                                let removed = result.removeLast()
                                result.append(Sleep(startDate: removed.startDate, endDate: activity.startDate, epochs: []))
                            } else {
                                result.append(Sleep(startDate: startDate!, endDate: activity.startDate, epochs: []))
                            }
                        }
                        startDate = activity.startDate
                    }
                }
                if activity.hashValue == activities.last!.hashValue && startDate != nil {
                    // ignore awake < 2 min
                    if !result.isEmpty && startDate!.timeIntervalSinceReferenceDate - result.last!.endDate.timeIntervalSinceReferenceDate < 180 {
                        let removed = result.removeLast()
                        result.append(Sleep(startDate: removed.startDate, endDate: sleep.endDate, epochs: []))
                    } else {
                        result.append(Sleep(startDate: startDate!, endDate: sleep.endDate, epochs: []))
                    }
                }
            }
            
        }
        return result
    }
    
    private func identifyShortSleeps(activities: [HKQuantitySample], existingSleep: [HKCategorySample]) -> [Sleep] {
        var result: [Sleep] = []

        var startDate: Date?
        
        for activeEnergy in activities {
            
            logger.log(";\(activeEnergy.startDate.formatted(), privacy: .public);\(activeEnergy.endDate.formatted(), privacy: .public);\(activeEnergy.quantity.doubleValue(for: .kilocalorie()))")
    
//            if activeEnergy.startDate.formatted() == "08/10/2022, 1:49" {
//                logger.log("xx")
//            }
            
            if startDate != nil &&
                activeEnergy.startDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > 600 {
                result.append(Sleep(startDate: startDate!, endDate: activeEnergy.startDate, epochs: []))
            }
            startDate = activeEnergy.endDate
        }
        return result.filter({$0.startDate > existingSleep.last!.endDate}) //avoiding overwriting sleeps
    }
    
    private func getStartDate(_ currentDate: Date) -> Date {
        var result = Calendar.current.startOfDay(for: currentDate)
        result = Calendar.current.date(byAdding: .day, value: -1, to: result)!
        result = Calendar.current.date(byAdding: .hour, value: 9, to: result)!
        return result
    }
    
}
