//
//  SleepState.swift
//  Sleepi
//
//  Created by Ionut Radu on 26.05.2022.
//

import Foundation

struct SleepState {
    var sleeps: [Sleep]
    var naps: [[Sleep]]
    var sleepPoints: [SleepPoint]
    var startSleep: Date
    var endSleep: Date
    var sleepDuration: Double
    var screenWidth: Double?
    var heartRateAverage: Double
    var hoursLabels: [HourItem]
    var totalBedTime: TimeInterval
    var sleepTime: TimeInterval?
    var awakeTime: TimeInterval?
    var deepSleepTime: TimeInterval?
    var lightSleepTime: TimeInterval?
    var remSleepTime: TimeInterval?


}
