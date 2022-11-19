//
//  EpochsToSleepsHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "EpochsToSleepsHandler"
)

class EpochsToSleepsHandler: BaseHandler {
    override func handle(_ request: Request) -> LocalizedError? {
        var sleepsResult: [Sleep] = []
        if let sleeps = request.sleeps {
            for (index, sleep) in sleeps.enumerated() {
                if sleeps.indices.contains(index - 1) &&
                    sleep.startDate.timeIntervalSinceReferenceDate - sleeps[index - 1].endDate.timeIntervalSinceReferenceDate < 18000 // 5 hours
                {
                    let awake = Sleep(startDate: sleeps[index - 1].endDate, endDate: sleep.startDate, stage: .Awake)
                    sleepsResult.append(awake)
                }
                if let epochs = sleep.epochs {
                    for epoch in epochs {
                        if let stage = epoch.stage {
                            let sleepWithStage = Sleep(startDate: epoch.startDate, endDate: epoch.endDate, stage: stage)
                            logger.debug(";detector;EpochsToSleepsHandler;\(sleepWithStage.startDate.formatted(), privacy: .public);\(sleepWithStage.endDate.formatted(), privacy: .public);\(sleepWithStage.stage!.rawValue)")
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
