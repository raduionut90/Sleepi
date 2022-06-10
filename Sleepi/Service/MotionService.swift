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
    let recorder = CMSensorRecorder()
    let watchMotionService = WMotionService()
    let motion = CMMotionManager()

    init() {
        watchMotionService.startDeviceMotion()
    }
    
    func readMotionData() {
        if motion.isDeviceMotionAvailable {
            print("ios device motion available")

            var xx = 0.0
            var yy = 0.0
            var zz = 0.0

            // Configure a timer to fetch the motion data.
            self.timer = Timer(fire: Date(), interval: (60), repeats: true,
                               block: { (timer) in
                                if let data = self.motion.deviceMotion {
                                    print("data div motion")

                                    // Get the attitude relative to the magnetic north reference frame.
                                    let x = data.attitude.pitch
                                    let y = data.attitude.roll
                                    let z = data.attitude.yaw
                                    
                                    let xRange = (x - 0.1)..<(x + 0.1)
                                    let yRange = (y - 0.1)..<(y + 0.1)
                                    let zRange = (z - 0.1)..<(z + 0.1)

                                    
                                    if !xRange.contains(xx) || !yRange.contains(yy) || !zRange.contains(zz){
                                        print(Date())
                                        print("movement")

                                    } else {
                                        print(Date())
                                        print("Not movement")
                                    }
                                    
                                    xx = x
                                    yy = y
                                    zz = z

                                }
            })
            
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: RunLoop.Mode.default)
        }
    }
    
}
