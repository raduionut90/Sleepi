//
//  StageRequest.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import HealthKit

struct StageRequest: Request {
    var sleeps: [Sleep]?
    var date: Date?
    var activeEnergyBurned: [HKQuantitySample]? 
    var heartRates: [HKQuantitySample]?
}
