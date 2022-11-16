//
//  EpochsToSleepsHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation

class EpochsToSleepsHandler: BaseHandler {
    override func handle(_ request: Request) -> LocalizedError? {
        var sleepsResult: [Sleep] = []
        if let sleeps = request.sleeps {
            for (index, sleep) in sleeps.enumerated() {
                if sleeps.indices.contains(index - 1) {
                    let awake = Sleep(startDate: sleeps[index - 1].endDate, endDate: sleep.startDate, stage: .Awake)
                    sleepsResult.append(awake)
                }
                if let epochs = sleep.epochs {
                    for epoch in epochs {
                        if let stage = epoch.stage {
                            let sleepWithStage = Sleep(startDate: epoch.startDate, endDate: epoch.endDate, stage: stage)
                            sleepsResult.append(sleepWithStage)
                        }
                    }
                }
            }
        }
        if sleepsResult.isEmpty == false {
            let newRequest = StageRequest(sleeps: sleepsResult)
            return next?.handle(newRequest)
        }
        return nil
    }
}
