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
    var stage: SleepStage?
    
    init(startDate: Date, hr: Double){
        self.startDate = startDate
        self.hr = hr
    }
    
    init(startDate: Date, endDate: Date, actEng: Double){
        self.startDate = startDate
        self.endDate = endDate
        self.actEng = actEng
    }
    
    func setStage(_ nsHeartRateAverage: Double) {
        var result: SleepStage = SleepStage.LightSleep
                
        if let hr = self.hr {
            if hr <= nsHeartRateAverage - 2 {
                result = SleepStage.DeepSleep
            } else if hr > nsHeartRateAverage + 8 {
                result = SleepStage.RemSleep
            }
        }
        self.stage = result
    }
}
