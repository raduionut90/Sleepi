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
    @Published var loading: Bool = true

    init(){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func performSleepDetection() {
        Task.init {
            loading = true

            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {

                    var currentDate = Date()
                    var aDayBefore = getStartDate(currentDate)
                    var sleeps: [HKCategorySample] = []
                    
                    while sleeps.isEmpty {
                        sleeps = await healthStore.getSleeps(startTime: aDayBefore, endTime: currentDate)
                        let lastSleepEndDate = sleeps.last?.endDate ?? aDayBefore
                        let heartRates = await healthStore.getSamples(startDate: aDayBefore, endDate: currentDate, type: .heartRate)
                        let activeEnergy = await healthStore.getSamples(startDate: aDayBefore, endDate: currentDate, type: .activeEnergyBurned)
                        
                        let activities: [Records] = Utils.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergy)
                        
                        logger.log("last sleep end \(lastSleepEndDate)")

                        let potentialSleeps = identifySleeps(activities: activities, lastSleepEndDate: lastSleepEndDate)
                        
                        for sleep in potentialSleeps {
                            try await healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                        }
                        
                        currentDate = aDayBefore
                        aDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: aDayBefore)!
                        if aDayBefore < Calendar.current.date(byAdding: .day, value: -14, to: Date())! {
                            break
                        }
                    }

                }
            }
            self.loading = false
        }
    }

    private func identifySleeps(activities: [Records], lastSleepEndDate: Date) -> [Sleep] {
        var tmpSleeps: [Sleep] = []
        let firstActivityIndex = activities.firstIndex(where: { $0.startDate >= lastSleepEndDate })!
        
        var startDate: Date?
        var lowActivityEpochs: [Epoch] = []
//        let epochs = Utils.getEpochsFromActivities(activities: Array(activities[firstActivityIndex...]), epochLenght: 1)
        let epochs = Utils.getEpochsFromActivitiesByTimeInterval(activities: Array(activities[firstActivityIndex...]), minutes: 5)
        let allEpochs = Utils.getEpochsFromActivitiesByTimeInterval(activities: activities, minutes: 5)

        let actQuartile = Utils.getQuartiles(values: allEpochs.compactMap({$0.meanActivity}) )
        let hrQuartile = Utils.getQuartiles(values: allEpochs.compactMap({$0.meanHR}) )

        logger.log(";\(actQuartile.firstQuartile);\(actQuartile.median);\(actQuartile.thirdQuartile)")
        logger.log(";\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
        
        for (index, epoch) in epochs.enumerated() {
            logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.meanActivity);\(epoch.meanHR)")
            
//            if epoch.records.contains(where: {$0.startDate.formatted() == "26/08/2022, 8:51"}){
//                logger.log("")
//            }

            if epoch.meanActivity.isNaN || epoch.meanActivity < actQuartile.firstQuartile &&
                epochs.indices.contains(index - 1) && epoch.startDate.timeIntervalSinceReferenceDate - epochs[index - 1].endDate.timeIntervalSinceReferenceDate < 600 {
                if startDate == nil {
                    startDate = epochs.indices.contains(index - 1) ? epochs[index - 1].endDate : epoch.startDate
                }
                lowActivityEpochs.append(epoch)
//            } else if epochs.indices.contains(index - 1) && epochs[index - 1].meanActivity < actQuartile.firstQuartile &&
//                        epoch.meanActivity < actQuartile.median {
//                if startDate != nil {
//                    lowActivityEpochs.append(epoch)
//                }
            } else {
                if startDate != nil && !lowActivityEpochs.isEmpty {
                    
                    if (lowActivityEpochs.last!.endDate.timeIntervalSinceReferenceDate) - startDate!.timeIntervalSinceReferenceDate > Constants.SLEEP_DURATION {
                        tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.startDate, epochs: []))
                    }
                    startDate = nil
                    lowActivityEpochs = []
                }
            }
            if epoch == epochs.last && startDate != nil && epoch.endDate.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate > Constants.SLEEP_DURATION {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.endDate, epochs: []))
            }
        }
        let sleeps: [Sleep] = proccesPotentialSleeps(potentialSleeps: tmpSleeps, epochs: epochs, actQuartile: actQuartile, hrQuartile: hrQuartile)
        return sleeps
    }
    private func proccesPotentialSleeps(potentialSleeps: [Sleep], epochs: [Epoch], actQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), hrQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double)) -> [Sleep] {
        var sleeps: [Sleep] = []
        sleeps = getConcatenatedSleeps(sleeps: potentialSleeps)
        logger.log("")
        sleeps = getSleepEpochs(sleeps: sleeps, epochs: epochs)

        logger.log("after Concatenated:")
        for result in sleeps {
            let meanActivity = result.epochs.filter({!$0.meanActivity.isNaN }).map {$0.meanActivity}.reduce(0, +)
            logger.log("\(result.startDate.formatted());\(result.endDate.formatted());\(meanActivity);\(result.heartRateAverage)")
        }

        logger.log(";before filter sleep duration \(sleeps.count)")
        sleeps = sleeps.filter( {$0.getDuration() >= 1500} )
        logger.log(";after filter sleep duration \(sleeps.count)")
//        sleeps = sleeps.filter( {$0.heartRateAverage < hrQuartile.thirdQuartile} )
        logger.log(";after filter hr quart Q3 \(sleeps.count)")
//        sleeps = filterSleepByHr(sleeps: sleeps, epochs: epochs)
        sleeps = filterByLowActivityPercent(sleeps: sleeps, actQuartile: actQuartile, hrQuartile: hrQuartile)
        logger.log(";result:")
        for result in sleeps {
            let meanActivity = result.epochs.filter({!$0.meanActivity.isNaN }).map {$0.meanActivity}.reduce(0, +)

            logger.log(";\(result.startDate.formatted());\(result.endDate.formatted());\(meanActivity);\(result.heartRateAverage)")
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
                let sleepEpochs = Array(epochs[firstEpoch..<lastEpoch])
                let newSleep = Sleep(startDate: sleep.startDate, endDate: sleep.endDate, epochs: sleepEpochs)
                result.append(newSleep)
            }
        }
        return result
    }
    
    private func filterByLowActivityPercent(sleeps: [Sleep], actQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), hrQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double)) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {
            let sumActivity = sleep.epochs.filter({!$0.meanActivity.isNaN }).map {$0.meanActivity}.reduce(0, +)

            let percent = 3600.0 * Double(sumActivity) / sleep.getDuration()
            
            logger.log(";\(sleep.startDate.formatted());\(sleep.endDate.formatted());percent;\(percent);\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
            if percent < 2 && sleep.heartRateAverage < hrQuartile.median {
                result.append(sleep)
            } else if percent < 5 && sleep.heartRateAverage < hrQuartile.firstQuartile {
                result.append(sleep)
                logger.log(";\(sleep.startDate.formatted());\(sleep.endDate.formatted());5percent;\(percent);\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
            }
        }
        return result
    }
    
    private func getConcatenatedSleeps(sleeps: [Sleep]) -> [Sleep] {
        var result: [Sleep] = []
        for (index, sleep) in sleeps.enumerated() {
            if sleeps.indices.contains(index - 1) {
                if sleep.startDate.timeIntervalSinceReferenceDate - (result.last?.endDate.timeIntervalSinceReferenceDate)! < 300 {
                    let newSleep = Sleep(startDate: result.last!.startDate, endDate: sleep.endDate, epochs: [])
                    result.removeLast()
                    result.append(newSleep)
                } else {
                    result.append(sleep)
                }
            } else {
                result.append(sleep)
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
