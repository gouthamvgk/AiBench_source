//
//  download.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 03/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import Foundation
import CoreML

protocol downloadProtocol {
    var progressAlert: progressAlertController? {get set}
    var modelInfo: [String: String]? {get set}
    func updateMeta(type: String, version: String, url: String, compiledPath: String, compiledURL: URL, customTask: inferType?)
}

class DownloadInstance {
    
    var downloadURL: URL
    var modelType: String
    var modelVersion: String
    var customName: String!
    var isDownloading = false
    var progress: Float = 0
    var resumeData: Data?
    var task: URLSessionDownloadTask?
    
    init(url: URL, type: String, version: String, modelName: String?) {
        self.downloadURL = url
        self.modelType = type
        self.modelVersion = version
        self.customName = modelName
    }
}
class Download: NSObject {
    lazy var session: URLSession = {
//      let configuration = URLSessionConfiguration.background(withIdentifier:"bgDownloader")
        let configuration = URLSessionConfiguration.default
        configuration.sessionSendsLaunchEvents = true
        configuration.timeoutIntervalForRequest = TimeInterval(10)
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
      return session
    }()
    var currDownload: DownloadInstance?
    var secondaryDelegate: downloadProtocol?
    var primaryDelegate: downloadProtocol?
    var coreMLType: inferType?
    lazy var isDownloading: Bool =  {
        if let flag = self.currDownload?.isDownloading {
            return flag
        }
        else {
            return false
        }
    }()


    func startDownload(url: String, type: String, version: String, modelName: String? = nil) -> Bool {
        guard let hitURL = URL(string: url) else {return false}
        self.currDownload = DownloadInstance(url: hitURL, type: type, version: version, modelName: modelName)
        self.currDownload?.task = self.session.downloadTask(with: hitURL)
        self.currDownload?.task?.resume()
        self.currDownload?.isDownloading = true
        return true
    }
    
    func cancelDownload() {
        if let downloadtask = self.currDownload {
            downloadtask.task?.cancel()
            self.currDownload = nil
        }
    }
    
    func pauseDownload() {
      guard let downloadtask = self.currDownload, downloadtask.isDownloading
        else {
          return
      }
      downloadtask.task?.cancel(byProducingResumeData: { data in
        downloadtask.resumeData = data
      })
      downloadtask.isDownloading = false
    }
    
    func resumeDownload() {
        guard let downloadtask = self.currDownload else {
        return
        }
      if let resumeData = downloadtask.resumeData {
        downloadtask.task = self.session.downloadTask(withResumeData: resumeData)
      } else {
        downloadtask.task = self.session.downloadTask(with: downloadtask.downloadURL)
      }
      
      downloadtask.task?.resume()
      downloadtask.isDownloading = true
    }
    
    func putAlert(alertString: String, message: String,  controller: progressAlertController?) {
        DispatchQueue.main.async {
            controller?.title = alertString
            controller?.message = message
        }
    }
}

extension Download {
    
    func detectModelType(model: MLModel) {
        if checkForClassification(model: model) {
            self.coreMLType = inferType.classification
        }
        else if checkForDetection(model: model) {
            self.coreMLType = inferType.detection
        }
        else if checkForSegmentation(model: model) {
            self.coreMLType = inferType.segmentation
        }
        else {
            self.coreMLType = inferType.regression
        }
    }
    
    func checkForClassification(model: MLModel) -> Bool {
        if let fea1 = model.modelDescription.predictedFeatureName, let fea2 = model.modelDescription.predictedProbabilitiesName {
            let outputNames = model.modelDescription.outputDescriptionsByName
            if outputNames[fea1]?.type == MLFeatureType.string, outputNames[fea2]?.type == MLFeatureType.dictionary {
                return true
            }
        }
        return false
    }
    
    func checkForSegmentation(model: MLModel) -> Bool {
        let outputString = ["semanticPredictions"]
        let outputNames = model.modelDescription.outputDescriptionsByName
        if outputNames.count > 1 {return false}
        for (key, val) in outputNames {
            if !(outputString.contains(key) && val.type == MLFeatureType.multiArray) {
                return false
            }
        }
        return true
    }
    
