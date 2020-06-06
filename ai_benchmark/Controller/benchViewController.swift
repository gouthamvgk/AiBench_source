//
//  benchViewController.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 24/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class benchViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!
    

    var rootLayer: CALayer!
    var overlay: CALayer!
    var segLayer: CALayer!
    var posLayer: PoseLayer!
    var poseConfig: PoseBuilderConfiguration!
    weak var subLayer: AVCaptureVideoPreviewLayer?
    private let videoCapture = VideoCapture()
    var model: VModel?
    var modelURL: URL!
    var modelDevice: String!
    var task: String!
    var textLayer: CATextLayer?
    var currentImage: CVImageBuffer? = nil
    var startTime: CFAbsoluteTime!
    let maxBoundingBoxViews = 10
    var boundingBoxViews = [BoundingBoxView]()
    var colors: [String: UIColor] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.model = VModel(path: self.modelURL, device: self.modelDevice, task: self.task)
        self.model?.delegate = self
        self.videoCapture.delegate = self
        if self.task == inferType.detection.rawValue {
            self.createBboxViews()
            self.setupDetColors()
        }
        else if self.task == inferType.segmentation.rawValue {
            self.createSegView()
            self.setupSegColors()
        }
        else if self.task == inferType.poseEstimation.rawValue {
            self.poseConfig = PoseBuilderConfiguration()
            self.createPoseView()
        }
        self.createTextView()
    }

    override func viewDidLayoutSubviews() {
        self.setupAndBeginCapturingVideoFrames()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        setupAndBeginCapturingVideoFrames()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.destroyModel()
    }
    
    func createAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.navigationController?.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func cameraTapped(_ sender: UIButton) {
        self.videoCapture.flipCamera { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.createAlert(title: "Flipping failed!", message: "Camera flipping failed with error \(error). Restart App and try again. If problem persists contact developer.Make sure your camera supports hd1280x720 resolution. Switching to back camera!")
                }
                self.setupAndBeginCapturingVideoFrames()
            }
        }
    }
    
    func destroyModel() {
        if self.videoCapture.captureSession.isRunning {
            self.videoCapture.captureSession.stopRunning()
        }
        self.model?.model = nil
        self.model?.request = nil
        self.model = nil
    }

}


//MARK: SetupFunctions
extension benchViewController {
    private func setupAndBeginCapturingVideoFrames() {
        self.rootLayer = self.previewView.layer
        self.videoCapture.setUpAVCapture { error in
            if let error = error {
                self.createAlert(title: "Camera initialisation failed!", message: "Camera cannot be started due to interal error \(error). Restart the App. If the problem persists contack developer.")
                return
            }
            self.rootLayer.sublayers = nil
            self.subLayer = self.videoCapture.previewLayer
            if let layer = self.subLayer {
                self.rootLayer.addSublayer(layer)
            }
            self.setupLayers()
            self.videoCapture.startCapturing()
        }
    }
    
    private func setupLayers() {
        self.overlay = CALayer()
        self.overlay.name = "overlay"
        self.overlay.frame = self.rootLayer.bounds
        self.overlay.position = CGPoint(x: self.rootLayer.bounds.midX, y: self.rootLayer.bounds.midY)
        self.rootLayer.addSublayer(self.overlay)
        if self.task == inferType.detection.rawValue {
            self.setupBboxLayer()
        }
        else if self.task == inferType.segmentation.rawValue {
            self.setupSegLayer()
        }
        else if self.task == inferType.poseEstimation.rawValue {
            setupPoseLayer()
        }
        if self.textLayer != nil {
            self.setupTextLayer()
        }
    }
    
    func setupBboxLayer() {
        for box in self.boundingBoxViews {
            box.addToLayer(self.overlay)
        }
    }
    
    func setupSegLayer() {
        self.segLayer.frame = self.overlay.bounds
        self.segLayer.position = CGPoint(x: self.overlay.bounds.midX, y: self.overlay.bounds.midY)
        self.segLayer.isOpaque = false
        self.segLayer.opacity = 0.5
        self.segLayer.setNeedsDisplay()
        self.segLayer.contentsGravity = .resize
        self.overlay.addSublayer(segLayer)
        
    }
    
