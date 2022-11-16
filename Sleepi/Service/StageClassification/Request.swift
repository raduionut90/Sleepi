//
//  StageDetectionRequest.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import HealthKit

protocol Request {
    var sleeps: [Sleep]? { get }
    var date: Date? { get }
    var activeEnergyBurned: [HKQuantitySample]? { get }
    var heartRates: [HKQuantitySample]? { get }
}

extension Request {
    //Default implementation
    var sleeps: [Sleep]? { return nil }
    var date: Date? {  return nil  }
    var activeEnergyBurned: [HKQuantitySample]? {  return nil  }
    var heartRates: [HKQuantitySample]? {  return nil  }
}
