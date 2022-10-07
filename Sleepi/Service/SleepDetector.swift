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
    
    fileprivate func removeGapPeriods(_ sleeps: [Sleep], _ heartRates: [HKQuantitySample], _ activeEnergy: [HKQuantitySample]) -> [Sleep] {
        var result = sleeps
        var all: [HKQuantitySample] = []
        all.append(contentsOf: heartRates)
        all.append(contentsOf: activeEnergy)
        all = all.sorted(by: { (a,b) in  a.startDate < b.startDate })
        var withoutFirst = all
        withoutFirst.removeFirst()
        let timeGaps: [DateInterval] = zip(all, withoutFirst)
            .filter { (a,b) in b.startDate.timeIntervalSinceReferenceDate - a.endDate.timeIntervalSinceReferenceDate > 900 }
            .map {(a,b) in DateInterval(start: a.endDate, end: b.startDate)}
        
        for timeGap in timeGaps {
            result.removeAll(where: {
                timeGap.contains($0.startDate) ||
                timeGap.contains($0.endDate) ||
                ($0.startDate...$0.endDate).contains(timeGap.start) ||
                ($0.startDate...$0.endDate).contains(timeGap.end)
            })
        }
        return result
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
            return inBedSleeps
        }
        return potentialSleeps
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
                        
                        if !activeEnergy.isEmpty && !heartRates.isEmpty {

                            let shortSleeps = identifyShortSleeps(activities: activeEnergy)
                            var shortSleepsFiltered = removeGapPeriods(shortSleeps, heartRates, activeEnergy)
                            
                            if !sleeps.isEmpty {
                                shortSleepsFiltered = shortSleepsFiltered.filter({$0.startDate > sleeps.last!.endDate})
                            }
                            
                            let inBedSleeps = getInBedSleeps(shortSleepsFiltered)
                            logger.log(";zip;")
                            logger.log(";zip;adayBefore;\(startDate.formatted());\(endDate.formatted())")

                            let finalSleeps = inBedSleeps.filter { $0.getDuration() > 1200 }

                            let processedSleeps = getSleepsFromInBedTime(inBedSleeps: finalSleeps, activeEnergy: activeEnergy, steps: steps)
                            
                            for sleep in processedSleeps {
                                try await healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                                logger.log(";zip;saved;\(sleep.startDate.formatted());\(sleep.endDate.formatted())")
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
//            print("slpdur: \(sleep.startDate.formatted());\(sleep.endDate.formatted());\(sleep.getDuration())")

            let threshold = sleep.getDuration() < 3600 ? 0.02 : 0.05

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

    fileprivate func stopSleep(_ startDate: inout Date?, _ lowActivityEpochs: inout [Epoch], _ tmpSleeps: inout [Sleep], _ epoch: Epoch) {
        if startDate != nil && !lowActivityEpochs.isEmpty {
            
            if epoch.startDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > Constants.SLEEP_DURATION {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.startDate, epochs: []))
            }
            startDate = nil
            lowActivityEpochs = []
        }
    }
    
    private func identifyShortSleeps(activities: [HKQuantitySample]) -> [Sleep] {
        var tmpSleeps: [Sleep] = []

        let filteredActiveEnergies = activities.filter { $0.quantity.doubleValue(for: .kilocalorie()) >= 0 }
        var startDate: Date?
        
        for activeEnergy in filteredActiveEnergies {
            logger.log(";\(activeEnergy.startDate.formatted(), privacy: .public);\(activeEnergy.endDate.formatted(), privacy: .public);\(activeEnergy.quantity.doubleValue(for: .kilocalorie()))")

//            if activeEnergy.startDate.formatted() == "05/10/2022, 13:59" {
//                logger.log("x")
//            }
            
//            let prev = filteredActiveEnergies.indices.contains(filteredActiveEnergies.firstIndex(of: activeEnergy)! - 1) ? filteredActiveEnergies[filteredActiveEnergies.firstIndex(of: activeEnergy)! - 1] : nil
//            let next = filteredActiveEnergies.indices.contains(filteredActiveEnergies.firstIndex(of: activeEnergy)! + 1) ? filteredActiveEnergies[filteredActiveEnergies.firstIndex(of: activeEnergy)! + 1] : nil
            
//            if activeEnergy.quantity.doubleValue(for: .kilocalorie()) < 0.25 && prev != nil && next != nil {
//                if activeEnergy.startDate.timeIntervalSinceReferenceDate - prev!.endDate.timeIntervalSinceReferenceDate > 300 &&
//                    next!.startDate.timeIntervalSinceReferenceDate - activeEnergy.endDate.timeIntervalSinceReferenceDate > 300{
//                    continue
//                }
//            }
            
            if startDate != nil &&
                activeEnergy.startDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > 900 {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: activeEnergy.startDate, epochs: []))
            }
            startDate = activeEnergy.endDate
        }
        return tmpSleeps
    }
    
    private func addEpochs(potentialSleeps: [Sleep], epochs: [Epoch]) -> [Sleep] {

        let sleeps = getSleepEpochs(sleeps: potentialSleeps, epochs: epochs)

        logger.log(";sleep count: \(sleeps.count)")
        for result in sleeps {
            let meanActivity = result.epochs.filter({!$0.sumActivity.isNaN }).map {$0.sumActivity}.reduce(0, +)
            logger.log("\(result.startDate.formatted(), privacy: .public);\(result.endDate.formatted(), privacy: .public);\(meanActivity);\(result.heartRateAverage)")
        }
        return sleeps
    }
    
    private func getSleepEpochs(sleeps: [Sleep], epochs: [Epoch]) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {
            let firstEpoch: Int = epochs.firstIndex {$0.startDate >= sleep.startDate}!
            let lastEpoch: Int = (epochs.firstIndex {$0.endDate >= sleep.endDate}) ?? epochs.indices.last!
            if firstEpoch < lastEpoch {
                let sleepEpochs = Array(epochs[firstEpoch...lastEpoch])
                let newSleep = Sleep(startDate: sleep.startDate, endDate: sleep.endDate, epochs: sleepEpochs)
                result.append(newSleep)
            }
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