    func setupPoseLayer() {
        self.posLayer.frame = self.overlay.bounds
        self.posLayer.position = CGPoint(x: self.overlay.bounds.midX, y: self.overlay.bounds.midY)
        self.posLayer.setNeedsDisplay()
        self.posLayer.contentsGravity = .resize
        self.overlay.addSublayer(self.posLayer)
    }
    
    func setupTextLayer() {
        let b_h = self.overlay.bounds.height * 0.9
        let b_w = self.overlay.bounds.width*0.9
        self.textLayer?.bounds = CGRect(x: 0.0, y: 0.0, width: b_w, height: b_h)
        self.textLayer?.position = CGPoint(x: self.overlay.bounds.minX + b_w/2.0, y: self.overlay.bounds.minY + b_h/2.0)
        self.textLayer?.isWrapped = true
        self.overlay.addSublayer(self.textLayer!)
    }
    
    func setupSegColors(number: Int = 50) {
        for i in 0..<number {
            self.colors[String(i)] = UIColor(red: CGFloat.random(in: 0...1),
                                        green: CGFloat.random(in: 0...1),
                                        blue: CGFloat.random(in: 0...1),
                                        alpha: 1)
        }
    }
    
    func setupDetColors() {
        if let allLabels = self.model?.classNames {
            let labels = allLabels.components(separatedBy: ",")
            for label in labels {
                self.colors[label] = UIColor(red: CGFloat.random(in: 0...1),
                                      green: CGFloat.random(in: 0...1),
                                      blue: CGFloat.random(in: 0...1),
                                      alpha: 1)
            }
            self.colors["default"] = UIColor(red: CGFloat.random(in: 0...1),
                                    green: CGFloat.random(in: 0...1),
                                    blue: CGFloat.random(in: 0...1),
                                    alpha: 1)
        }
    }
}

//MARK: ViewCreateDeletefunctions
extension benchViewController {
    
    func removeDetection() {
        for box in self.boundingBoxViews {
            box.hide()
        }
    }
    
    func createPoseView() {
        let poseView = PoseLayer()
        poseView.name = "poselayer"
        self.posLayer = poseView
    }
    
    func createTextView() {
        let textLayer = CATextLayer()// container layer that has all the renderings of the observations
        textLayer.name = "TextOverlay"
        textLayer.alignmentMode = .left
        self.textLayer = textLayer
    }
    
    func createBboxViews() {
        for _ in 0..<self.maxBoundingBoxViews {
            self.boundingBoxViews.append(BoundingBoxView())
      }
    }
    
    func createSegView() {
        let segView = CALayer()
        segView.name = "SegmentationView"
        self.segLayer = segView
    }
    
    func createSegMap(netOut: MLMultiArray) -> UIImage? {
        let ptr = UnsafeMutablePointer<Int32> (OpaquePointer(netOut.dataPointer))
        let height = netOut.shape[0].intValue
        let width = netOut.shape[1].intValue
        let ystride = netOut.strides[0].intValue
        let xstride = netOut.strides[1].intValue
        let channels = 4
        var comp = UIColor.white.rgba
        var pixels = [UInt8](repeating: 255, count: width*height*channels)
        for x in 0..<width {
            for y in 0..<height {
                let value = ptr[y*ystride + x*xstride]
                let color = self.colors[String(value)] ?? UIColor.red
                comp = color.rgba
                for c in 0..<channels {
                    pixels[(y*width + x)*channels + c] = UInt8(getValue(ind: c, tuple: comp) * 255.0)
                }
            }
        }
        return UIImage.fromByteArrayRGBA(pixels, width: width, height: height)
    }
}

//MARK: Predictionfunctions
extension benchViewController: VideoCaptureDelegate {
    func videoCapture(_ videoCapture: VideoCapture, didCaptureFrame image: CMSampleBuffer) {
        if self.currentImage == nil, let buffer = CMSampleBufferGetImageBuffer(image) {
            self.startTime = CFAbsoluteTimeGetCurrent()
            self.currentImage = buffer
            self.model?.doPrediction(image: buffer)
        }
    }
}

