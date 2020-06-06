//
//  jsonUtils.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 03/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON

func setModelJson(controller: homeViewController, silent: Bool) {
    let userDef = UIApplication.shared.delegate as! AppDelegate
    let meta = userDef.appMeta
    let metaKeys = meta.dictionaryRepresentation().keys
    if let hitURL = URL(string: C.infoURL) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(10)
        configuration.timeoutIntervalForResource = TimeInterval(10)
        let session = URLSession(configuration: configuration)
        let task = session.dataTask(with: hitURL) { (data, response, error) in
            if let er = error {
                DispatchQueue.main.async {
                    if !(metaKeys.contains("isFirstTime")) {
                        controller.downloadErrorAction(title: "Check your Internet Connection", message: "Internet Connection needed atleast for first time to setup app", allowCancel: false, erroString: er.localizedDescription)
                    } else {
                        if silent {
                            controller.silentFail()
                        } else {
                            controller.downloadErrorAction(title: "Check you Internet Connection", message: "Internet needed for refreshing!", allowCancel: true, erroString: er.localizedDescription)
                        }
                    }
                }
                return
            }
            if let actData = data {
                do {
                    let json = try JSON(data: actData)
                    var modelJson = json.dictionaryObject as! [String : [String : String]]
                    var sections =  [String: [String]]()
                    let downloadInfo =  [String: [String:String]]()
                    for (_, val) in modelJson {
                        if let actValue = val["family"] {
                            if !(sections.keys.contains(actValue)) {
                                sections[actValue] = [val["modelName"] ?? "None"]
                            } else {
                                sections[actValue]!.append(val["modelName"] ?? "None")
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        if !(metaKeys.contains("isFirstTime")) {
                            meta.set(modelJson, forKey: "modelInfo")
                            meta.set(sections, forKey: "modelSections")
                            meta.set(downloadInfo, forKey: "downloadMeta")
                            meta.set(false, forKey: "isFirstTime")
                        } else {
                            let modelInfoMeta = meta.dictionary(forKey: "modelInfo") as? [String : [String : String]]
                            let sectionMeta = meta.dictionary(forKey: "modelSections") as? [String : [String]]
                            if modelInfoMeta != nil, sectionMeta != nil {
                                for (key, val) in modelInfoMeta! {
                                    if val["family"]! == "Custom Models" {
                                        modelJson[key] = val
                                        sections.updateValue(sectionMeta!["Custom Models"]!, forKey: "Custom Models")
                                    }
                                }
                            }
                            meta.set(modelJson, forKey: "modelInfo")
                            meta.set(sections, forKey: "modelSections")
                        }

                        controller.updateCurrentInfo()
                        controller.downloadAlert?.dismiss(animated: true, completion: nil)
                        controller.collectionView.reloadData()
                    }
                } catch {
                    DispatchQueue.main.async {
                        if !(metaKeys.contains("isFirstTime")) {
                            controller.downloadErrorAction(title: "Problem with server!", message: "Please try again! If error persists contact developer", allowCancel: false, erroString: error.localizedDescription)
                        } else {
                            if silent {
                                controller.silentFail()
                            } else {
                                controller.downloadErrorAction(title: "Problem with server!", message: "Pleaser try again after some time. If problem persists contact developer", allowCancel: true, erroString: error.localizedDescription)
                            }
                        }
                    }
                    return
                }
            }
        }
        task.resume()
    }
}

