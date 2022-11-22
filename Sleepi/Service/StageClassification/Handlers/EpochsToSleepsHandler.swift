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
    
    fileprivate func checkContinuity(_ request: Request, _ sleep: Sleep, _ sleepsResult: inout [Sleep]) async throws -> Sleep? {
        if let existingSleeps = try await SleepHelper.shared.getSleeps(startDate: Calendar.current.date(byAdding: .hour, value: -48, to: request.date!)!, endDate: request.date!) {
            
            if let lastExistingSleep = existingSleeps.last {
                
                if !sleep.isNap() && !lastExistingSleep.isNap() && sleep.startDate.timeIntervalSinceReferenceDate - lastExistingSleep.endDate.timeIntervalSinceReferenceDate < 10800{ // 3h
                    var awake = Sleep(startDate: lastExistingSleep.endDate, endDate: sleep.startDate)
                    awake.stage = .Awake
                    return awake
                }
            }
        }
        

        return nil
    }
    
    override func handle(_ request: Request) async throws {
        var sleepsResult: [Sleep] = []
        
        if let sleeps = request.sleeps {
            for (index, sleep) in sleeps.enumerated() {
                if index == 0 {
                    if let awake = try await checkContinuity(request, sleep, &sleepsResult) {
                        sleepsResult.append(awake)
                        logger.debug(";detector;EpochsToSleepsHandler;\(awake.startDate.formatted(), privacy: .public);\(awake.endDate.formatted(), privacy: .public);\(awake.stage!.rawValue);continuity")
                    }
                }
                    
                if sleeps.indices.contains(index - 1) && !sleeps[index - 1].isNap() && !sleep.isNap() {
                    var awake = Sleep(startDate: sleeps[index - 1].endDate, endDate: sleep.startDate)
                    if awake.getDuration() < 10800 { // 3h
                        awake.stage = .Awake
                        sleepsResult.append(awake)
                        logger.debug(";detector;EpochsToSleepsHandler;\(awake.startDate.formatted(), privacy: .public);\(awake.endDate.formatted(), privacy: .public);\(awake.stage!.rawValue)")
                    }
                }
                if let epochs = sleep.epochs {
                    for epoch in epochs {
                        if let stage = epoch.stage {
                            var sleepWithStage = Sleep(startDate: epoch.startDate, endDate: epoch.endDate)
                            sleepWithStage.stage = stage
                            logger.debug(";detector;EpochsToSleepsHandler;\(sleepWithStage.startDate.formatted(), privacy: .public);\(sleepWithStage.endDate.formatted(), privacy: .public);\(sleepWithStage.stage!.rawValue)")
                            sleepsResult.append(sleepWithStage)
                        }
                    }
                }
            }
        }
        if sleepsResult.isEmpty == false {
            let newRequest = StageRequest(sleeps: sleepsResult)
            try await next?.handle(newRequest)
        }
    }
}
