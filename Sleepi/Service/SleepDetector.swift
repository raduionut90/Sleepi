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
                        let sortedActivEnergy = activities.filter( { $0.actEng != nil } ).map({ $0.actEng! } )
                        let actQuartiles = Utils.getQuartiles(values: sortedActivEnergy)
                        let hrQuartiles = Utils.getQuartiles(values: activities.filter( { $0.hr != nil } ).map({ $0.hr! } ))
                        logger.log("\(actQuartiles.firstQuartile);\(actQuartiles.median);\(actQuartiles.thirdQuartile)")
                        logger.log("\(hrQuartiles.firstQuartile);\(hrQuartiles.median);\(hrQuartiles.thirdQuartile)")
                        logger.log("last sleep end \(lastSleepEndDate)")

                        let potentialSleeps = identifySleeps(activities: activities, actQuartile: actQuartiles, hrQuartile: hrQuartiles, lastSleepEndDate: lastSleepEndDate)
                        
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

    private func identifySleeps(activities: [Records], actQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), hrQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), lastSleepEndDate: Date) -> [Sleep] {
        var tmpSleeps: [Sleep] = []
        let firstActivityIndex = activities.firstIndex(where: { $0.startDate >= lastSleepEndDate })!
        
        var startDate: Date?
        var lowActivityEpochs: [Epoch] = []
        let epochs = Utils.getEpochsFromActivities(activities: Array(activities[firstActivityIndex...]), epochLenght: 1)
        let epochsTest = Utils.getEpochsFromActivitiesByTimeInterval(activities: Array(activities[firstActivityIndex...]), minutes: 3)
        for epo in epochsTest {
            print("\(epo.startDate.formatted());\(epo.endDate.formatted());\(epo.getTotalActivities())")
        }

        for epoch in epochs {
            logger.log("\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.meanActivity);\(epoch.meanHR)")
            
//            if epoch.records.contains(where: {$0.startDate.formatted() == "23.08.2022, 2:07"}){
//                logger.log("")
//            }

            if epoch.meanActivity.isNaN || epoch.meanActivity < actQuartile.median && !epoch.records.contains(where: { $0.firstAfterGap ?? false }){
                if startDate == nil {
                    startDate = epoch.records.first?.startDate
                }
                lowActivityEpochs.append(epoch)
            } else {
                if startDate != nil && !lowActivityEpochs.isEmpty {
                    
                    if (lowActivityEpochs.last!.endDate.timeIntervalSinceReferenceDate) - startDate!.timeIntervalSinceReferenceDate > Constants.SLEEP_DURATION {
                        tmpSleeps.append(Sleep(startDate: startDate!, endDate: lowActivityEpochs.last!.records.last!.endDate, epochs: []))
                    }
                    startDate = nil
                    lowActivityEpochs = []
                }
            }
            if epoch == epochs.last && startDate != nil {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.records.last!.endDate, epochs: lowActivityEpochs))
            }
        }
        let sleeps: [Sleep] = proccesPotentialSleeps(potentialSleeps: tmpSleeps, epochs: epochs, actQuartile: actQuartile, hrQuartile: hrQuartile)
        return sleeps
    }
    private func proccesPotentialSleeps(potentialSleeps: [Sleep], epochs: [Epoch], actQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), hrQuartile: (firstQuartile: Double, median: Double, thirdQuartile: Double)) -> [Sleep] {
        var sleeps: [Sleep] = []
//        sleeps = getConcatenatedSleeps(sleeps: tmpSleeps)
        logger.log("")
        sleeps = getSleepEpochs(sleeps: potentialSleeps, epochs: epochs)

        logger.log("after Concatenated:")
        for result in sleeps {
            let meanActivity = result.epochs.compactMap({$0.meanActivity}).filter({!$0.isNaN}).reduce(0, +) / Double(result.epochs.compactMap({$0.meanActivity}).filter({!$0.isNaN}).count)
            logger.log("\(result.startDate.formatted());\(result.endDate.formatted());\(meanActivity);")
        }

        logger.log("before filter sleep duration \(sleeps.count)")
        sleeps = sleeps.filter( {$0.getDuration() >= Constants.SLEEP_DURATION} )
        logger.log("after filter sleep duration \(sleeps.count)")
//        sleeps = sleeps.filter( {$0.heartRateAverage < hrQuartile.thirdQuartile} )
        logger.log("after filter hr quart Q3 \(sleeps.count)")
//        sleeps = filterSleepByHr(sleeps: sleeps, epochs: epochs)
        sleeps = filterByLowActivityPercent(sleeps: sleeps, actQuartile: actQuartile, hrQuartile: hrQuartile)
        logger.log("result:")
        for result in sleeps {
            let meanActivity = result.epochs.compactMap({$0.meanActivity}).filter({!$0.isNaN}).reduce(0, +) / Double(result.epochs.compactMap({$0.meanActivity}).filter({!$0.isNaN}).count)

            logger.log("\(result.startDate.formatted());\(result.endDate.formatted());\(result.heartRateAverage);\(meanActivity) ")
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
            let highActivities = sleep.epochs.filter( { !$0.meanActivity.isNaN && $0.meanActivity > actQuartile.firstQuartile} ).count

            let percent = 3600.0 * Double(highActivities) / sleep.getDuration()
            
            logger.log("\(sleep.startDate.formatted());\(sleep.endDate.formatted());percent;\(percent);\(sleep.heartRateAverage);\(hrQuartile.firstQuartile);\(hrQuartile.median);\(hrQuartile.thirdQuartile)")
            if percent < 5 {
                result.append(sleep)
            } else if percent < 15 && sleep.heartRateAverage < hrQuartile.firstQuartile {
                result.append(sleep)
                logger.log("percent 15%")
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
