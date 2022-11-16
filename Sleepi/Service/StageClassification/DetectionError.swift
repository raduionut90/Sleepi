//
//  DetectionError.swift
//  Sleepi
//
//  Created by Ionut Radu on 16.11.2022.
//

import Foundation

enum DetectionError: LocalizedError {
    case emptyActiveEnergyBurned
    case emptyHeartRates
    case emptySleeps
    case emptyDate
    case emptySleepStage
    case emptySleepEpochs
    
    var errorDescription: String? {
        switch self {
        case .emptyHeartRates:
            return "Heart Rates is empty"
        case .emptyActiveEnergyBurned:
            return "Active Energy Burned is empty"
        case .emptySleeps:
            return "Sleeps is empty"
        case .emptyDate:
            return "Date is empty"
        case .emptySleepStage:
            return "Empty Sleep Stage"
        case .emptySleepEpochs:
            return "Empty Sleep Epochs"
        }
    }
}
