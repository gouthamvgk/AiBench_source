//
//  modelUtils.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 14/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import Foundation
import CoreML
import Vision

func getMLConfig(_ device: String) -> MLModelConfiguration {
    let conf = MLModelConfiguration()
    switch device {
        case C.runType[0]:
            conf.computeUnits = .cpuOnly
        case C.runType[1]:
            conf.computeUnits = .cpuAndGPU
        case C.runType[2]:
            conf.computeUnits = .all
        default:
            conf.computeUnits = .all
        }
        return conf
}

func getTask(_ task: String) -> inferType {
    switch task {
    case "classification":
        return inferType.classification
    case "detection":
        return inferType.detection
    case "regression":
        return inferType.regression
    case "poseEstimation":
        return inferType.poseEstimation
    case "segmentation":
        return inferType.segmentation
    default:
        fatalError("Task type not understood")
    }
}

func getValue(ind: Int, tuple: (CGFloat, CGFloat, CGFloat, CGFloat)) -> CGFloat {
    switch ind {
    case 0:
        return tuple.0
    case 1:
        return tuple.1
    case 2:
        return tuple.2
    case 3:
        return tuple.3
    default:
        return 0.0
    }
}

func getAlertMessage(type: failedType) -> String {
    switch type {
    case .AlreadyRunning:
        return "Instance of download already running. Quit it"
    case .invalidInput:
        return "Input String invalide! Check entered content"
    case .urlContent:
        return "Enter the correct URL"
    }
}