//MARK:Drawing Functions
extension benchViewController {
    func writeDetResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.removeDetection()
        for (i,result) in results.enumerated() {
              guard let prediction = result as? VNRecognizedObjectObservation else {
                  continue
              }
              let topLabelObservation = prediction.labels[0]
              let scale = CGAffineTransform.identity.scaledBy(x: self.rootLayer.bounds.width, y: self.rootLayer.bounds.height)
              let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y:  -self.rootLayer.bounds.height)
              let objectBounds = prediction.boundingBox.applying(scale).applying(transform)
              // The labels array is a list of VNClassificationObservation objects,
              // with the highest scoring class first in the list.
              let label = String(format: "%@ %.1f", topLabelObservation.identifier, topLabelObservation.confidence * 100)
              let color = self.colors[topLabelObservation.identifier] ?? UIColor.cyan
              self.boundingBoxViews[i].show(frame: objectBounds, label: label, color: color)
            }
        CATransaction.commit()
    }
    
    
    func writeClassRegResults(priString: String, time: Double) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        let fps = String(format: " FPS: %.2f", 1.0/time)
        let combinedString = "\(priString)\n  \(fps)"
        let largeFont = UIFont(name: "Chalkboard SE", size: 20.0)!
        let formattedString = NSMutableAttributedString(string: combinedString)
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont, NSMutableAttributedString.Key.foregroundColor: #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1),
            NSMutableAttributedString.Key.backgroundColor: #colorLiteral(red: 0.8032323776, green: 0.8549019694, blue: 0.7520004853, alpha: 1)], range: NSRange(location: 0, length: combinedString.count))
        self.textLayer?.string = formattedString
        CATransaction.commit()
    }
    
    func writeError(priString: String) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        let largeFont = UIFont(name: "Chalkboard SE", size: 20.0)!
        let formattedString = NSMutableAttributedString(string: priString)
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont, NSMutableAttributedString.Key.foregroundColor: #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1),
            NSMutableAttributedString.Key.backgroundColor: #colorLiteral(red: 0.8032323776, green: 0.8549019694, blue: 0.7520004853, alpha: 1)], range: NSRange(location: 0, length: priString.count))
        self.textLayer?.string = formattedString
        CATransaction.commit()
    }
    
    func writeFPS(time: Double){
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        let fps = String(format: " FPS: %.2f", 1.0/time)
        let largeFont = UIFont(name: "Chalkboard SE", size: 20.0)!
        let formattedString = NSMutableAttributedString(string: fps)
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont, NSMutableAttributedString.Key.foregroundColor: #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1),
            NSMutableAttributedString.Key.backgroundColor: #colorLiteral(red: 0.8032323776, green: 0.8549019694, blue: 0.7520004853, alpha: 1)], range: NSRange(location: 0, length: fps.count))
        self.textLayer?.string = formattedString
        CATransaction.commit()
    }
    
    func writeSegMap(image: UIImage?) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        DispatchQueue.main.async {
            self.segLayer.contents = image?.cgImage
            
        }
        CATransaction.commit()
    }
    
    func writePosResults(results: [VNCoreMLFeatureValueObservation]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        let poseOutput = PoseNetOutput(results: results, modelInputSize: CGSize(width: C.posWidth, height: C.posHeight), modelOutputStride: C.posStride)
        let poseBuilder = PoseBuilder(output: poseOutput, configuration: self.poseConfig, imageWidth: self.overlay.bounds.width, imageHeight: self.overlay.bounds.height)
        let poses = [poseBuilder.pose]
        self.posLayer.show(poses: poses)
        CATransaction.commit()
    }
    
    func detectType(feature: MLFeatureValue) -> String {
        switch feature.type {
        case .multiArray:
            return "MultiArray Shape:\(feature.multiArrayValue?.shape ?? [NSNumber(booleanLiteral: false)])"
        case .dictionary:
            return "Dictionary Num_elements:\(feature.dictionaryValue.count)"
        case .image:
            return "ImageType CVPixelBuffer"
        case .sequence:
            return "MLSequence"
        case .string:
            return "String \(feature.stringValue)"
        case .double:
            return "Double \(feature.doubleValue)"
        case .int64:
            return "Int64 \(feature.int64Value)"
        case .invalid:
            return "Invalid type"
        default:
            return "Cannot identify type"
        }
    }
}

//MARK: VisionPostprocessingfunctions
extension benchViewController: ModelProcessDelegate {
    func processError(errorString: String) {
        self.currentImage = nil
        let resultString = "Following error occured: \(errorString) Check the Doc for passing correct model"
        DispatchQueue.main.async {
            self.writeError(priString: resultString)
        }
    }
    
