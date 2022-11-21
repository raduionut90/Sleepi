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
class SleepClassificationHandler: BaseHandler {
    var secondHandler: Handler?
    
    init(with handler: Handler? = nil, secodHandler: Handler? = nil) {
        super.init(with: handler)
        self.secondHandler = secodHandler
    }
    
    override func handle(_ request: Request) async throws {
        var nightSleep: [Sleep] = []
        var naps: [Sleep] = []
            
        if let sleeps = request.sleeps {
            for sleep in sleeps {
                logger.debug(";detector;ClassificationHandler;\(sleep.startDate.formatted(), privacy: .public);\(sleep.endDate.formatted(), privacy: .public)")
                
                if sleep.isNap() {
                    var nap: Sleep = Sleep(startDate: sleep.startDate, endDate: sleep.endDate)
                    nap.stage = .Nap
                    naps.append(nap)
                } else {
                    nightSleep.append(sleep)
                }
            }
        }
        
        if naps.isEmpty == false {
            let request = StageRequest(sleeps: naps)
            if let secondHandler = secondHandler {
                try await secondHandler.handle(request)
            }
        }
        let newRequest = StageRequest(sleeps: nightSleep, date: request.date, activeEnergyBurned: request.activeEnergyBurned, heartRates: request.heartRates)
        try await next?.handle(newRequest)
    }
    
}
