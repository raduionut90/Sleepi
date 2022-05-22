//
//  HealthStore.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation
import HealthKit
import SwiftUI

extension Date {
    static func mondayAt12AM() -> Date {
        return Calendar(identifier: .iso8601).date(from: Calendar(identifier: .iso8601).dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    }
}

class HealthStore {
    var healthStore: HKHealthStore?
    var query: HKSampleQuery?
    
    init(){
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let healthKitTypes: Set = [HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!, HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!]
        
        guard let healthStore = self.healthStore else {
            return completion(false)
        }

        healthStore.requestAuthorization(toShare: [], read: healthKitTypes) { (success, error) in
            completion(success)
        }
    }
    
    func startSleepQuery(date: Date, completion: @escaping ([HKSample]) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!

        var startDate = Calendar.current.startOfDay(for: date)
        startDate = Calendar.current.date(byAdding: .hour, value: -3, to: startDate)!
        
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 1000, sortDescriptors: [sortDescriptor]) { (query, tmpResult, error) -> Void in

            if error != nil {
                    print("Something went wrong getting sleep analysis: \(String(describing: error))")
                return
            }
            if let result = tmpResult {

//                for item in result {
//                    if let sample = item as? HKCategorySample {
//                        let value = (sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue) ? "InBed" : "Asleep"
//                            print("Healthkit sleep: \(sample.startDate) \(sample.endDate) value: \(value)")
//                    }
//                }
                completion(result)
            }
        }
        

        if let healthStore = healthStore, let query = self.query{
            healthStore.execute(query)
        }

    }
    
    func startHeartRateQuery(
        startDate: Date,
        endDate: Date,
        completion: @escaping (_ samples: [HKQuantitySample]?) -> Void) {

            print("startDate: \(startDate)")
            print("endDate: \(endDate)")

        /// Create sample type for the heart rate
        guard let sampleType = HKObjectType
          .quantityType(forIdentifier: .heartRate) else {
            completion(nil)
          return
        }

        /// Predicate for specifiying start and end dates for the query
        let predicate = HKQuery
          .predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictEndDate)

        /// Set sorting by date.
        let sortDescriptor = NSSortDescriptor(
          key: HKSampleSortIdentifierStartDate,
          ascending: false)

        /// Create the query
        let query = HKSampleQuery(
          sampleType: sampleType,
          predicate: predicate,
          limit: Int(HKObjectQueryNoLimit),
          sortDescriptors: [sortDescriptor]) { (_, results, error) in

            guard error == nil else {
              print("Error: \(error!.localizedDescription)")
              return
            }


            completion(results as? [HKQuantitySample])
        }

        /// Execute the query in the health store
        let healthStore = HKHealthStore()
        healthStore.execute(query)
      }
    
}
