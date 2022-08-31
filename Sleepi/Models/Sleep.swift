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
    var epochs: [Epoch]
    let heartRateAverage: Double

    init(startDate: Date, endDate: Date, epochs: [Epoch]) {
        self.startDate = startDate
        self.endDate = endDate
        self.epochs = epochs
        self.heartRateAverage = Utils.getAverage(values: epochs.map( {$0.meanHR} ))
//        self.updateEpochEndTime()
    }
    
    func getDuration() -> Double {
        return self.endDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate
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
