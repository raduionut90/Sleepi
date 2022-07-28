//
//  Activity.swift
//  Sleepi
//
//  Created by Ionut Radu on 03.07.2022.
//

import Foundation
import os

class Activity: Equatable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Activity.self)
    )
    
    internal init(startDate: Date, endDate: Date? = nil, hr: Double? = nil, actEng: Double? = nil, hrv: Double? = nil, rhr: Double? = nil, respRate: Double? = nil, stage: SleepStage? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.hr = hr
        self.actEng = actEng
        self.hrv = hrv
        self.rhr = rhr
        self.respRate = respRate
        self.stage = stage
    }
    
    static func == (lhs: Activity, rhs: Activity) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let startDate: Date
    var endDate: Date?
    var hr: Double?
    var actEng: Double?
    var hrv: Double?
    var rhr: Double?
    var respRate: Double?
    var stage: SleepStage?
    
//    init(startDate: Date, hr: Double){
//        self.startDate = startDate
//        self.hr = hr
//    }
//
//    init(startDate: Date, endDate: Date, actEng: Double){
//        self.startDate = startDate
//        self.endDate = endDate
//        self.actEng = actEng
//    }
    
    func setStage(_ nsHeartRateAverage: Double) {
        var result: SleepStage = SleepStage.LightSleep
                
        if let hr = self.hr {
            if hr <= nsHeartRateAverage - 2 {
                result = SleepStage.DeepSleep
            } else if hr > nsHeartRateAverage + 2 {
                result = SleepStage.RemSleep
            }
        }
        self.stage = result
//        Self.logger.debug("\(self.startDate) hr: \(self.hr!, format: .fixed), hrAvr: \(nsHeartRateAverage), stage: \(result.rawValue, privacy: .private)")
        print("\(startDate.formatted()) \(hr!) \(result.rawValue)")
//        Self.logger.debug("hr: \(self.hr), hrAvr: \(nsHeartRateAverage), stage: \(self.stage)")
    }
}
