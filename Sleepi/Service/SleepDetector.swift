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
    
    fileprivate func processActivities(_ activities: [Record], _ steps: [HKQuantitySample]) {
        for (index, activity) in activities.enumerated() {
            let step: HKQuantitySample? = steps.first(where: { (activity.startDate...activity.endDate).contains($0.startDate) ||
                (activity.startDate...activity.endDate).contains($0.endDate)
            })
            if step != nil {
                activity.step = true
            }
            if index - 1 > 0 && activity.startDate.timeIntervalSinceReferenceDate - activities[index - 1].endDate.timeIntervalSinceReferenceDate > 900 {
                activity.firstAfterGap = true
            }
        }
    }
    
    func performSleepDetection() async throws {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    
                    let currentDate = Date()
//                    var twoWeekAgo = Calendar.current.date(byAdding: .day, value: -14, to: currentDate)!
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

                        let activities: [Record] = Utils.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergy)
                        
                        processActivities(activities, steps)
                        
                        if !activities.isEmpty {

                            var potentialSleeps = identifySleeps(activities: activities)
                            logger.log(";zip;")
                            logger.log(";zip;adayBefore;\(startDate.formatted());\(endDate.formatted())")
                            
                            if !sleeps.isEmpty {
                                potentialSleeps = potentialSleeps.filter({$0.startDate > sleeps.last!.endDate})
                            }
                            for sleep in potentialSleeps {

                                try await healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                                logger.log(";zip;saved;\(sleep.startDate.formatted());\(sleep.endDate.formatted())")
                            }
                        } else {
                            logger.log("no activities; \(startDate) - \(endDate)")
                        }
                        

                        startDate = endDate
                        endDate = Calendar.current.date(byAdding: .hour, value: 24, to: endDate)!
                        if endDate > currentDate {
                            break
                        }
                    }

                }
            }        
    }

    fileprivate func stopSleep(_ startDate: inout Date?, _ lowActivityEpochs: inout [Epoch], _ tmpSleeps: inout [Sleep], _ epoch: Epoch) {
        if startDate != nil && !lowActivityEpochs.isEmpty {
            
            if (lowActivityEpochs.last!.endDate.timeIntervalSinceReferenceDate) - startDate!.timeIntervalSinceReferenceDate > Constants.SLEEP_DURATION {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.startDate, epochs: []))
            }
            startDate = nil
            lowActivityEpochs = []
        }
    }
    
    private func identifySleeps(activities: [Record]) -> [Sleep] {
        var tmpSleeps: [Sleep] = []
        
        var startDate: Date?
        var lowActivityEpochs: [Epoch] = []

        let epochs = Utils.getEpochs(activities: activities, minutes: 2)
        let allEpochs = Utils.getEpochs(activities: activities, minutes: 2)

        let actQuartile = Utils.getQuartiles(values: allEpochs.compactMap({$0.sumActivity}) )
        let hrQuartile = Utils.getQuartiles(values: allEpochs.compactMap({$0.meanHR}) )

        logger.log(";\(actQuartile.firstQuartile);\(actQuartile.median);\(actQuartile.thirdQuartile)")
        logger.log(";\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
        var counter = 0
        for (index, epoch) in epochs.enumerated() {
            logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR);\(epoch.isContainingGapOrStep())")
//            for record in epoch.records {
//                logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR);\(record.startDate.formatted());\(record.endDate.formatted());\(record.actEng ?? 0);\(record.hr ?? 999);\(epoch.isContainingGapOrStep())")
//
//            }

//            if epoch.records.contains(where: {$0.startDate.formatted() == "11/09/2022, 1:58"}){
//                logger.log("xx")
//            }
            let lastEpoch = epochs.indices.contains(index - 1) ? epochs[index - 1] : nil
            
            if epoch.sumActivity <= 0.2 &&
                !epoch.isContainingGapOrStep() &&
                !(lastEpoch?.isContainingGapOrStep() ?? false) {

                if startDate == nil {
                    startDate = lastEpoch != nil ? lastEpoch!.records.last!.endDate : epoch.startDate
                }
                lowActivityEpochs.append(epoch)
                counter = 0
            }
            
            else if startDate != nil &&
                        ((epoch.sumActivity <= 0.5 && counter < 2) || (epoch.sumActivity <= 1.5 && counter < 1)) &&
                        !epoch.isContainingGapOrStep() &&
                        !(lastEpoch?.isContainingGapOrStep() ?? false) {
                
                if startDate == nil {
                    startDate = lastEpoch != nil ? lastEpoch!.records.last!.endDate : epoch.startDate
                }
                lowActivityEpochs.append(epoch)
                counter += 1
            }
            else {
                stopSleep(&startDate, &lowActivityEpochs, &tmpSleeps, epoch)
                counter = 0
            }
            
            if epoch == epochs.last && startDate != nil && epoch.endDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > Constants.SLEEP_DURATION {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.endDate, epochs: []))
            }
        }
        let sleeps: [Sleep] = addEpochs(potentialSleeps: tmpSleeps, epochs: epochs)
        return sleeps
    }
    private func addEpochs(potentialSleeps: [Sleep], epochs: [Epoch]) -> [Sleep] {

        let sleeps = getSleepEpochs(sleeps: potentialSleeps, epochs: epochs)

        logger.log(";sleep count: \(sleeps.count)")
        for result in sleeps {
            let meanActivity = result.epochs.filter({!$0.sumActivity.isNaN }).map {$0.sumActivity}.reduce(0, +)
            logger.log("\(result.startDate.formatted());\(result.endDate.formatted());\(meanActivity);\(result.heartRateAverage)")
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
