//
//  EpochsRefactoringHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "EpochsTimeRefactoringHandler"
)

class EpochsTimeRefactoringHandler: BaseHandler {
    
    override func handle(_ request: Request) async throws {
        if let sleeps = request.sleeps {
            var resultSleeps: [Sleep] = []
            for sleep in sleeps {
//                logger.debug(";detector;EpochsTimeRefactoringHandler;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public)")
                
                if let epochs = sleep.epochs {
                    var result: [Epoch] = []
                    for epoch in epochs {
                        if result.isEmpty {
                            result.append(epoch)
                        } else {
                            if result.last!.stage != epoch.stage && epoch.getDuration() > 300 {
                                result.last!.endDate = epoch.startDate
                                result.append(epoch)
                            }
                        }
                    }
                    
                    result.last?.endDate = sleep.endDate
                    
                    var newSleep = Sleep(startDate: sleep.startDate, endDate: sleep.endDate)
                    newSleep.epochs = result
                    resultSleeps.append(newSleep)
                }
            }
            let newRequest = StageRequest(sleeps: resultSleeps, date: request.date)
            try await next?.handle(newRequest)
        }
    }
}