    func processClassifications(for request: VNRequest, error: Error?) {
        let elapsedTime = CFAbsoluteTimeGetCurrent() - self.startTime
        var resultString = ""
        guard let results = request.results else {
            resultString = "Error occured during inference decoding! If it's a custom model check the Doc for correct format. If not contact developer"
            DispatchQueue.main.async {
                self.writeError(priString: resultString)
            }
            self.currentImage = nil
            return
        }
        guard let classifications = results as? [VNClassificationObservation] else {
            self.currentImage = nil
            return
        }
        if classifications.isEmpty {
            resultString = "Nothing recognized"
        } else {
            let topClassifications = classifications.prefix(2)
            let descriptions = topClassifications.map { classification in
               return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
            }
            resultString = "Classification:\n" + descriptions.joined(separator: "\n")
        }
        self.currentImage = nil
        DispatchQueue.main.async {
            self.writeClassRegResults(priString: resultString, time: elapsedTime)
        }
    }
    
    func processRegression(for request: VNRequest, error: Error?) {
        let elapsedTime = CFAbsoluteTimeGetCurrent() - self.startTime
        var resultString = ""
        guard let results = request.results else {
            resultString = "Error occured during inference decoding! If it's a custom model check the Doc for correct format. If not contact developer"
            DispatchQueue.main.async {
                self.writeError(priString: resultString)
            }
            self.currentImage = nil
            return
        }
        guard let regression = results as? [VNCoreMLFeatureValueObservation] else {
            self.currentImage = nil
            return
        }
        for (i, res) in regression.enumerated() {
            if i == 0 {
                resultString += "Regression:"
            }
            resultString += "\n"
            resultString += "  Output:\(i+1) Name: \(res.featureName) \(detectType(feature: res.featureValue))"
            
        }
        self.currentImage = nil
        DispatchQueue.main.async {
            self.writeClassRegResults(priString: resultString, time: elapsedTime)
        }
    }
    

    func processPoseEstimation(for request: VNRequest, error: Error?) {
        let elapsedTime = CFAbsoluteTimeGetCurrent() - self.startTime
        DispatchQueue.main.async {
            self.writeFPS(time: elapsedTime)
        }
        guard let results = request.results else {
            let resultString = "Error occured during inference decoding! If it's a custom model check the Doc for correct format. If not contact developer"
            DispatchQueue.main.async {
                self.writeError(priString: resultString)
            }
            self.currentImage = nil
            return
        }
        guard let posResults = results as? [VNCoreMLFeatureValueObservation] else {
            self.currentImage = nil
            return
        }
        self.currentImage = nil
        DispatchQueue.main.async {
            self.writePosResults(results: posResults)
        }
    }
    
    func processSegmentation(for request: VNRequest, error: Error?) {
        let elapsedTime = CFAbsoluteTimeGetCurrent() - self.startTime
        DispatchQueue.main.async {
            self.writeFPS(time: elapsedTime)
        }
        guard let results = request.results else {
            let resultString = "Error occured during inference decoding! If it's a custom model check the Doc for correct format. If not contact developer"
            DispatchQueue.main.async {
                self.writeError(priString: resultString)
            }
            self.currentImage = nil
            return
        }
        guard let segmentations = results as? [VNCoreMLFeatureValueObservation] else {
            self.currentImage = nil
            return
        }
        guard let segMap = segmentations[0].featureValue.multiArrayValue else {
            self.currentImage = nil
            return
        }
        let image = createSegMap(netOut: segMap)
        self.currentImage = nil
        self.writeSegMap(image: image)
        }
        
 
    func processDetections(for request: VNRequest, error: Error?)  {
        let elapsedTime = CFAbsoluteTimeGetCurrent() - self.startTime
        DispatchQueue.main.async {
            self.writeFPS(time: elapsedTime)
        }
        guard let results = request.results else {
            let resultString = "Error occured during inference decoding! If it's a custom model check the Doc for correct format. If not contact developer"
            DispatchQueue.main.async {
                self.writeError(priString: resultString)
            }
            self.currentImage = nil
            return
        }
        self.currentImage = nil
        DispatchQueue.main.async {
            self.writeDetResults(results)
        }
    }
}
