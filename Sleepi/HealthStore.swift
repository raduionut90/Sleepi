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

        let readTypes: Set = [HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!,
                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!,
                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN)!,
                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.restingHeartRate)!,
                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.respiratoryRate)!,
                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!]
        let writeTypes: Set = [HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!]
        let res: ()? = try? await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        guard res != nil else {
            throw HKError(.errorAuthorizationDenied)
        }
        return true
    }
    
    func sleepQuery(date: Date) async -> [HKCategorySample] {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
        
        var startDate = Calendar.current.startOfDay(for: date)
        startDate = Calendar.current.date(byAdding: .hour, value: -4, to: startDate)!
        
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 1000, sortDescriptors: [sortDescriptor]) { (query, tmpResult, error) -> Void in
                
                if error != nil {
                    print("Something went wrong getting sleep analysis: \(String(describing: error))")
                    return
                }

                if let result = tmpResult {
                    var sleeps: [HKCategorySample] = []

                    for item in result {
                        if let sample = item as? HKCategorySample {
//                            print(sample.sourceRevision.source)
//                            print("\(sample.startDate.formatted());\(sample.endDate.formatted());\(sample.sourceRevision.source)")

                            if sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier {
                                sleeps.append(sample)
//                                print("\(sleep.startDate.formatted());\(sleep.endDate.formatted())")
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
        endDate: Date) async -> [HKQuantitySample] {

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

                  if let result = tmpResult as? [HKQuantitySample] {
                      continuation.resume(returning: result)
                  }
            }

                /// Execute the query in the health store
            if let healthStore = healthStore {
                healthStore.execute(query)
            }
        }
      }
    
    func startHeartRateVariabilityQuery(
        startDate: Date,
        endDate: Date) async -> [HKQuantitySample] {

//            print("startDate: \(startDate)")
//            print("endDate: \(endDate)")

        /// Create sample type for the heart rate
        let sampleType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

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

                  if let result = tmpResult as? [HKQuantitySample] {
                      continuation.resume(returning: result)
                  }
            }

                /// Execute the query in the health store
            if let healthStore = healthStore {
                healthStore.execute(query)
            }
        }
      }
    
    func startRestingHeartRateQuery(
        startDate: Date,
        endDate: Date) async -> [HKQuantitySample] {

//            print("startDate: \(startDate)")
//            print("endDate: \(endDate)")

        /// Create sample type for the heart rate
        let sampleType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!

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

                  if let result = tmpResult as? [HKQuantitySample] {
                      continuation.resume(returning: result)
                  }
            }

                /// Execute the query in the health store
            if let healthStore = healthStore {
                healthStore.execute(query)
            }
        }
      }
    
    func startRespiratoryRateQuery(
        startDate: Date,
        endDate: Date) async -> [HKQuantitySample] {

//            print("startDate: \(startDate)")
//            print("endDate: \(endDate)")

        /// Create sample type for the heart rate
        let sampleType = HKObjectType.quantityType(forIdentifier: .respiratoryRate)!

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

                  if let result = tmpResult as? [HKQuantitySample] {
                      continuation.resume(returning: result)
                  }
            }

                /// Execute the query in the health store
            if let healthStore = healthStore {
                healthStore.execute(query)
            }
        }
      }
    
    func activeEnergyQuery(
        startDate: Date,
        endDate: Date) async -> [HKQuantitySample] {

//            print("startDate: \(startDate)")
//            print("endDate: \(endDate)")

        /// Create sample type for the heart rate
        let sampleType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!

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

              if let result = tmpResult as? [HKQuantitySample] {
                  continuation.resume(returning: result)
              }
            }

                /// Execute the query in the health store
            if let healthStore = healthStore {
                healthStore.execute(query)
            }
        }
      }
    
    func saveSleepAnalysis(startTime: Date, endTime: Date) {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
            
        // we create new object we want to push in Health app
        let object = HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleep.rawValue, start: startTime, end: endTime)
        
        // we now push the object to HealthStore
        
        if let healthStore = healthStore {
            healthStore.save(object, withCompletion: { (success, error) -> Void in
                
                if error != nil {
                    print("ERROR: HealthStore.saveSleepAnalysis: \(error.debugDescription)")
                    return
                }
        
                if success {
                    print("My new data was saved in Healthkit")
                } else {
                    // It was an error again
                    print("ERROR: HealthStore.saveSleepAnalysis: Data was not saved for sleep startTime \(startTime) endTime: \(endTime)")
                }
            })
        }
    }
    
    func readRecordedSleepsBySleepi(startTime: Date, endTime: Date) async -> [HKSample] {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 1000, sortDescriptors: [sortDescriptor]) { (query, tmpResult, error) -> Void in
                
                if error != nil {
                    print("Something went wrong getting sleep analysis: \(String(describing: error))")
                    return
                }

                if let result = tmpResult {
                    var sleeps: [HKCategorySample] = []

                    for item in result {
                        if let sample = item as? HKCategorySample {
//                            print(sample.sourceRevision.source)
//                            print("\(sample.startDate.formatted());\(sample.endDate.formatted());\(sample.sourceRevision.source)")

                            if sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier {
                                sleeps.append(sample)
//                                print("\(sleep.startDate.formatted());\(sleep.endDate.formatted())")
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
}
