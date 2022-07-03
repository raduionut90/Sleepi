//
//  WatchConnectivityService.swift
//  Sleepi Watch WatchKit Extension
//
//  Created by Ionut Radu on 22.06.2022.
//

import Foundation
import WatchConnectivity
import os
import CoreMotion

class WatchConnectivityService: NSObject, ObservableObject {
    private let wcSession: WCSession
    private let logger = Logger(subsystem: "WCExperimentsWatchApp", category: "WatchConnectivityService")

    override init() {
        self.wcSession = WCSession.default
        super.init()
        if WCSession.isSupported() {
            wcSession.delegate = self
            wcSession.activate()
        }
    }
        
    func sendSleepDataToiOS(data: [CMRecordedAccelerometerData]) {
        guard wcSession.activationState == .activated else {
            logger.error("Error attempting to transfer user info: WCSession is not activated")
            return
        }
        logger.notice("sendSleepDataToiOS: \(data.count)")
        do {
            let dataEnc = try NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false)
            try wcSession.updateApplicationContext(["motionData": dataEnc])
        } catch let error {
            print(error)
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        logger.notice("WCSession activationDidCompleteWith state: \(activationState.rawValue), error: \(error?.localizedDescription ?? "nil")")
    }
    
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        logger.notice("WCSession didFinish userInfoTransfer: \(userInfoTransfer.userInfo), error: \(error?.localizedDescription ?? "nil")")
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        logger.notice("Received userInfo: \(userInfo)")
        if let request = userInfo["requestRecordingMotionData"] as? Bool {
            DispatchQueue.main.async {
                request ? WMotionService().startRecording() : nil
            }
        }
    }
    

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]){
        print("didReceiveApplicationContext")
        print(applicationContext)
        print(self.wcSession.receivedApplicationContext)
        logger.notice("Received applicationContext: \(applicationContext)")
        if let request = applicationContext["requestMotionData"] as? Date {
            DispatchQueue.main.async {
                WMotionService().readMotionData(service: self)
            }
        }
    }
}
