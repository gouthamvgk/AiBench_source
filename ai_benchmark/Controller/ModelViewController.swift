//
//  ViewController.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 03/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import UIKit
import CoreML
import Vision

class ModelViewController: UIViewController, downloadProtocol {
    var downloadManager: Download?
    var modelInfo: [String: String]?
    var section: Int?
    var color: UIColor?
    var parentView: homeViewController?
    var downloadMeta: [String: String]?
    var currentState: state?
    var progressAlert: progressAlertController?
    var downloadPath: URL!
    var preType: [String]!
    let userDef = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var runStack: UIStackView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var runButton: UIButton!
    @IBOutlet weak var deviceSegment: UISegmentedControl!
    @IBOutlet weak var modelName: UILabel!
    @IBOutlet weak var modelFamily: UILabel!
    @IBOutlet weak var modelSize: UILabel!
    @IBOutlet weak var modelSegment: UISegmentedControl!
    @IBOutlet weak var actionButton: UIButton!
    
    @IBAction func actionPressed(_ sender: UIButton) {
        let currType = self.preType[self.modelSegment.selectedSegmentIndex]
        var alertTitle: String
        var alertMessage: String
        (alertTitle, alertMessage)  = getAlertContent()
        let alert = createAlert(title: alertTitle, message: alertMessage, type: currType)
        self.navigationController?.present(alert, animated: true, completion: nil)
    }
    @IBAction func infoClicked(_ sender: UIButton) {
        self.createSmallAlert(title: self.modelInfo!["modelName"]!, message: self.modelInfo!["description"]!)
    }
    @IBAction func pressRun(_ sender: UIButton) {
        let prepend = self.preType[self.modelSegment.selectedSegmentIndex]
        if let path = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(self.downloadMeta!["\(prepend)_compiledURL"]!) {
            self.downloadPath = path
            performSegue(withIdentifier: "benchmarkSegue", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destination = segue.destination as! benchViewController
        destination.modelURL = self.downloadPath
        destination.modelDevice = C.runType[deviceSegment.selectedSegmentIndex]
        destination.task = self.modelInfo!["task"]!
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        changeState()
    }
    
    @IBAction func deviceSegmentChanged(_ sender: UISegmentedControl) {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.downloadManager?.secondaryDelegate = self
        self.actionButton.layer.cornerRadius = self.actionButton.layer.frame.height/4
        self.runButton.layer.cornerRadius = self.runButton.layer.frame.height/4
        if let modelData = self.modelInfo {
            self.updateState()
            if modelData["family"]! == "Custom Models" {
                self.preType = C.customPreType
            }
            else {
                self.preType = C.preType
            }
            self.modelName.text = modelData["modelName"]!
            self.modelFamily.text = "Family: \(modelData["family"]!)"
            modelSegment.removeAllSegments()
            for (index, item) in self.preType.enumerated() {
                modelSegment.insertSegment(withTitle: item.uppercased(), at: index, animated: false)
            }
            modelSegment.selectedSegmentIndex = 0
            changeState()
            if modelData["family"]! == "Custom Models" {
                self.createSmallAlert(title: self.modelInfo!["modelName"]!, message: self.modelInfo!["description"]!)
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        if self.modelInfo!["family"]! == "Custom Models" && self.currentState! == .toDownload {
            var modelInfoMeta = userDef.appMeta.dictionary(forKey: "modelInfo") as? [String : [String : String]]
            var sections = userDef.appMeta.dictionary(forKey: "modelSections") as? [String: [String]]
            var customSection = sections?["Custom Models"]
            modelInfoMeta?.removeValue(forKey: self.modelInfo!["modelName"]!)
            if let index = customSection?.firstIndex(of: self.modelInfo!["modelName"]!) {
                customSection?.remove(at: index)
                if customSection?.count == 0 {
                    sections?.removeValue(forKey: "Custom Models")
                } else {
                    sections?.updateValue(customSection!, forKey: "Custom Models")
                }
                userDef.appMeta.set(sections, forKey: "modelSections")
            }
            userDef.appMeta.set(modelInfoMeta, forKey: "modelInfo")
            self.parentView?.updateCurrentInfo()
            //update model sections here
        }
        self.downloadManager?.secondaryDelegate = nil
    }
    
    func updateMeta(type: String, version: String, url: String, compiledPath: String, compiledURL: URL, customTask: inferType?) {
        var wholeMeta = userDef.appMeta.dictionary(forKey: "downloadMeta") as? [String: [String: String]]
        var currInfo: [String : String]!
        if let info = wholeMeta?[self.modelInfo!["modelName"]!] {
            currInfo = info
            currInfo.updateValue(url, forKey: "\(type)_downloadURL")
            currInfo.updateValue(compiledPath, forKey: "\(type)_compiledURL")
            currInfo.updateValue(version, forKey: "\(type)_version")
        } else {
            currInfo = ["\(type)_downloadURL" : url]
            currInfo.updateValue(compiledPath, forKey: "\(type)_compiledURL")
            currInfo.updateValue(version, forKey: "\(type)_version")
        }
        wholeMeta?.updateValue(currInfo, forKey: self.modelInfo!["modelName"]!)
        self.userDef.appMeta.set(wholeMeta, forKey: "downloadMeta")
        self.updateState()
        self.changeState()
    }
    

    func deleteMeta(type: String) {
        var wholeMeta = userDef.appMeta.dictionary(forKey: "downloadMeta") as? [String: [String: String]]
        var currInfo: [String : String]!
        if let info = wholeMeta?[self.modelInfo!["modelName"]!] {
            currInfo = info
            currInfo.removeValue(forKey: "\(type)_downloadURL")
            currInfo.removeValue(forKey: "\(type)_compiledURL")
            currInfo.removeValue(forKey: "\(type)_version")
            wholeMeta?.updateValue(currInfo, forKey: self.modelInfo!["modelName"]!)
            self.userDef.appMeta.set(wholeMeta, forKey: "downloadMeta")
        } else {
            self.createSmallAlert(title: "Something happened during delete!", message: "Refresh model list at home page. If app crashes during use please reinstall it.")
        }
        if type == C.customPreType[0] {
            self.parentView?.updateCurrentInfo()
        }
        self.updateState()
        self.changeState()
    }
    
    
    func updateState() {
        self.downloadMeta = (userDef.appMeta.dictionary(forKey: "downloadMeta") as? [String: [String: String]])?[self.modelInfo!["modelName"]!]
    }
    
    func changeState() {
        self.actionButton.isEnabled = true
        self.runStack.isHidden = true

        let index = modelSegment.selectedSegmentIndex
        let prepend = self.preType[index]
        if let size = modelInfo?["\(prepend)_size"] {
            self.modelSize.text = size.contains("M") ? "Size: \(size)" : "Size: \(size) MB"
        } else {
            self.modelSize.text = "Not available"
            self.actionButton.isEnabled = false
            self.currentState = .invalid
            return
        }
        if self.downloadMeta != nil {
            if self.downloadMeta!["\(prepend)_downloadURL"] != nil {
                self.actionButton.setTitle("Remove Model", for: .normal)
                self.currentState = .downloaded
                self.runStack.isHidden = false
                self.runStack.isUserInteractionEnabled = true
                self.deviceSegment.removeAllSegments()
                for (index, item) in C.runType.enumerated() {
                    deviceSegment.insertSegment(withTitle: item.uppercased(), at: index, animated: false)
                }
                deviceSegment.selectedSegmentIndex = 0
                if self.downloadMeta!["\(prepend)_version"]! != self.modelInfo!["\(prepend)_version"]! {
                    self.createSmallAlert(title: "Model version Changed!", message: "The version of model in your local device is different from the one present in servers currently. Delete the model and redownload it to use latest model weights.")
                }
                return
            }
        }
        self.actionButton.setTitle("Download", for: .normal)
        self.currentState = .toDownload
    }
    
    func createDownloadAlert() {
        self.progressAlert = progressAlertController(title: "Downloading", message: nil, preferredStyle: .alert)
        self.progressAlert?.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (UIAlertAction) in
            self.downloadManager?.cancelDownload()
        }))
        self.navigationController?.present(self.progressAlert!, animated: true, completion: nil)
    }
    
}

//MARK:- fileChangeMethods
extension ModelViewController {
    
