//
//  Activity.swift
//  Sleepi
//
//  Created by Ionut Radu on 03.07.2022.
//

import Foundation

class Activity: Equatable {
    static func == (lhs: Activity, rhs: Activity) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let startDate: Date
    var endDate: Date?
    var hr: Double?
    var actEng: Double?
    var stage: SleepType?
    
    init(startDate: Date, hr: Double){
        self.startDate = startDate
        self.hr = hr
    }
    
    init(startDate: Date, endDate: Date, actEng: Double){
        self.startDate = startDate
        self.endDate = endDate
        self.actEng = actEng
    }
    
    func setStage(_ heartRateNightSleepsAverage: Double) {
        var result: SleepType = SleepType.LightSleep
//        print("\(startDate.formatted());\(hr!)")
                
        if let hr = self.hr {
            if hr <= heartRateNightSleepsAverage - 2 {
                result = SleepType.DeepSleep
            } else if hr > heartRateNightSleepsAverage + 8 {
                result = SleepType.RemSleep
            }
        }
        self.stage = result
    }
}
