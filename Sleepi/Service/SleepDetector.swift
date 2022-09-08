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
    
    func performSleepDetection() async throws {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    
                    var currentDate = Date()
                    var aDayBefore = Calendar.current.date(byAdding: .hour, value: -24, to: currentDate)!
                    var sleeps: [HKCategorySample] = []
                    
                    while sleeps.isEmpty {
                        sleeps = await healthStore.getSleeps(startTime: aDayBefore, endTime: currentDate)
                        let lastSleepEndDate = sleeps.last?.endDate ?? aDayBefore
                        let heartRates = await healthStore.getSamples(startDate: aDayBefore, endDate: currentDate, type: .heartRate)
                        let activeEnergy = await healthStore.getSamples(startDate: aDayBefore, endDate: currentDate, type: .activeEnergyBurned)
                        
                        let activities: [Records] = Utils.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergy)
                        
                        if !activities.isEmpty {
                            logger.log("last sleep end \(lastSleepEndDate)")

                            let potentialSleeps = identifySleeps(activities: activities, lastSleepEndDate: lastSleepEndDate)
                            
                            for sleep in potentialSleeps {
                                try await healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                            }
                        } else {
                            logger.log("no activities \(aDayBefore) - \(currentDate)")
                        }
                        
                        currentDate = aDayBefore
                        aDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: aDayBefore)!
                        if aDayBefore < Calendar.current.date(byAdding: .day, value: -14, to: Date())! {
                            break
                        }
                    }

                }
            }        
    }

    private func identifySleeps(activities: [Records], lastSleepEndDate: Date) -> [Sleep] {
        var tmpSleeps: [Sleep] = []
        let firstActivityIndex = activities.firstIndex(where: { $0.startDate >= lastSleepEndDate })!
        
        var startDate: Date?
        var lowActivityEpochs: [Epoch] = []

        let relevantActivities = Array(activities[firstActivityIndex...])
        let epochs = Utils.getEpochs(activities: relevantActivities, minutes: 3)
        let allEpochs = Utils.getEpochs(activities: activities, minutes: 3)

        let actQuartile = Utils.getQuartiles(values: allEpochs.compactMap({$0.sumActivity}) )
        let hrQuartile = Utils.getQuartiles(values: allEpochs.compactMap({$0.meanHR}) )

        logger.log(";\(actQuartile.firstQuartile);\(actQuartile.median);\(actQuartile.thirdQuartile)")
        logger.log(";\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
        
        for (index, epoch) in epochs.enumerated() {
//            logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR)")
            for record in epoch.records {
                logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR);\(record.startDate.formatted());\(record.endDate.formatted());\(record.actEng ?? 0);\(record.hr ?? 999)")

            }
            
//            if epoch.records.contains(where: {$0.startDate.formatted() == "05/09/2022, 21:57"}){
//                logger.log("")
//            }
            var counter = 0
            let lastEpoch = epochs.indices.contains(index - 1) ? epochs[index - 1] : nil
            if epoch.sumActivity < 0.3 && epochs.indices.contains(index - 1) && epoch.startDate.timeIntervalSinceReferenceDate - epochs[index - 1].endDate.timeIntervalSinceReferenceDate < 600 {
                if epochs.indices.contains(index - 1)  {
                    if startDate == nil {
                        startDate = epochs[index - 1].records.last!.endDate
//                        startDate = epoch.startDate
                    }
                    lowActivityEpochs.append(epoch)
                } else if !epochs.indices.contains(index - 1) {
                    startDate = epoch.startDate
                    lowActivityEpochs.append(epoch)
                }
                counter = 0
            }
            else if epoch.sumActivity < 0.5 && counter <= 1 && startDate != nil {
                lowActivityEpochs.append(epoch)
                counter += 1
            }
            else {
                if startDate != nil && !lowActivityEpochs.isEmpty {
                    
                    if (lowActivityEpochs.last!.endDate.timeIntervalSinceReferenceDate) - startDate!.timeIntervalSinceReferenceDate > Constants.MINI_SLEEP_DURATION {
                        tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.startDate, epochs: []))
                    }
                    startDate = nil
                    lowActivityEpochs = []
                }
            }
            if epoch == epochs.last && startDate != nil && epoch.endDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > Constants.MINI_SLEEP_DURATION {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.startDate, epochs: []))
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
    
    private func filterSleepByHr(sleeps: [Sleep], epochs: [Epoch]) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {

            let lastEpochs = epochs.reversed().filter({!$0.meanHR.isNaN}).first(where: {$0.startDate < sleep.startDate})
            let nextEpochs = epochs.filter({!$0.meanHR.isNaN}).first(where: {$0.startDate > sleep.endDate})
            // 95% from max
            let maxHr = max(lastEpochs?.meanHR ?? 0, nextEpochs?.meanHR ?? 0)
            if sleep.heartRateAverage < maxHr {
                result.append(sleep)
            } else {
                logger.log("Sleep: \(sleep.startDate.formatted()) - \(sleep.endDate.formatted()) ignored due to HR \(sleep.heartRateAverage), maxHR: \(maxHr)")
            }

        }
        return result
    }
    
    private func getSleepEpochs(sleeps: [Sleep], epochs: [Epoch]) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {
            let firstEpoch = epochs.firstIndex {$0.startDate >= sleep.startDate}!
            let lastEpoch = (epochs.firstIndex {$0.endDate >= sleep.endDate})!
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
            
            if percent < 5 && sleep.heartRateAverage < hrQuartile.median {
                logger.log(";\(sleep.startDate.formatted());\(sleep.endDate.formatted());percent<;\(percent);\(sumActivity);\(sleep.getDuration());\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
                result.append(sleep)
            }
//            else if percent < 5 && sleep.heartRateAverage < hrQuartile.firstQuartile {
//                result.append(sleep)
//                logger.log(";\(sleep.startDate.formatted());\(sleep.endDate.formatted());5percent;\(percent);\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
//            }
            else{
                logger.log(";\(sleep.startDate.formatted());\(sleep.endDate.formatted());percent>;\(percent);\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")

            }
//            else if percent < 6 && sleep.heartRateAverage < hrQuartile.median {
//                result.append(sleep)
//                logger.log(";\(sleep.startDate.formatted());\(sleep.endDate.formatted());5percent;\(percent);\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
//            }
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
