//
//  EpochsClassificationHandler.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "EpochsClassificationHandler"
)

class EpochsClassificationHandler: BaseHandler {
    override func handle(_ request: Request) -> LocalizedError? {
        if let sleeps = request.sleeps {
            for sleep in sleeps {
                if let epochs = sleep.epochs {
                    let activityQuartiles = Utils.getQuartiles(values: epochs.map {$0.sumActivity} )
                    let hrQuartiles = Utils.getQuartiles(values: epochs.map {$0.meanHR} )

                    logger.log(";\(activityQuartiles.firstQuartile);\(activityQuartiles.median);\(activityQuartiles.thirdQuartile)")
                    logger.log(";\(hrQuartiles.firstQuartile);\(hrQuartiles.median);\(hrQuartiles.thirdQuartile)")

                    for (index, epoch) in epochs.enumerated() {

                        logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR)")
                        let lastEpoch = epochs.indices.contains(index - 1) ? epochs[index - 1] : nil

                        if lastEpoch != nil && !lastEpoch!.meanHR.isNaN {
                            if (epoch.meanHR < lastEpoch!.meanHR - 5 || epoch.meanHR < hrQuartiles.firstQuartile ) && epoch.sumActivity == 0 {
                                epoch.stage = SleepStage.DeepSleep
                            } else if ((epoch.meanHR > lastEpoch!.meanHR + 5 || epoch.meanHR >= hrQuartiles.thirdQuartile) ) || (epoch.sumActivity > 0.1 && epoch.meanHR.isNaN ){
                                epoch.stage = SleepStage.RemSleep
                            } else if (((lastEpoch!.meanHR - 2)...(lastEpoch!.meanHR + 2)).contains(epoch.meanHR) ||
                                       lastEpoch!.meanHR.isNaN && epoch.meanHR.isNaN) &&
                                        ((lastEpoch!.sumActivity - 0.05 ... lastEpoch!.sumActivity + 0.05).contains(epoch.sumActivity) ||
                                        lastEpoch!.sumActivity.isNaN && epoch.sumActivity.isNaN)  {
                                epoch.stage = lastEpoch!.stage
                            } else {
                                epoch.stage = SleepStage.LightSleep
                            }
                        } else {
                            if epoch.sumActivity == 0 && (epoch.meanHR < hrQuartiles.firstQuartile || epoch.meanHR.isNaN) {
                                epoch.stage = SleepStage.DeepSleep
                            } else if (epoch.meanHR >= hrQuartiles.thirdQuartile || epoch.meanHR.isNaN) && epoch.sumActivity > 0.2 {
                                epoch.stage = SleepStage.RemSleep
                            } else {
                                epoch.stage = SleepStage.LightSleep
                            }
                        }
                    }
                } else {
                    return DetectionError.emptySleepEpochs
                }
                
            }
        }
        return next?.handle(request)
    }
}
