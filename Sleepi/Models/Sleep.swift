//
//  Step.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation

struct Sleep: Hashable, Identifiable, Equatable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let epochs: [Epoch]
    let heartRateAverage: Double

    init(startDate: Date, endDate: Date, epochs: [Epoch]) {
        self.startDate = startDate
        self.endDate = endDate
        self.epochs = epochs
        self.heartRateAverage = Utils.getAverage(values: epochs.map( {$0.meanHR} ))
        self.updateEpochEndTime()
    }
    
    func getDuration() -> Double {
        return self.endDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate
    }
    
    fileprivate func updateMeanHr(_ epoch: Epoch, _ index: Int) {
        //update meanHr if nil
        if epoch.meanHR.isNaN {
            let prevMeanHr: Double = epochs[..<index].reversed().first( where: {!$0.meanHR.isNaN} ).map( {$0.meanHR} ) ?? 0.0
            let nextMeanHr: Double = epochs[index...].first( where: {!$0.meanHR.isNaN} ).map({$0.meanHR} ) ?? 0.0
            let meanHR = (prevMeanHr + nextMeanHr) / 2
            epoch.meanHR = meanHR
        }
    }
    
    private func updateEpochEndTime() {
        for (index, epoch) in epochs.enumerated() {
            if index < epochs.count - 1 {
                epoch.endDate = epochs[index + 1].startDate
            }
            if index == epochs.count - 1 {
                epoch.endDate = self.endDate
            }
            
            updateMeanHr(epoch, index)
        }
    }
    
    func getStageSleepDuration(allSleepsHrAverage: Double, stage: SleepStage) -> Double {
        var result: [TimeInterval] = []
        
//        if stage == .LightSleep {
//            result.append(self.activities.first!.startDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate)
//        }
        
        for epoch in epochs {
            switch stage {
            case .DeepSleep:
                if epoch.sleepClasification == .DeepSleep {
                    result.append(epoch.endDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate)
                }
            case .LightSleep:
                if epoch.sleepClasification == .LightSleep {
                    result.append(epoch.endDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate)
                }
            case .RemSleep:
                if epoch.sleepClasification == .RemSleep {
                    result.append(epoch.endDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate)
                }
            case .Awake:
                ()
            }
        }
        return result.reduce(0, +);
    }
}
