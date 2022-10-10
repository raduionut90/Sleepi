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
                    var lastEndDateExistingSleep: Date? = nil
                    
                    while true {
     
                        let heartRates = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .heartRate)
                        let activeEnergy = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .activeEnergyBurned)
                        let steps = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .stepCount)
                        
                        if !activeEnergy.isEmpty && !heartRates.isEmpty && !steps.isEmpty{
                            let lastEndSleep: Date? = lastEndDateExistingSleep != nil ? lastEndDateExistingSleep : sleeps.last?.endDate
                            
                            if let identifiedSleeps = try await processActivities(activeEnergy, heartRates, lastEndSleep, startDate, endDate, steps, healthStore) {
                                
                                for sleep in identifiedSleeps {
                                    try await healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                                    logger.log(";zip;saved;\(sleep.startDate.formatted());\(sleep.endDate.formatted())")
                                }
                                
                                lastEndDateExistingSleep = identifiedSleeps.last?.endDate ?? nil
                            }
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
                if sleep == potentialSleeps.last! {
                    inBedSleeps.append(Sleep(startDate: potentialSleeps[lastIndexUsed].startDate, endDate: potentialSleeps.last!.endDate, epochs: []))
                }
            }
        }
        
        if !inBedSleeps.isEmpty {
            for sleep in inBedSleeps {
                if sleep.getDuration() < 1200 {
                    logger.debug(";removedBy duration < 1200;\(sleep.getDuration());\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public)")
                    inBedSleeps.removeAll(where: {$0.id == sleep.id})
                }
            }
            
            return inBedSleeps
        }
        return potentialSleeps
    }
    
    fileprivate func processActivities(_ activeEnergy: [HKQuantitySample], _ heartRates: [HKQuantitySample], _ lastEndDateExistingSleep: Date?, _ startDate: Date, _ endDate: Date, _ steps: [HKQuantitySample], _ healthStore: HealthStore) async throws -> [Sleep]? {
        
        let timeGaps = getTimeGaps(heartRates, activeEnergy)

        let shortSleeps = identifyShortSleeps(activeEnergies: activeEnergy, lastEndDateExistingSleep: lastEndDateExistingSleep, timeGaps: timeGaps)
        
        if timeGaps != nil {
            for timeGap in timeGaps! {
                logger.debug(";timeGap:;\(timeGap.start.formatted(), privacy: .public);\(timeGap.end.formatted(), privacy: .public)")
            }
        }

        if !shortSleeps.isEmpty {
            let inBedSleeps: [Sleep] = getInBedSleeps(shortSleeps)
            let processedSleeps: [Sleep] = getSleepsFromInBedTime(inBedSleeps: inBedSleeps, activeEnergy: activeEnergy, steps: steps) 
            return processedSleeps
        }
        return nil
    }
    
    fileprivate func getTimeGaps(_ heartRates: [HKQuantitySample], _ activeEnergy: [HKQuantitySample]) -> [DateInterval]? {
        var all: [HKQuantitySample] = []
        all.append(contentsOf: heartRates)
        all.append(contentsOf: activeEnergy)
        all = all.sorted(by: { (a,b) in  a.startDate < b.startDate })
        var withoutFirst = all
        withoutFirst.removeFirst()
        var timeGaps: [DateInterval]? = nil
        let result = zip(all, withoutFirst)
            .filter { (a,b) in b.startDate.timeIntervalSinceReferenceDate - a.endDate.timeIntervalSinceReferenceDate > 1200 }
            .map {(a,b) in DateInterval(start: a.endDate, end: b.startDate)}
        
        if !result.isEmpty {
            timeGaps = result
        }
        
        return timeGaps
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
//                logger.log(";getSleepsFromInBedTime;\(activity.startDate.formatted(), privacy: .public);\(activity.endDate.formatted(), privacy: .public);\(activity.quantity)")
                
//                if activity.startDate.formatted() == "07/10/2022, 1:51" {
//                    print("x")
//                }
                
                let kcal = activity.quantityType == HKSampleType.quantityType(forIdentifier: .activeEnergyBurned) ? activity.quantity.doubleValue(for: .kilocalorie()) : 0
                let step = activity.quantityType == HKSampleType.quantityType(forIdentifier: .stepCount) ? activity.quantity.doubleValue(for: .count()) : 0
                
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
                if activity == activities.last! && startDate != nil {
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
        for sleep in result {
            logger.debug(";inBedSleep;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public)")
        }
        return result
    }
    
    private func identifyShortSleeps(activeEnergies: [HKQuantitySample], lastEndDateExistingSleep: Date?, timeGaps: [DateInterval]?) -> [Sleep] {
        var result: [Sleep] = []

        var startDate: Date?
        
        var activities = activeEnergies
        //avoiding overwriting sleeps
        if lastEndDateExistingSleep != nil {
            activities = activities.filter({ $0.startDate > lastEndDateExistingSleep! })
            logger.debug(";lastEndDateExistingSleep:;\(lastEndDateExistingSleep!.formatted())")
        }
        
        for activeEnergy in activities.filter({$0.quantity.doubleValue(for: .kilocalorie()) > 0.1}) {
            logger.log(";\(activeEnergy.startDate.formatted(), privacy: .public);\(activeEnergy.endDate.formatted(), privacy: .public);\(activeEnergy.quantity.doubleValue(for: .kilocalorie()))")
            
            let isTimeGap: (Bool)? = timeGaps?.first(where: { $0.contains(activeEnergy.startDate) }) != nil
//            if activeEnergy.startDate.formatted() == "11.10.2022, 6:48" {
//                logger.log("xx")
//            }
            
            if startDate != nil &&
                    !(isTimeGap ?? false) &&
                    activeEnergy.startDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > 900 {
                result.append(Sleep(startDate: startDate!, endDate: activeEnergy.startDate, epochs: []))
            }
            startDate = activeEnergy.endDate
        }

        return result
    }
    
    private func getStartDate(_ currentDate: Date) -> Date {
        var result = Calendar.current.startOfDay(for: currentDate)
        result = Calendar.current.date(byAdding: .day, value: -1, to: result)!
        result = Calendar.current.date(byAdding: .hour, value: 9, to: result)!
        return result
    }
    
}
