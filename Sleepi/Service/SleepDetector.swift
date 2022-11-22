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
    private var firstSleepDetectedDate: Date? = nil
    
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
                
                if !sleeps.isEmpty {
                    firstSleepDetectedDate = sleeps.first?.startDate ?? nil
                }
                
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
                    var startDate = Calendar.current.startOfDay(for: currentDate)
                    startDate = Calendar.current.date(byAdding: .hour, value: 12, to: currentDate)!
                    startDate = Calendar.current.date(byAdding: .day, value: -14, to: currentDate)!
                    var endDate: Date = Calendar.current.date(byAdding: .hour, value: 24, to: startDate)!
                    let sleeps: [HKCategorySample] = await healthStore.getSleeps(startTime: startDate, endTime: currentDate)

//                    if firstSleepDetectedDate != nil {
//                        startDate = firstSleepDetectedDate!
//                        startDate = Calendar.current.startOfDay(for: startDate)
//                        startDate = Calendar.current.date(byAdding: .hour, value: 12, to: startDate)!
//                        endDate = Calendar.current.date(byAdding: .hour, value: 24, to: startDate)!
//                    } else if !sleeps.isEmpty {
//                        startDate = sleeps.last!.startDate > Calendar.current.date(byAdding: .hour, value: -24, to: currentDate)! ?
//                                Calendar.current.date(byAdding: .hour, value: -24, to: currentDate)! : sleeps.last!.startDate
//                        startDate = Calendar.current.startOfDay(for: startDate)
//                        startDate = Calendar.current.date(byAdding: .hour, value: 12, to: startDate)!
//                        endDate = Calendar.current.date(byAdding: .hour, value: 24, to: startDate)! >= currentDate ? currentDate : Calendar.current.date(byAdding: .hour, value: 24, to: startDate)!
//                    } else {
//                        startDate = Calendar.current.date(byAdding: .hour, value: -24, to: currentDate)!
//                        endDate = currentDate
//                    }
                    
                    var lastEndDateExistingSleep: Date? = nil
                    
                    while true {
                        logger.debug(";startDate;\(startDate.formatted(), privacy: .public);endDate;\(endDate.formatted(), privacy: .public)")
                        let heartRates = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .heartRate)
                        let activeEnergy = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .activeEnergyBurned)
                        let steps = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .stepCount)
                        
                        if !activeEnergy.isEmpty && !heartRates.isEmpty && !steps.isEmpty{
                            let lastEndSleep: Date? = lastEndDateExistingSleep != nil ? lastEndDateExistingSleep : sleeps.last?.endDate
                            
                            if let identifiedSleeps = processActivities(activeEnergy, heartRates, lastEndSleep, startDate, endDate, steps, healthStore) {
                                let request = StageRequest(sleeps: identifiedSleeps, date: endDate, activeEnergyBurned: activeEnergy, heartRates: heartRates)
                                
                                if !identifiedSleeps.isEmpty {
                                    let stageManager = SleepStageManager(request: request)
                                    do {
                                        try await stageManager.executePipeline()
                                    } catch {
                                        logger.error("Unexpected error: \(error).")
                                    }

                                    lastEndDateExistingSleep = identifiedSleeps.last?.endDate ?? nil
                                }

                            }
                        } else {
                            logger.log("no activities; \(startDate) - \(endDate)")
                        }
                        
                        startDate = Calendar.current.date(byAdding: .hour, value: -2, to: endDate)!
                        endDate = Calendar.current.date(byAdding: .hour, value: 24, to: endDate)!
                        if startDate >= currentDate {
                            break
                        }
                    }
                }
            }        
    }
    
    private func processActivities(_ activeEnergy: [HKQuantitySample], _ heartRates: [HKQuantitySample], _ lastEndDateExistingSleep: Date?, _ startDate: Date, _ endDate: Date, _ steps: [HKQuantitySample], _ healthStore: HealthStore)  -> [Sleep]? {
        
        let timeGaps = getTimeGaps(heartRates, activeEnergy)
        if timeGaps != nil {
            for timeGap in timeGaps! {
                logger.debug(";timeGap:;\(timeGap.start.formatted(), privacy: .public);\(timeGap.end.formatted(), privacy: .public)")
            }
        }
        
        let shortSleeps = identifyShortSleeps(activeEnergies: activeEnergy, lastEndDateExistingSleep: lastEndDateExistingSleep, timeGaps: timeGaps)
        for sleep in shortSleeps {
            logger.debug(";identifyShortSleeps;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public)")
        }

        if !shortSleeps.isEmpty {
            let inBedSleeps: [Sleep] = getInBedSleeps(shortSleeps)
            for sleep in inBedSleeps {
                logger.debug(";getInBedSleeps;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public);\(sleep.getDuration())) ")
            }
            
            if let sleepAfterDurationFilter: [Sleep] = getSleepsAfterDurationFilter(inBedSleeps: inBedSleeps) {
                let finalSleeps: [Sleep] = checkSleepActivities(sleepAfterDurationFilter, heartRates, activeEnergy)
                for sleep in finalSleeps {
                    logger.debug(";checkSleepActivities;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public)")
                }
                return finalSleeps
            }
        }
        return nil
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
        
        for activeEnergy in activities {
            logger.log(";\(activeEnergy.startDate.formatted(), privacy: .public);\(activeEnergy.endDate.formatted(), privacy: .public);\(activeEnergy.quantity.doubleValue(for: .kilocalorie()))")
            
            let isTimeGap: Bool? = timeGaps?.first(where: { $0.contains(activeEnergy.startDate) }) != nil
            
            //for debugging
//            if activeEnergy.startDate.formatted() == "12/10/2022, 22:09" {
//                if timeGaps != nil {
//                    for timegap in timeGaps! {
//                        logger.log(";\(timegap.start);\(timegap.end);")
//                    }
//                }
//                logger.log(";\(activeEnergy.startDate);\(activeEnergy.endDate);")
//            }
            
            if startDate != nil &&
                    !(isTimeGap ?? false) &&
                    activeEnergy.startDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > 180 {
                result.append(Sleep(startDate: startDate!, endDate: activeEnergy.startDate))
            }
            startDate = activeEnergy.endDate
        }

        return result
    }
    
    fileprivate func getInBedSleeps(_ potentialSleeps: [Sleep]) -> [Sleep] {
        var inBedSleeps: [Sleep] = []
        var lastIndexUsed: Int = 0
        for (index, sleep) in potentialSleeps.enumerated() {
            if potentialSleeps.indices.contains(index - 1){
                if sleep.startDate.timeIntervalSinceReferenceDate - potentialSleeps[index - 1].endDate.timeIntervalSinceReferenceDate > 180 {
                    inBedSleeps.append(Sleep(startDate: potentialSleeps[lastIndexUsed].startDate, endDate: potentialSleeps[index - 1].endDate))
                    lastIndexUsed = index
                }
                if sleep == potentialSleeps.last! {
                    inBedSleeps.append(Sleep(startDate: potentialSleeps[lastIndexUsed].startDate, endDate: potentialSleeps.last!.endDate))
                }
            }
        }

        return inBedSleeps
    }
    
    private func getSleepsAfterDurationFilter(inBedSleeps: [Sleep]) -> [Sleep]? {
        var result: [Sleep] = []
        
        for sleep in inBedSleeps {
            if (sleep.isNap() && sleep.getDuration() > Constants.SLEEP_DURATION) || (!sleep.isNap() && sleep.getDuration() > Constants.SLEEP_DURATION) {
                result.append(sleep)
            } else {
                logger.debug(";checkSleepActivities;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public);removed")
            }
            
        }
        return result.isEmpty ? nil : result
    }
    
    private func checkSleepActivities(_ sleeps: [Sleep], _ heartRates: [HKQuantitySample], _ activeEnergy: [HKQuantitySample]) -> [Sleep] {
        var activities: [HKQuantitySample] = []
        activities.append(contentsOf: activeEnergy)
        activities.append(contentsOf: heartRates)
        var finalSleeps: [Sleep] = []
        for sleep in sleeps {
            if activities.contains(where: {$0.startDate > sleep.startDate && $0.startDate < sleep.endDate}) {
                finalSleeps.append(sleep)
            } else {
                
                logger.debug(";checkSleepActivities;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public);\(sleep.getDuration());deleted")
            }
        }
        return finalSleeps
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


    
    private func getStartDate(_ currentDate: Date) -> Date {
        var result = Calendar.current.startOfDay(for: currentDate)
        result = Calendar.current.date(byAdding: .day, value: -1, to: result)!
        result = Calendar.current.date(byAdding: .hour, value: 9, to: result)!
        return result
    }
    
}
