//
//  SessionHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 21.06.2022.
//

import Foundation
import WatchConnectivity
import os
import CoreMotion

class WatchConnectivityService: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "SleepiApp", category: "WatchConnectivityService")

    // 2: Property to manage session
    private var session = WCSession.default
    
    override init() {
        super.init()
        // 3: Start and activate session if it's supported
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        
        print("isReachable?: \(session.isReachable)")
        print("isPaired?: \(session.isPaired), isWatchAppInstalled?: \(session.isWatchAppInstalled)")
    }
    
    func requestRecordingMotionDataToWatch() {
        guard session.activationState == .activated else {
            logger.error("Error attempting to transfer user info: WCSession is not activated")
            return
        }
        session.transferUserInfo(["requestRecordingMotionData": true])
    }
    
    func requestMotionDataToWatch() {
        print("requestMotionDataToWatch")
        guard session.activationState == .activated else {
            logger.error("Error attempting to transfer user info: WCSession is not activated")
            return
        }
        do {
            print("updateApplicationContext")

            try session.updateApplicationContext(["requestMotionData": Date()])
        } catch let error {
            logger.error("error: \(error.localizedDescription)")
        }
//        session.transferUserInfo(["requestMotionData": true])
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    // MARK: - WCSessionDelegate
    
    // 4: Required protocols
    
    // a
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        logger.notice("activationDidCompleteWith activationState:\(activationState.rawValue) error:\(String(describing: error))")
    }
    
    // b
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.notice("sessionDidBecomeInactive: \(session)")
    }

    // c
    func sessionDidDeactivate(_ session: WCSession) {
        logger.notice("sessionDidDeactivate: \(session)")
        // Reactivate session
        /**
         * This is to re-activate the session on the phone when the user has switched from one
         * paired watch to second paired one. Calling it like this assumes that you have no other
         * threads/part of your code that needs to be given time before the switch occurs.
         */
        self.session.activate()
    }

    /// Observer to receive messages from watch and we be able to response it
    ///
    /// - Parameters:
    ///   - session: session
    ///   - userInfo: userInfo received
    ///   - replyHandler: response handler
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]){
        print("didReceiveApplicationContext: \(applicationContext)")
        if let motionData = applicationContext["motionData"] as? Data {
            do {
                let myCustomObject = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(motionData)
                print(myCustomObject!)
            } catch let error {
                print(error)
            }
//            DispatchQueue.main.async {
//                print(myCustomObject) //[CMRecordedAccelerometerData]
//            }
        }
    }
}