    func startDownload(type: String) {
        if let downloadURL = self.modelInfo?["\(type)_downloadURL"], let version = self.modelInfo?["\(type)_version"] {
            createDownloadAlert()
            _ = self.downloadManager?.startDownload(url: downloadURL, type: type, version: version)
        }
    }
    
    func deleteDownload(type: String) {
        if let deletePath = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((self.downloadMeta?["\(type)_compiledURL"])!) {
            if FileManager.default.fileExists(atPath: deletePath.path) {
                try? FileManager.default.removeItem(atPath: deletePath.path)
            }
        }
        deleteMeta(type: type)
        
    }
}

//MARK:- Alertconroller code
extension ModelViewController {
    func createAlert(title: String, message: String, type: String) -> UIAlertController {
        let alert = UIAlertController(title: title,
                                      message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (sender) in
        switch self.currentState {
            case .downloaded:
                self.deleteDownload(type: type)
            case .toDownload:
                self.startDownload(type: type)
            default:
                break
            }
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: nil))
        return alert
    }
    
    func getAlertContent() -> (String, String) {
        var alertTitle = ""
        var alertMessage = ""
        switch self.currentState {
        case .downloaded:
            alertTitle = "Delete alert"
            alertMessage = "Do you want to delete the model?"
        case .toDownload:
            alertTitle = "Download alert"
            alertMessage = "Do you want download the model?"
        default:
            break
        }
        return (alertTitle, alertMessage)
    }
    
    func createSmallAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.navigationController?.present(alert, animated: true, completion: nil)
    }
}

//extension ModelViewController: URLSessionDelegate {
//  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
//    DispatchQueue.main.async {
//      if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
//        let completionHandler = appDelegate.backgroundSessionCompletionHandler {
//        appDelegate.backgroundSessionCompletionHandler = nil
//        completionHandler()
//      }
//    }
//  }
//}

