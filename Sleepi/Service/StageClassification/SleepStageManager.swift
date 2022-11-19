//
//  SleepStageManager.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SleepStageManager"
)

class SleepStageManager {
    let request: Request
    
    init(request: Request) {
        self.request = request
    }
    
    
    func executePipeline() async throws {
        try self.checkRequest(self.request)
        // Save sleeps
        let saveHandler = SaveHandler()
        // TimeRefactorByStage
        
        // EpochsToSleepsWithStage - epochs to sleeps
        let epochsToSleepsHandler = EpochsToSleepsHandler(with: saveHandler)
        // epoch refactoring handler - Time refactoring
        let epochTimeRefactoringHandler = EpochsTimeRefactoringHandler(with: epochsToSleepsHandler)
        // epochClassification - stage classification epochs
        let epochClassification = EpochsClassificationHandler(with: epochTimeRefactoringHandler)
        // setting epochs to sleep
        let epochsFilterHandler = EpochsFilterHandler(with: epochClassification)
        // night sleeps and naps classification
        let classificationHandler = SleepClassificationHandler(with: epochsFilterHandler, secodHandler: saveHandler)
        
        if let sleeps = request.sleeps {
            for sleep in sleeps {
                logger.debug(";detector;SleepStageManager;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public)")
            }
        }
        if let error = classificationHandler.handle(self.request) {
            logger.error("\(error.localizedDescription)")
        }
    }
    
    
    private func checkRequest(_ request: Request) throws {
        guard request.sleeps?.isEmpty == false else {
            logger.error("emptySleeps")
            throw DetectionError.emptySleeps
        }
        guard request.heartRates?.isEmpty == false else {
            logger.error("emptyHeartRates")
            throw DetectionError.emptyHeartRates
        }
        guard request.activeEnergyBurned?.isEmpty == false else {
            logger.error("emptyActiveEnergyBurned")
            throw DetectionError.emptyActiveEnergyBurned
        }
        guard request.date != nil else {
            logger.error("emptyDate")
            throw DetectionError.emptyDate
        }
    }
    
//    private func startClassification(sleeps: [Sleep]) {
//        let nightAndNapSleeps: (nightSleep: [Sleep], naps: [Sleep]) = self.sleepFilter(sleeps: identifiedSleeps, date: endDate)
//        try await finalProcessing(nightAndNapSleeps, heartRates, activeEnergy, healthStore)
//    }
//
//    fileprivate func finalProcessing(_ sleeps: (nightSleep: [Sleep], naps: [Sleep]), _ heartRates: [HKQuantitySample], _ activeEnergy: [HKQuantitySample], _ healthStore: HealthStore) async throws {
//
//        for (index, sleep) in sleeps.nightSleep.enumerated() {
//            let filteredHeartRates = heartRates.filter({$0.startDate >= sleep.startDate && $0.endDate <= sleep.endDate})
//            let filteredActiveEnergyBurned = activeEnergy.filter({$0.startDate >= sleep.startDate && $0.endDate <= sleep.endDate})
//            let activities: [Record] = Utils.getActivitiesFromRawData(heartRates: filteredHeartRates, activeEnergy: filteredActiveEnergyBurned)
//            var tmpEpochs: [Epoch] = Utils.getEpochs(activities: activities)
//            stageClasification(epochs: &tmpEpochs)
//            let epochs = processEpochs(epochs: tmpEpochs)
//
//            for epoch in epochs {
//                try await healthStore.saveSleepStages(startTime: epoch.startDate, endTime: epoch.endDate, stage: epoch.stage!.rawValue)
//                logger.log(";stage;stage;\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.stage!.rawValue)")
//            }
//            if sleeps.nightSleep.indices.contains(index + 1) {
//                try await healthStore.saveSleepStages(startTime: sleep.endDate, endTime: sleeps.nightSleep[index + 1].startDate, stage: SleepStage.Awake.rawValue)
//                logger.log(";awake;stage;\(sleep.endDate.formatted());\(sleeps.nightSleep[index + 1].startDate.formatted());\(SleepStage.Awake.rawValue)")
//            }
//        }
//
//        // nap case
//        for nap in sleeps.naps {
//            try await healthStore.saveSleepStages(startTime: nap.startDate, endTime: nap.endDate, stage: SleepStage.Nap.rawValue)
//            logger.log(";nap;stage;\(nap.startDate.formatted());\(nap.endDate.formatted());\(SleepStage.Nap.rawValue)")
//        }
//    }
//
//    private func stageClasification(epochs: inout [Epoch]) {
//
//            let activityQuartiles = Utils.getQuartiles(values: epochs.map {$0.sumActivity} )
//            let hrQuartiles = Utils.getQuartiles(values: epochs.map {$0.meanHR} )
//
//            logger.log(";\(activityQuartiles.firstQuartile);\(activityQuartiles.median);\(activityQuartiles.thirdQuartile)")
//            logger.log(";\(hrQuartiles.firstQuartile);\(hrQuartiles.median);\(hrQuartiles.thirdQuartile)")
//
//            for (index, epoch) in epochs.enumerated() {
//
//                logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR)")
//                let lastEpoch = epochs.indices.contains(index - 1) ? epochs[index - 1] : nil
//
//                if lastEpoch != nil && !lastEpoch!.meanHR.isNaN {
//                    if (epoch.meanHR < lastEpoch!.meanHR - 5 || epoch.meanHR < hrQuartiles.firstQuartile ) && epoch.sumActivity == 0 {
//                        epoch.stage = SleepStage.DeepSleep
//                    } else if ((epoch.meanHR > lastEpoch!.meanHR + 5 || epoch.meanHR >= hrQuartiles.thirdQuartile) ) || (epoch.sumActivity > 0.1 && epoch.meanHR.isNaN ){
//                        epoch.stage = SleepStage.RemSleep
//                    } else if (((lastEpoch!.meanHR - 2)...(lastEpoch!.meanHR + 2)).contains(epoch.meanHR) ||
//                               lastEpoch!.meanHR.isNaN && epoch.meanHR.isNaN) &&
//                                ((lastEpoch!.sumActivity - 0.05 ... lastEpoch!.sumActivity + 0.05).contains(epoch.sumActivity) ||
//                                lastEpoch!.sumActivity.isNaN && epoch.sumActivity.isNaN)  {
//                        epoch.stage = lastEpoch!.stage
//                    } else {
//                        epoch.stage = SleepStage.LightSleep
//                    }
//                } else {
//                    if epoch.sumActivity == 0 && (epoch.meanHR < hrQuartiles.firstQuartile || epoch.meanHR.isNaN) {
//                        epoch.stage = SleepStage.DeepSleep
//                    } else if (epoch.meanHR >= hrQuartiles.thirdQuartile || epoch.meanHR.isNaN) && epoch.sumActivity > 0.2 {
//                        epoch.stage = SleepStage.RemSleep
//                    } else {
//                        epoch.stage = SleepStage.LightSleep
//                    }
//                }
//            }
//
//    }
//
//    private func sleepFilter(sleeps: [Sleep], date: Date) -> (nightSleep: [Sleep], naps: [Sleep]) {
//        var nightSleep: [Sleep] = []
//        var naps: [Sleep] = []
//        var referenceHour = Calendar.current.startOfDay(for: date)
//        referenceHour = Calendar.current.date(byAdding: .hour, value: 10, to: referenceHour)!
//
//        for sleep in sleeps {
//            if sleep.startDate > referenceHour {
//                naps.append(sleep)
//            } else {
//                nightSleep.append(sleep)
//            }
//        }
//        return (nightSleep, naps)
//    }
//
//    private func processEpochs(epochs: [Epoch]) -> [Epoch] {
//        var result: [Epoch] = []
//        for (index, epoch) in epochs.enumerated(){
//            if epochs.indices.contains(index + 1) {
//                epoch.endDate = epochs[index + 1].startDate
//            }
//            if result.isEmpty {
//                result.append(epoch)
//            } else {
//                if result.last!.stage != epoch.stage {
//                    result.last!.endDate = epoch.startDate
//                    result.append(epoch)
//                }
//            }
//        }
//        return result
//    }
//
}
