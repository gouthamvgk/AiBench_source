//
//  homeViewControllerCollectionViewController.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 03/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import UIKit
import SwiftyJSON


class homeViewController: UICollectionViewController, downloadProtocol {
    
    var downloadManager = Download()
    var downloadAlert: downloadAlertController?
    var customAlert: customModelAlert?
    var progressAlert: progressAlertController?
    private let reuseIdentifier = "sectionCell"
    private let sectionInsets = UIEdgeInsets(top: 20, left: 20.0, bottom: 20.0, right: 20.0)
    private let itemsPerRow: CGFloat = 3
    let numSecColors = 6
    var currentColor: UIColor?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var selectedItem: String!
    private var selectedSection: Int!
    var models: [String: [String: String]]?
    var sectionMappings = [(String, Int)]()
    var sections: [String: [String]]?
    var modelInfo: [String: String]? // currently a hack for protocol
    
    @IBAction func reloadClicked(_ sender: UIButton) {
        self.createAlertDownload(silent: false)
    }
    
    @IBAction func helpClicked(_ sender: Any) {
        let action = UIAlertAction(title: "Open Doc", style: .default) { (alert) in
            self.openDoc()
        }
        self.createAlert(title: "Help", message: C.helpString, action: action)
    }
    @IBAction func addModelClicked(_ sender: UIButton) {
        self.createCustomModAlert()
    }
    
    @IBAction func deleteAllClicked(_ sender: UIButton) {
        self.createDeleteAlert()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.downloadManager.primaryDelegate = self
        let metaKeys = appDelegate.appMeta.dictionaryRepresentation().keys
        if !(metaKeys.contains("isFirstTime")) {
            self.createAlertDownload(silent: false)
        } else {
            self.createAlertDownload(silent: true)
//            self.updateCurrentInfo()
//            self.collectionView.reloadData()
        }

    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.collectionView.reloadData()
    }
    
    func openDoc() {
        if let url = URL(string: C.docURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    

}

//Mark:- UpdateMethods
extension homeViewController {
    
    func setMappings() {
        self.sectionMappings.removeAll()
        self.sections?.forEach({ (arg0) in
            let (key, value) = arg0
            self.sectionMappings.append((key, value.count))
        })
    }
    
    func updateCurrentInfo() {
        self.models = appDelegate.appMeta.dictionary(forKey: "modelInfo") as? [String: [String: String]]
        self.sections = appDelegate.appMeta.dictionary(forKey: "modelSections") as? [String: [String]]
        self.setMappings()
    }
    
    func updateMeta(type: String, version: String, url: String, compiledPath: String, compiledURL: URL, customTask: inferType?) {
        let size = try? FileManager.default.allocatedSizeOfDirectory(at: compiledURL)
        var modelInfoMeta = appDelegate.appMeta.dictionary(forKey: "modelInfo") as? [String : [String : String]]
        var sectionMeta = appDelegate.appMeta.dictionary(forKey: "modelSections") as? [String : [String]]
        var downloadMeta = appDelegate.appMeta.dictionary(forKey: "downloadMeta") as? [String: [String: String]]
        var sections = sectionMeta?["Custom Models"] ?? [String]()
        var customDescription: String = ""
        var task: inferType!
        if let infType = customTask {
            switch infType {
            case .classification:
                customDescription = C.classString
                task = .classification
            case .detection:
                customDescription = C.detString
                task = .detection
            case .segmentation:
                customDescription = C.segString
                task = .segmentation
            default:
                customDescription = C.defString
                task = .regression
            }
        }
        let customInfo: [String: String] = [
            "modelName": self.modelInfo?["modelName"] ?? "Default",
            "family": "Custom Models",
            "description": customDescription,
            "task": task.rawValue,
            "custom_size": size ?? "Unknown",
            "custom_downloadURL": url,
            "custom_version": version
        ]
        let downloadInfo: [String : String] = [
            "\(type)_downloadURL": url,
            "\(type)_compiledURL": compiledPath,
            "\(type)_version": version
        ]
        sections.append(self.modelInfo?["modelName"] ?? "Default")
        
        modelInfoMeta?.updateValue(customInfo, forKey: self.modelInfo?["modelName"] ?? "Default")
        downloadMeta?.updateValue(downloadInfo, forKey: self.modelInfo?["modelName"] ?? "Default")
        sectionMeta?.updateValue(sections, forKey: "Custom Models")
        
        appDelegate.appMeta.set(downloadMeta, forKey: "downloadMeta")
        appDelegate.appMeta.set(modelInfoMeta, forKey: "modelInfo")
        appDelegate.appMeta.set(sectionMeta, forKey: "modelSections")
        
        self.updateCurrentInfo()
        self.collectionView.reloadData()
    }
    
    func deleteAllWeights() {
        let allTypes = C.preType + C.customPreType
        var downloadMeta = appDelegate.appMeta.dictionary(forKey: "downloadMeta") as? [String: [String: String]]
        var instance: Dictionary<String, String>.Keys
        if downloadMeta != nil {
            for model in downloadMeta!.keys {
                instance = downloadMeta![model]!.keys
                for typ in allTypes {
                    if instance.contains("\(typ)_compiledURL"), deleteFile(compiledURL: downloadMeta![model]!["\(typ)_compiledURL"]!) {
                        downloadMeta![model]!.removeValue(forKey: "\(typ)_compiledURL")
                        downloadMeta![model]!.removeValue(forKey: "\(typ)_downloadURL")
                        downloadMeta![model]!.removeValue(forKey: "\(typ)_version")
                    }
                }
            }
        }
        appDelegate.appMeta.set(downloadMeta, forKey: "downloadMeta")
    }
    
    func deleteFile(compiledURL: String) -> Bool {
        if let path = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(compiledURL) {
            do {
                try FileManager.default.removeItem(at: path)
                return true
            } catch {
                return false
            }
        }
        return false
    }
}

//MARK:- UICollectionViewSelectMethods

extension homeViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.selectedItem = self.sections?[self.sectionMappings[indexPath.section].0]?[indexPath.row]
        self.selectedSection = indexPath.section
        self.currentColor = UIColor(named: "section\(indexPath.section % numSecColors)")
        performSegue(withIdentifier: "toModelView", sender: self)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destination = segue.destination as! ModelViewController
        destination.modelInfo = self.models?[self.selectedItem]
        destination.section = self.selectedSection
        destination.parentView = self
        destination.downloadManager = self.downloadManager
        destination.color = self.currentColor
    }
}

