//
//  WMotionService.swift
//  Sleepi Watch WatchKit Extension
//
//  Created by Ionut Radu on 04.06.2022.
//

import Foundation
import CoreMotion

class WMotionService {
    let motion = CMMotionManager()

    func startDeviceMotion() {
        if motion.isDeviceMotionAvailable {
            print("start watch motion")

            self.motion.deviceMotionUpdateInterval = 60
            self.motion.showsDeviceMovementDisplay = true
            self.motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }
    }
}
