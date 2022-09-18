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

@MainActor
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
            
            if (lowActivityEpochs.last!.endDate.timeIntervalSinceReferenceDate) - startDate!.timeIntervalSinceReferenceDate > Constants.MINI_SLEEP_DURATION {
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

        let epochs = Utils.getEpochs(activities: activities, minutes: 3)
        let allEpochs = Utils.getEpochs(activities: activities, minutes: 3)

        let actQuartile = Utils.getQuartiles(values: allEpochs.compactMap({$0.sumActivity}) )
        let hrQuartile = Utils.getQuartiles(values: allEpochs.compactMap({$0.meanHR}) )

        logger.log(";\(actQuartile.firstQuartile);\(actQuartile.median);\(actQuartile.thirdQuartile)")
        logger.log(";\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
        var counter = 0
        for (index, epoch) in epochs.enumerated() {
//            logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR)")
            for record in epoch.records {
                logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR);\(record.startDate.formatted());\(record.endDate.formatted());\(record.actEng ?? 0);\(record.hr ?? 999);\(epoch.isContainingGapOrStep())")

            }

            if epoch.records.contains(where: {$0.startDate.formatted() == "11/09/2022, 1:58"}){
                logger.log("xx")
            }
            let lastEpoch = epochs.indices.contains(index - 1) ? epochs[index - 1] : nil
            let lastEpochLowActMeanHr = lowActivityEpochs.last(where: { !$0.meanHR.isNaN }).map {$0.meanHR}
            
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
                        epoch.sumActivity <= 2 &&
                        counter < 2 &&
                        ( (lastEpochLowActMeanHr != nil && !epoch.meanHR.isNaN) ? epoch.meanHR <= (lastEpochLowActMeanHr! + 10) : true) &&
                        !epoch.isContainingGapOrStep() &&
                        !(lastEpoch?.isContainingGapOrStep() ?? false) {
                
                if startDate == nil {
                    startDate = lastEpoch != nil ? lastEpoch!.records.last!.endDate : epoch.startDate
                }
                lowActivityEpochs.append(epoch)
                counter += 1
            }
            else {
                if counter == 2 {
                    let removedEpoch = lowActivityEpochs.removeLast()
                    stopSleep(&startDate, &lowActivityEpochs, &tmpSleeps, removedEpoch)
                } else {
                    stopSleep(&startDate, &lowActivityEpochs, &tmpSleeps, epoch)
                }
                counter = 0
            }
            
            if epoch == epochs.last && startDate != nil && epoch.endDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > Constants.MINI_SLEEP_DURATION {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.endDate, epochs: []))
            }
        }
        let sleeps: [Sleep] = proccesPotentialSleeps(potentialSleeps: tmpSleeps, epochs: epochs, actQuartile: actQuartile, hrQuartile: hrQuartile)
        return sleeps
    }
    private func proccesPotentialSleeps(potentialSleeps: [Sleep], epochs: [Epoch], actQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), hrQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double)) -> [Sleep] {
        logger.log(";before filter sleep duration \(potentialSleeps.count)")
        for result in potentialSleeps {
            let meanActivity = result.epochs.filter({!$0.sumActivity.isNaN }).map {$0.sumActivity}.reduce(0, +)
            logger.log("\(result.startDate.formatted());\(result.endDate.formatted());\(meanActivity);\(result.heartRateAverage)")
        }
        var concatSleeps = getConcatenatedSleeps(sleeps: potentialSleeps)
        concatSleeps = concatSleeps.filter({$0.getDuration() >= Constants.SLEEP_DURATION})

        var sleeps: [Sleep] = getValidatedSleeps(potentialSleeps: potentialSleeps, concatenatedSleeps: concatSleeps)
        sleeps = getSleepEpochs(sleeps: sleeps, epochs: epochs)

        logger.log("after Concatenated: \(sleeps.count)")

        sleeps = filterByLowActivityPercent(sleeps: sleeps, actQuartile: actQuartile, hrQuartile: hrQuartile)
        logger.log(";after percent: \(sleeps.count)")
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
    
    private func filterByLowActivityPercent(sleeps: [Sleep], actQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), hrQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double)) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {
            let sumActivity = sleep.epochs.map {$0.sumActivity}.reduce(0, +)
            let percent = 3600.0 * Double(sumActivity) / sleep.getDuration()
            
            if percent < 10 && sleep.heartRateAverage < hrQuartile.thirdQuartile {
                logger.log(";\(sleep.startDate.formatted());\(sleep.endDate.formatted());percent<;\(percent);\(sumActivity);\(sleep.getDuration());\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
                result.append(sleep)
            }
            else{
                logger.log(";\(sleep.startDate.formatted());\(sleep.endDate.formatted());percent>;\(percent);\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")

            }
        }
        return result
    }
    private func getValidatedSleeps(potentialSleeps: [Sleep], concatenatedSleeps: [Sleep]) -> [Sleep] {
        var result: [Sleep] = []
        for concatSleep in concatenatedSleeps {
            let validatedSleeps = potentialSleeps.filter({$0.startDate >= concatSleep.startDate && $0.endDate <= concatSleep.endDate})
            result.append(contentsOf: validatedSleeps)
        }
        return result
    }
    
    private func getConcatenatedSleeps(sleeps: [Sleep]) -> [Sleep] {
        var concatenatedSleeps: [Sleep] = []
        
        for (index, sleep) in sleeps.enumerated() {
            if sleeps.indices.contains(index - 1) {
                if sleep.startDate.timeIntervalSinceReferenceDate - (concatenatedSleeps.last?.endDate.timeIntervalSinceReferenceDate)! < Constants.CONCATENATE_SLEEP_DURATION {
                    let newSleep = Sleep(startDate: concatenatedSleeps.last!.startDate, endDate: sleep.endDate, epochs: [])
                    concatenatedSleeps.removeLast()
                    concatenatedSleeps.append(newSleep)
                } else {
                    concatenatedSleeps.append(sleep)
                }
            } else {
                concatenatedSleeps.append(sleep)
            }
        }
        return concatenatedSleeps
    }
    
    private func getStartDate(_ currentDate: Date) -> Date {
        var result = Calendar.current.startOfDay(for: currentDate)
        result = Calendar.current.date(byAdding: .day, value: -1, to: result)!
        result = Calendar.current.date(byAdding: .hour, value: 9, to: result)!
        return result
    }
    
}
