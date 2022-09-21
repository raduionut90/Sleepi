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
    
    func getStageSleepDuration(stage: SleepStage) -> Double {
        var result: [TimeInterval] = []
        
//        if stage == .LightSleep {
//            result.append(self.activities.first!.startDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate)
//        }
        
        for (index, epoch) in epochs.enumerated() {
            switch stage {
            case .DeepSleep:
                if epoch.stage == .DeepSleep {
                    let timeInterval = epochs.indices.contains(index + 1) ? epochs[index + 1].startDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate : self.endDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate
                    result.append(timeInterval)
                }
            case .LightSleep:
                if epoch.stage == .LightSleep {
                    let timeInterval = epochs.indices.contains(index + 1) ? epochs[index + 1].startDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate : self.endDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate
                    result.append(timeInterval)
                }
            case .RemSleep:
                if epoch.stage == .RemSleep {
                    let timeInterval = epochs.indices.contains(index + 1) ? epochs[index + 1].startDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate : self.endDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate
                    result.append(timeInterval)                }
            case .Awake:
                ()
            }
        }
        return result.reduce(0, +);
    }
}
