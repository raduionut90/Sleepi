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
    
    func requestAuthorization() async throws -> Bool {
        let store = HKHealthStore()

        let readTypes: Set = [HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!, HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!]
        
        let res: ()? = try? await store.requestAuthorization(toShare: [], read: readTypes)
        guard res != nil else {
            throw HKError(.errorAuthorizationDenied)
        }
        return true
    }
    
    func startSleepQuery(date: Date) async -> [Sleep] {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
        
        var startDate = Calendar.current.startOfDay(for: date)
        startDate = Calendar.current.date(byAdding: .hour, value: -3, to: startDate)!
        
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 1000, sortDescriptors: [sortDescriptor]) { (query, tmpResult, error) -> Void in
                
                if error != nil {
                    print("Something went wrong getting sleep analysis: \(String(describing: error))")
                    return
                }
                var sleeps: [Sleep] = []

                if let result = tmpResult {

                    for item in result {
                        if let sample = item as? HKCategorySample {
//                            print(sample.sourceRevision.source)
//                            print(sample.sourceRevision.productType!)

                            if (sample.sourceRevision.source.bundleIdentifier.contains("com.apple.health") &&
                                ((sample.sourceRevision.productType?.contains("Watch")) == true)) {
                                let sleep = Sleep(value: sample.value, startDate: sample.startDate, endDate: sample.endDate, source: sample.sourceRevision.source.name, heartRates: [HeartRate]())
                                sleeps.append(sleep)
                            }
                        }
                    }
                    continuation.resume(returning: sleeps)
                }
            }
            
            
            if let healthStore = healthStore {
                healthStore.execute(query)
            }
            
        }
    }
    
    func startHeartRateQuery(
        startDate: Date,
        endDate: Date) async -> [HeartRate] {

//            print("startDate: \(startDate)")
//            print("endDate: \(endDate)")

        /// Create sample type for the heart rate
        let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        /// Predicate for specifiying start and end dates for the query
        let predicate = HKQuery
          .predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictEndDate)

        /// Set sorting by date.
        let sortDescriptor = NSSortDescriptor(
          key: HKSampleSortIdentifierStartDate,
          ascending: true)

        /// Create the query
        return await withCheckedContinuation { continuation in

            let query = HKSampleQuery(
              sampleType: sampleType,
              predicate: predicate,
              limit: Int(HKObjectQueryNoLimit),
              sortDescriptors: [sortDescriptor]) { (_, tmpResult, error) in

                guard error == nil else {
                    print("Error: \(error!.localizedDescription)")
                    return
                }

              var heartRates: [HeartRate] = []
              if let result = tmpResult as? [HKQuantitySample] {
                  for item in result {
                      let hr = HeartRate(value: item.quantity.doubleValue(for: HKUnit(from: "count/min")), startDate: item.startDate)
                      heartRates.append(hr)
                  }
                  
                  continuation.resume(returning: heartRates)
              }
            }

                /// Execute the query in the health store
            if let healthStore = healthStore {
                healthStore.execute(query)
            }
        }
      }
    
}