    func checkForDetection(model: MLModel) -> Bool {
        let outputString = ["confidence", "coordinates"]
        let outputNames = model.modelDescription.outputDescriptionsByName
        for (key, val) in outputNames {
            if !(outputString.contains(key) && val.type == MLFeatureType.multiArray) {
                return false
            }
        }
        return true
    }
    
    func checkCustomModel(path: URL) -> Bool {
        var inputPass: Bool = false
        var checkFlag: Bool = true
        let model = try? MLModel(contentsOf: path)
        if model != nil {
            let inputDescription = model?.modelDescription.inputDescriptionsByName
            if inputDescription != nil {
                for (_, val) in inputDescription! {
                    if val.type == MLFeatureType.image {
                        inputPass = true
                    } else if val.type != MLFeatureType.image && val.isOptional == false {
                        checkFlag = false
                    }
                }
                if !inputPass {return false}
                self.detectModelType(model: model!)
            } else {return false}
        } else {
            return false
        }
        
        return inputPass && checkFlag
    }
    
}

extension Download: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        self.currDownload?.isDownloading = false
        let currentDelegate = self.secondaryDelegate != nil ? self.secondaryDelegate : self.primaryDelegate
        let saveName = self.secondaryDelegate != nil ? self.secondaryDelegate?.modelInfo?["modelName"] : self.currDownload?.customName
        if let name = saveName, let instance = self.currDownload {
            if let alert = currentDelegate?.progressAlert {
                DispatchQueue.main.async {
                    alert.title = "Compiling the model..."
                    alert.message = ""
                }
            }
            let saveName = "\(name)_\(instance.modelType)"
            if let compiledUrl = try? MLModel.compileModel(at: location) {
                try? FileManager.default.removeItem(at: location)
                if checkCustomModel(path: compiledUrl) {
                    if let destinationFile = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: compiledUrl, create: true).appendingPathComponent(saveName).appendingPathExtension("mlmodelc") {
                        do {
                            if FileManager.default.fileExists(atPath: destinationFile.path) {
                                _ = try FileManager.default.replaceItemAt(destinationFile, withItemAt: compiledUrl)
                            } else {
                                try FileManager.default.copyItem(at: compiledUrl, to: destinationFile)
                            }
                            try? FileManager.default.removeItem(at: compiledUrl)
                        } catch {
                            self.putAlert(alertString: "Copying/Moving model failed", message: "Restart App!", controller: currentDelegate?.progressAlert)
                            return
                        }
                        DispatchQueue.main.async {
                            currentDelegate?.updateMeta(type: instance.modelType, version: instance.modelVersion, url: instance.downloadURL.absoluteString, compiledPath: destinationFile.lastPathComponent, compiledURL: destinationFile,customTask: self.coreMLType)
                            currentDelegate?.progressAlert?.dismiss(animated: true, completion: nil)
                        }
                    }
                } else {
                    self.putAlert(alertString: "Model input invalid", message: "Your custom model should have Image type input or only one mandatory input. Check Doc", controller: currentDelegate?.progressAlert)
                    return
                }
            }
            else {
                self.putAlert(alertString: "Compiling model failed", message: "Make sure model is valid!", controller: currentDelegate?.progressAlert)
                return
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let currentDelegate = self.secondaryDelegate != nil ? self.secondaryDelegate : self.primaryDelegate
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        let totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
        let writtenSize = ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)
        if let alert = currentDelegate?.progressAlert {
            DispatchQueue.main.async {
//                alert.message = "\(Int(progress*100))%"
                alert.message = "\(writtenSize) / \(totalSize)"
                alert.progress!.progress = progress
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.currDownload?.isDownloading = false
        let currentDelegate = self.secondaryDelegate != nil ? self.secondaryDelegate : self.primaryDelegate
        if let alert = currentDelegate?.progressAlert, let _ = error {
            DispatchQueue.main.async {
                alert.progress?.isHidden = true
                alert.message = ""
                alert.title = "Download failed! Check your internet or give right URL"
            }
        }
    }
}
