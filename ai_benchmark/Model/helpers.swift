//
//  helpers.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 19/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import Foundation
import UIKit
import CoreGraphics
import CoreML

extension MLFeatureProvider {
    func multiArrayValue(for feature: PoseNetOutput.Feature) -> MLMultiArray? {
        return featureValue(for: feature.rawValue)?.multiArrayValue
    }
}

extension MLMultiArray {
    subscript(index: [Int]) -> NSNumber {
        return self[index.map { NSNumber(value: $0) } ]
    }
}


extension CGPoint {
//    init(_ cell: PoseNetOutput.Cell) {
//        self.init(x: CGFloat(cell.xIndex), y: CGFloat(cell.yIndex))
//    }

    /// Calculates and returns the squared distance between this point and another.
    func squaredDistance(to other: CGPoint) -> CGFloat {
        let diffX = other.x - x
        let diffY = other.y - y

        return diffX * diffX + diffY * diffY
    }

    /// Calculates and returns the distance between this point and another.
    func distance(to other: CGPoint) -> Double {
        return Double(squaredDistance(to: other).squareRoot())
    }

    /// Calculates and returns the result of an element-wise addition.
    static func + (_ lhs: CGPoint, _ rhs: CGVector) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    /// Performs element-wise addition.
    static func += (lhs: inout CGPoint, _ rhs: CGVector) {
        lhs.x += rhs.dx
        lhs.y += rhs.dy
    }

    /// Calculates and returns the result of an element-wise multiplication.
    static func * (_ lhs: CGPoint, _ scale: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * scale, y: lhs.y * scale)
    }

    /// Calculates and returns the result of an element-wise multiplication.
    static func * (_ lhs: CGPoint, _ rhs: CGSize) -> CGPoint {
        return CGPoint(x: lhs.x * rhs.width, y: lhs.y * rhs.height)
    }
}


extension UIColor {
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red, green, blue, alpha)
    }
}


extension UIImage {
  /**
    Resizes the image to width x height and converts it to an RGB CVPixelBuffer.
    
  */
    
  @nonobjc public class func fromByteArrayRGBA(_ bytes: [UInt8],
                                               width: Int,
                                               height: Int,
                                               scale: CGFloat = 0,
                                               orientation: UIImage.Orientation = .up) -> UIImage? {
    if let cgImage = CGImage.fromByteArrayRGBA(bytes, width: width, height: height) {
      return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    } else {
      return nil
    }
  }
}

extension CGImage {
  /**
    Converts the image into an array of RGBA bytes.
  */
    
  var size: CGSize {
      return CGSize(width: width, height: height)
  }
    
    
  @nonobjc public class func fromByteArrayRGBA(_ bytes: [UInt8],
                                               width: Int,
                                               height: Int) -> CGImage? {
    return fromByteArray(bytes, width: width, height: height,
                         bytesPerRow: width * 4,
                         colorSpace: CGColorSpaceCreateDeviceRGB(),
                         alphaInfo: .premultipliedLast)
  }


  @nonobjc class func fromByteArray(_ bytes: [UInt8],
                                    width: Int,
                                    height: Int,
                                    bytesPerRow: Int,
                                    colorSpace: CGColorSpace,
                                    alphaInfo: CGImageAlphaInfo) -> CGImage? {
    return bytes.withUnsafeBytes { ptr in
      let context = CGContext(data: UnsafeMutableRawPointer(mutating: ptr.baseAddress!),
                              width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bytesPerRow: bytesPerRow,
                              space: colorSpace,
                              bitmapInfo: alphaInfo.rawValue)
      return context?.makeImage()
    }
  }
}
