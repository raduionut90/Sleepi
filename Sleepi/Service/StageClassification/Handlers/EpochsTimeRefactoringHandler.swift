//
//  EpochsRefactoringHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation

class EpochsTimeRefactoringHandler: BaseHandler {
    
    override func handle(_ request: Request) -> LocalizedError? {
        if let sleeps = request.sleeps {
            var resultSleeps: [Sleep] = []
            for sleep in sleeps {
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
                    
                    let newSleep = Sleep(startDate: sleep.startDate, endDate: sleep.endDate, epochs: result)
                    resultSleeps.append(newSleep)
                }
            }
            let newRequest = StageRequest(sleeps: resultSleeps)
            return next?.handle(newRequest)
        }
        return nil
    }
}
