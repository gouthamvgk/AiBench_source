//
//  downloadAlert.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 10/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import UIKit

class downloadAlertController: UIAlertController {
    var activitySpin: UIActivityIndicatorView?
    var parentController: homeViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.activitySpin = UIActivityIndicatorView(style: .medium)
        self.activitySpin!.translatesAutoresizingMaskIntoConstraints = false
        self.activitySpin!.isUserInteractionEnabled = false
        self.activitySpin!.startAnimating()
        self.view.addSubview(self.activitySpin!)
        self.view.heightAnchor.constraint(equalToConstant: 105).isActive = true
        self.activitySpin!.centerXAnchor.constraint(equalTo: self.view.centerXAnchor, constant: 0).isActive = true
        self.activitySpin!.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -20).isActive = true
    }
    func changeState(label: String, message: String, text: String, allowCancel: Bool = false) {
        self.title = label
        self.message = message
        self.activitySpin?.stopAnimating()
        if allowCancel {
            self.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        }
        self.addAction(UIAlertAction(title: text, style: .default, handler: { (alert) in
            if let parentCont = self.parentController {
                DispatchQueue.main.async {
                    parentCont.createAlertDownload(silent: false)
                }
            }
        }))
    }
}


class progressAlertController: UIAlertController {
    var progress: UIProgressView?
    var parentController: ModelViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.progress = UIProgressView(progressViewStyle: .default)
        self.progress!.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.progress!)
        self.progress!.progress = 0.0
        self.progress!.tintColor = self.view.tintColor
        self.progress!.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -45).isActive = true
        self.progress?.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 5).isActive = true
        self.progress?.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -5).isActive = true
//        self.progress?.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
//        self.progress?.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
    }
}

class customModelAlert: UIAlertController {
    var textField1: UITextField?
    var textField2: UITextField?
    var parentController: homeViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addTextField { (textField) in
            self.textField1 = textField
            textField.addTarget(self, action: #selector(self.textFieldDidChange), for: .editingChanged)
            textField.placeholder = "Enter model URL"
        }
        self.addTextField { (textField) in
            self.textField2 = textField
            textField.addTarget(self, action: #selector(self.textFieldDidChange), for: .editingChanged)
            textField.placeholder = "Model Name"
        }
        self.addAction(UIAlertAction(title: "Add Model", style: .default, handler: { (alertAction) in
            DispatchQueue.main.async {
                self.parentController?.createCustomDownload(modelURL: self.textField1!.text, modelName: self.textField2?.text)
            }
        }))
        self.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.actions[0].isEnabled = false
    }

    
    @objc func textFieldDidChange() {
        if self.textField1?.text?.count ?? 0 > 0 && self.textField2?.text?.count ?? 0 > 0 {
            self.actions[0].isEnabled = true
        }
        else {
            self.actions[0].isEnabled = false
        }
    }
}
