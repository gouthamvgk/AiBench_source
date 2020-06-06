//
//  videoCapture.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 24/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import AVFoundation
import CoreVideo
import UIKit
import VideoToolbox

protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ videoCapture: VideoCapture, didCaptureFrame image: CMSampleBuffer)
}

/// - Tag: VideoCapture
class VideoCapture: NSObject {
    enum VideoCaptureError: Error {
        case captureSessionIsMissing
        case invalidInput
        case invalidOutput
        case unknown
        case cantConnect
    }

    weak var delegate: VideoCaptureDelegate?
    var bufferSize: CGSize = .zero
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private(set) var cameraPostion = AVCaptureDevice.Position.back
    private let sessionQueue = DispatchQueue(label: "backgroundTasks")
    
    public func flipCamera(completion: @escaping (Error?) -> Void) {
        sessionQueue.async {
            do {
                self.cameraPostion = self.cameraPostion == .back ? .front : .back
                self.captureSession.beginConfiguration()
                try self.setCaptureSessionInput()
                try self.setCaptureSessionOutput()
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                self.captureSession.commitConfiguration()
                self.cameraPostion = .back
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
}

//MARK:-ClassSetupfunctions
extension VideoCapture {
    public func setUpAVCapture(completion: @escaping (Error?) -> Void) {
        sessionQueue.async {
            do {
                try self.setUpAVCapture()
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureSession.commitConfiguration()
                    completion(error)
                }
            }
        }
    }

    private func setUpAVCapture() throws {
        if self.captureSession.isRunning {
            self.captureSession.stopRunning()
        }
        self.captureSession.beginConfiguration()

        self.captureSession.sessionPreset = .hd1280x720

        try self.setCaptureSessionInput()

        try self.setCaptureSessionOutput()

        
        if let parent = self.delegate as? benchViewController {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            self.previewLayer.videoGravity = AVLayerVideoGravity.resize
            self.previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.current.orientation.rawValue)!

            self.previewLayer.frame = parent.rootLayer.bounds
        }
        self.captureSession.commitConfiguration()
        
    }

}

//MARK:- SessionSetupfunctions
extension VideoCapture {
    private func setCaptureSessionInput() throws {
        // Use the default capture device to obtain access to the physical device
        // and associated properties.
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video,
            position: cameraPostion) else {
                throw VideoCaptureError.invalidInput
        }

        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            throw VideoCaptureError.invalidInput
        }

        guard captureSession.canAddInput(videoInput) else {
            throw VideoCaptureError.invalidInput
        }

        captureSession.addInput(videoInput)
        do {
            try  captureDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((captureDevice.activeFormat.formatDescription))
            self.bufferSize.width = CGFloat(dimensions.width)
            self.bufferSize.height = CGFloat(dimensions.height)
            captureDevice.unlockForConfiguration()
        } catch {
            throw VideoCaptureError.unknown
        }
    }

    private func setCaptureSessionOutput() throws {
        captureSession.outputs.forEach { output in
            captureSession.removeOutput(output)
        }
        
        let settings: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]

        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw VideoCaptureError.invalidOutput
        }

        captureSession.addOutput(videoOutput)
//        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        // Update the video orientation
        if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.isEnabled = true
            connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.current.orientation.rawValue)!
            connection.isVideoMirrored = cameraPostion == .front
            if connection.videoOrientation == .landscapeLeft {
                connection.videoOrientation = .landscapeRight
            } else if connection.videoOrientation == .landscapeRight {
                connection.videoOrientation = .landscapeLeft
            }
        }
        else {
            throw VideoCaptureError.cantConnect
        }
        
    }
}

//MARK:-Capturefunctions
extension VideoCapture {
    public func startCapturing(completion completionHandler: (() -> Void)? = nil) {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }

            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
    }

    public func stopCapturing(completion completionHandler: (() -> Void)? = nil) {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }

            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let delegate = delegate else { return }
            delegate.videoCapture(self, didCaptureFrame: sampleBuffer)
        
    }
}
