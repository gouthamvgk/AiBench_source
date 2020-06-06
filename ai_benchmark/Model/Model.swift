//
//  Model.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 22/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import Foundation
import CoreML
import Vision
import UIKit
import CoreMedia

protocol ModelProcessDelegate: AnyObject {
    func processClassifications(for request: VNRequest, error: Error?)
    func processRegression(for request: VNRequest, error: Error?)
    func processPoseEstimation(for request: VNRequest, error: Error?)
    func processSegmentation(for request: VNRequest, error: Error?)
    func processDetections(for request: VNRequest, error: Error?)
    func processError(errorString: String)
}

class VModel {
    var model: VNCoreMLModel?
    var task: inferType?
    var request: VNCoreMLRequest?
    weak var delegate: ModelProcessDelegate?
    var classNames: String?
    
    init(path: URL, device: String, task: String) {
        self.task = getTask(task)
        let conf = getMLConfig(device)
        let coreModel = try? MLModel(contentsOf: path, configuration: conf)
        if coreModel != nil {
//            inspectModel(model: coreModel!)
            self.model = try? VNCoreMLModel(for: coreModel!)
            if self.model != nil {
                self.request = VNCoreMLRequest(model: self.model!, completionHandler: { (request, error) in
                    self.doProcessing(request, error: error)
                })
                self.request?.imageCropAndScaleOption = .scaleFill
            }
            if self.task! == inferType.detection {
                guard let userDefined = coreModel?.modelDescription.metadata[MLModelMetadataKey.creatorDefinedKey] as? [String: String],
                   let allLabels = userDefined["classes"] else {
                  return
                }
                self.classNames = allLabels
            }
        }
        
    }
    
    func doPrediction(image: CVImageBuffer) {
        DispatchQueue.global(qos: .userInitiated).async {
            let orientation = self.exifOrientationFromDeviceOrientation()
            var options: [VNImageOption : Any] = [:]
            if let cameraIntrinsicMatrix = CMGetAttachment(image, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
              options[.cameraIntrinsics] = cameraIntrinsicMatrix
            }
            let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation, options: options)
            if self.request != nil {
                do {
                    try handler.perform([self.request!])
                } catch {
                    self.delegate?.processError(errorString: error.localizedDescription)
                }
            } else {
                self.delegate?.processError(errorString: "Model creation or request creation failed. Restart the App and try again!")
            }
        }
    }
    
    
    func doProcessing(_ request: VNRequest, error: Error?) {
        switch self.task! {
        case .classification:
            self.delegate?.processClassifications(for: request, error: error)
        case .detection:
            self.delegate?.processDetections(for: request, error: error)
        case .regression:
            self.delegate?.processRegression(for: request, error: error)
        case .poseEstimation:
            self.delegate?.processPoseEstimation(for: request, error: error)
        case .segmentation:
            self.delegate?.processSegmentation(for: request, error: error)
        }
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}
    
    
    
    

