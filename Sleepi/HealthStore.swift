//
//  HealthStore.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation
import HealthKit

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
    
    func calculateSleep(completion: @escaping ([HKSample]) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!

        let startDate = Calendar.current.date(byAdding: .day, value: -70, to: Date())
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

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
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
        
        guard let healthStore = self.healthStore else {
            return completion(false)
        }

        healthStore.requestAuthorization(toShare: [], read: [sleepType]) { (success, error) in
            completion(success)
        }
    }
}
