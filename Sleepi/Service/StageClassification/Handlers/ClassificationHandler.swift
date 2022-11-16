//
//  ClassificationHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "ClassificationHandler"
)

//Night Sleeps or Naps
class ClassificationHandler: BaseHandler {
    var secondHandler: Handler?
    
    init(with handler: Handler? = nil, secodHandler: Handler? = nil) {
        super.init(with: handler)
        self.secondHandler = secodHandler
    }
    
    override func handle(_ request: Request) -> LocalizedError? {
        var nightSleep: [Sleep] = []
        var naps: [Sleep] = []
        if let date = request.date {
            let referenceHour = Calendar.current.startOfDay(for: date)
            let tenAMnextDay = Calendar.current.date(byAdding: .hour, value: 10, to: referenceHour)!
            let eightPMprevDay = Calendar.current.date(byAdding: .hour, value: -4, to: referenceHour)!

            if let sleeps = request.sleeps {
                for sleep in sleeps {
                    if sleep.startDate < eightPMprevDay || sleep.startDate > tenAMnextDay {
                        let nap: Sleep = Sleep(startDate: sleep.startDate, endDate: sleep.endDate, stage: .Nap)
                        naps.append(nap)
                    } else {
                        nightSleep.append(sleep)
                    }
                }
            }
        }
        
        if naps.isEmpty == false {
            let request = StageRequest(sleeps: naps)
            if let secondHandler = secondHandler {
                if let error = secondHandler.handle(request) {
                    logger.error("\(error.localizedDescription)")
                }
            }
        }
        let newRequest = StageRequest(sleeps: nightSleep, activeEnergyBurned: request.activeEnergyBurned, heartRates: request.heartRates)
        return next?.handle(newRequest)
    }
    
}
