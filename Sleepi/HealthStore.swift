//
//  HealthStore.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation
import HealthKit
import SwiftUI
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "HealthStore"
)

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
                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
//                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN)!,
//                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.restingHeartRate)!,
//                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.respiratoryRate)!,
                              HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!]
        let writeTypes: Set = [HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!]
        let res: ()? = try? await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        guard res != nil else {
            logger.error("HealthKit autorization denied")
            throw HKError(.errorAuthorizationDenied)
        }
        return true
    }
    
    func getSamples(startDate: Date, endDate: Date, type: HKQuantityTypeIdentifier) async -> [HKQuantitySample] {
        
        /// Create sample type for the heart rate
        let sampleType = HKObjectType.quantityType(forIdentifier: type)!
        
        /// Predicate for specifiying start and end dates for the query
        let predicate = HKQuery
            .predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: [.strictStartDate, .strictEndDate])
        
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
                        logger.error("Error: \(error!.localizedDescription)")
                        return
                    }
                    
                    if let result = tmpResult as? [HKQuantitySample] {
                        let desiredSources = result.filter {
                            $0.sourceRevision.source.bundleIdentifier.starts(with: "com.apple.health")
                        }
                        continuation.resume(returning: desiredSources)
                    }
                }
            
            /// Execute the query in the health store
            if let healthStore = healthStore {
                healthStore.execute(query)
            }
        }
    }
    
    func saveSleep(startTime: Date, endTime: Date) async throws  {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
        let bundleVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)!
        print(bundleVersion)
        let metadata = ["SleepiAlghorithm" : bundleVersion]
        // we create new object we want to push in Health app
        let object = HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleep.rawValue, start: startTime, end: endTime, metadata: metadata)
//        object.metadata[HKMetadataKeyAlgorithmVersion] = 1.1

        // we now push the object to HealthStore
        
        if let healthStore = healthStore {
            
            let res: ()? = try? await healthStore.save(object)
            guard res != nil else {
                logger.error("ERROR: Sleep \(startTime.formatted()) - \(endTime.formatted()) has not been saved")
                throw HKError(.errorDatabaseInaccessible)
            }
        }
    }
    
    func deleteSleep(sleep: HKObject) async throws  {
        if let healthStore = healthStore {
            
            let res: ()? = try? await healthStore.delete(sleep)
            guard res != nil else {
                logger.error("ERROR: Sleep \(sleep) has not been deleted")
                throw HKError(.errorDatabaseInaccessible)
            }
        }
    }
    
    func getSleeps(startTime: Date, endTime: Date) async -> [HKCategorySample] {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 1000, sortDescriptors: [sortDescriptor]) { (query, tmpResult, error) -> Void in
                
                if error != nil {
                    logger.error("Something went wrong getting sleep: \(String(describing: error))")
                    return
                }
                
                if let result = tmpResult {
                    var sleeps: [HKCategorySample] = []
                    
                    for item in result {
                        if let sample = item as? HKCategorySample {
//                            logger.log(sample.sourceRevision.source)
                            logger.log(";\(sample.sourceRevision.source.bundleIdentifier);\(sample.startDate.formatted());\(sample.endDate.formatted())")
                            
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
