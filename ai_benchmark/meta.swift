//
//  appMeta.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 03/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import Foundation

struct C {
    static let infoURL = "https://raw.githubusercontent.com/gouthamk1998/AiBench_config/master/config.json"
    static let docURL = "https://github.com/gouthamvgk/AiBench_IOS/blob/master/README.md"
    static let preType = ["float32", "float16", "int8"]
    static let customPreType = ["custom"]
    static let runType = ["CPU", "C/G-PU", "Best"]
    static let posWidth = 513.0
    static let posHeight = 513.0
    static let posStride = 16
    static let classString = "App detected your model as Classification and will process outputs according to that. If not delete the model and check doc for proving inputs and outputs in correct format"
    static let detString = "App detected your model as Detection and will process outputs according to that. If not delete the model and check doc for proving inputs and outputs in correct format"
    static let segString = "App detected your model as Segmentation and will process outputs according to that. If not delete the model and check doc for proving inputs and outputs in correct format"
    static let defString = "App couldn't infer your model type. During benchmarking all outputs will be considered as MLFeatureObservation type and processed accordingly. If not delete the model and check doc for proving inputs and outputs in correct format"
    static let customNotice = "Custom Model should be provided in format mentioned in the App documentation. Press help in HomePage to open Doc"
    static let helpString = "AiBench helps you to benchmark your MLModel for time and results. To run models that comes with the App download the model weights and press Run_benchmark. To run custom model use Add Model button in HomePage and also read the documentation for providing models in right format. Note: Developer has no ownership over models that comes with the App. All models are used based on opensource license."
}

enum state {
    case downloaded
    case toDownload
    case invalid
}

enum inferType: String {
    case classification = "classification"
    case detection = "detection"
    case segmentation = "segmentation"
    case poseEstimation = "poseEstimation"
    case regression = "regression"
}

enum failedType {
    case urlContent
    case AlreadyRunning
    case invalidInput
}