//MARK:- UICollectionViewDataSource

extension homeViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return sections?.count ?? 0
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return sectionMappings[section].1

    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! sectionCell
        cell.cellText?.text = self.sections?[self.sectionMappings[indexPath.section].0]?[indexPath.row]
        cell.backgroundColor = UIColor(named: "section\(indexPath.section % numSecColors)")
        cell.layer.cornerRadius = cell.layer.frame.height/5
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let headerView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: "reusableSectionHeader",
          for: indexPath) as? sectionHeader
          else {
            fatalError("Invalid view type")
        }
        
        headerView.sectionLabel.text = self.sectionMappings[indexPath.section].0.uppercased()
        headerView.backgroundColor = UIColor(named: "section\(indexPath.section % numSecColors)")
        return headerView
    }
}

//MARK:- AlertControllers

extension homeViewController {
    func createAlert(title: String, message: String, action: UIAlertAction? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let cusAction = action {
            alert.addAction(cusAction)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        } else {
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        }
        self.navigationController?.present(alert, animated: true, completion: nil)
    }
    
    func createDeleteAlert() {
        let alert = UIAlertController(title: "Delete all downloaded models??", message: "Only weights will be deleted", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (alertAction) in
            self.deleteAllWeights()
        }))
        self.navigationController?.present(alert, animated: true, completion: nil)
    }
    
    func createAlertDownload(silent: Bool) {
        displaySignUpPendingAlert()
        self.navigationController?.present(self.downloadAlert!, animated: true)
        setModelJson(controller: self, silent: silent)
    }
    
    func displaySignUpPendingAlert(){
        self.downloadAlert = downloadAlertController(title: "Downloading model info...", message: "", preferredStyle: .alert)
        self.downloadAlert?.parentController = self
    }
    
    func downloadErrorAction(title: String, message: String, allowCancel: Bool, erroString: String) {
        self.downloadAlert?.changeState(label: title, message: message, text: "Try again", allowCancel: allowCancel)
    }
    func silentFail() {
        self.updateCurrentInfo()
        self.downloadAlert?.dismiss(animated: true, completion: nil)
        self.collectionView.reloadData()
    }
    
    func createCustomModAlert() {
        let customController = customModelAlert(title: "Custom Model Download", message: C.customNotice, preferredStyle: .alert)
        customController.parentController = self
        self.customAlert = customController
        self.navigationController?.present(self.customAlert!, animated: true, completion: nil)
    }
    
    func createProgressAlert() {
        self.progressAlert = progressAlertController(title: "Downloading", message: nil, preferredStyle: .alert)
        self.progressAlert?.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (UIAlertAction) in
            self.downloadManager.cancelDownload()
        }))
        self.navigationController?.present(self.progressAlert!, animated: true, completion: nil)
    }
    
    func createCustomDownload(modelURL: String?, modelName: String?) {
        if let url = modelURL, let name = modelName {
            if !self.downloadManager.isDownloading {
                    if !self.downloadManager.startDownload(url: url, type: "custom", version: "1", modelName: name) {
                        self.createAlert(title: "Download Failed!", message: getAlertMessage(type: failedType.urlContent))
                    }
                    else {
                        self.createProgressAlert()
                        self.modelInfo = ["modelName" : modelName ?? "Default"]
                    }
                }
                else {
                    self.createAlert(title: "Download Failed!", message: getAlertMessage(type: failedType.AlreadyRunning))
                }
        }
        else {
            self.createAlert(title: "Download Failed!", message: getAlertMessage(type: failedType.invalidInput))
        }
    }
}

//MARK:- UICollectionViewFlowDelegate

extension homeViewController : UICollectionViewDelegateFlowLayout {
  
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      sizeForItemAt indexPath: IndexPath) -> CGSize {
    let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
    let availableWidth = view.frame.width - paddingSpace
    let widthPerItem = availableWidth / itemsPerRow
    return CGSize(width: widthPerItem, height: widthPerItem)
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      insetForSectionAt section: Int) -> UIEdgeInsets {
    return sectionInsets
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return sectionInsets.left
  }
}


