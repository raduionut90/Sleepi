//
//  EpochsFilterHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation

class EpochsFilterHandler: BaseHandler {
    override func handle(_ request: Request) -> LocalizedError? {
        
        let activities: [Record] = Utils.getActivitiesFromRawData(heartRates: request.heartRates!, activeEnergy: request.activeEnergyBurned!)
        let epochs: [Epoch] = Utils.getEpochs(activities: activities)
        
        if let sleeps = request.sleeps {
            var sleepsWithEpochs: [Sleep] = []
            for var sleep in sleeps {
                sleep.epochs = epochs.filter({$0.startDate >= sleep.startDate && $0.endDate <= sleep.endDate})
                sleep.epochs?.first?.startDate = sleep.startDate
                sleep.epochs?.last?.endDate = sleep.endDate
                sleepsWithEpochs.append(sleep)
            }
            let newRequest = StageRequest(sleeps: sleepsWithEpochs)
            return next?.handle(newRequest)

        }
        return nil
    }
}
