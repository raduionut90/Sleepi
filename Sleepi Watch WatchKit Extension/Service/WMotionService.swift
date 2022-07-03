//
//  WMotionService.swift
//  Sleepi Watch WatchKit Extension
//
//  Created by Ionut Radu on 04.06.2022.
//

import Foundation
import CoreMotion
import SwiftUI

class WMotionService {

    let recorder = CMSensorRecorder()
    
    private var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
        return formatter
    }()
    
    func startRecording() {
        DispatchQueue.global(qos: .background).async {
            print("start record accelerometer")
            self.recorder.recordAccelerometer(forDuration: 43200)
        }
    }
    
    func readMotionData(service: WatchConnectivityService) {
        print("readMotionData")
        DispatchQueue.global(qos: .background).async {
            print("start reading accelerometer")

            let lastDay: Date = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
//            var xx = 0.0
//            var yy = 0.0
//            var zz = 0.0
            
//            var currentTime: Date?
//            var wasSet: Bool = false

            
            if let data = self.recorder.accelerometerData(from: lastDay, to: Date()) {
                print("wmotion service: load data")
                var dataRA: [CMRecordedAccelerometerData] = []
                
//                service.sendSleepDataToiOS(data: data as CMSensorDataList)
//                var lastMotion = 0.0
                
                for element in data as CMSensorDataList {
                    let lastElement = element as! CMRecordedAccelerometerData
                    dataRA.append(lastElement)
                }
                service.sendSleepDataToiOS(data: dataRA)
//                    if currentTime == nil {
//                        currentTime = lastElement.startDate
//                    }
//                    let currentTimeStr = self.formatter.string(from: currentTime!)
//
//                    //Get the attitude relative to the magnetic north reference frame.
//                    let x = lastElement.acceleration.x
//                    let y = lastElement.acceleration.y
//                    let z = lastElement.acceleration.z
//
//                    let motionRange = (lastMotion - 0.1)..<(lastMotion + 0.1)
//
//                    let accMotion = x + y + z
//
//                    if !wasSet && !motionRange.contains(accMotion) {
//                        wasSet = true
//                    }
//                    lastMotion = accMotion
//
//                    if currentTimeStr != self.formatter.string(from: lastElement.startDate) {
//                        currentTime = lastElement.startDate
//                        if !wasSet {
//                            activityMotion.append(lastElement.startDate)
//                        } else {
//                            wasSet = false
//                        }
//                    }
//
//                }
                
//                print(activityMotion)
//                var startSleep: Date?
//                for (index, element) in activityMotion.enumerated() {
//                    if index > 0 {
//                        if element.timeIntervalSinceReferenceDate - activityMotion[index - 1].timeIntervalSinceReferenceDate > 60 {
//                            print("not sleep:", activityMotion[index - 1], " - ", element)
//                            startSleep = element
//                        }
//                    } else {
//                        startSleep = element
//                    }
//                }
            } else {
                print("no acc data watch")
            }

        }

    }

}

extension CMSensorDataList: Sequence {
    public typealias Iterator = NSFastEnumerationIterator
    public func makeIterator() -> NSFastEnumerationIterator {
        return NSFastEnumerationIterator(self)
    }
}
