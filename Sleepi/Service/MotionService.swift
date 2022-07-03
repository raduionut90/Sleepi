//
//  CoreMotionService.swift
//  Sleepi
//
//  Created by Ionut Radu on 01.06.2022.
//

import Foundation
import CoreMotion
import SwiftUI


class MotionService {
    var timer: Timer?
    var motion: CMMotionManager
    var lastMotion = 0.0

    init() {
        self.motion = CMMotionManager()
    }

        
    //live accelerometer
//    func readMotionData() {
//        if motion.isDeviceMotionAvailable {
//            self.motion.deviceMotionUpdateInterval = 1
//            self.motion.showsDeviceMovementDisplay = true
//            self.motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
//
//            // Configure a timer to fetch the motion data.
//            self.timer = Timer(fire: Date(), interval: (1), repeats: true,
//                               block: { (timer) in
//
//                                if let data = self.motion.deviceMotion {
//
//                                    // Get the attitude relative to the magnetic north reference frame.
//                                    let x = data.attitude.pitch
//                                    let y = data.attitude.roll
//                                    let z = data.attitude.yaw
//
//                                    let m = x + y + z
//                                    let mRange = (self.lastMotion - 0.1)..<(self.lastMotion + 0.1)
//
//                                    if mRange.contains(m) {
//                                        print("No motion")
//                                    } else {
//                                        print("MOTION")
//                                    }
//                                    print("")
//                                    self.lastMotion = m
//
//                                }
//            })
//
//            // Add the timer to the current run loop.
//            RunLoop.current.add(self.timer!, forMode: RunLoop.Mode.default)
//        }
//    }
    
}
