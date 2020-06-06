//
//  poseOutput.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 31/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import CoreML
import Vision

/// - Tag: PoseNetOutput
struct PoseNetOutput {
    enum Feature: String {
        case heatmap = "heatmap"
        case offsets = "offsets"
        case backwardDisplacementMap = "displacementBwd"
        case forwardDisplacementMap = "displacementFwd"
    }
    
    struct Cell {
        let yIndex: Int
        let xIndex: Int

        init(_ yIndex: Int, _ xIndex: Int) {
            self.yIndex = yIndex
            self.xIndex = xIndex
        }

        static var zero: Cell {
            return Cell(0, 0)
        }
    }
    
    var heatmap: MLMultiArray!
    var offsets: MLMultiArray!
    var backwardDisplacementMap: MLMultiArray!
    var forwardDisplacementMap: MLMultiArray!
    let modelInputSize: CGSize
    let modelOutputStride: Int
    var height: Int {
        return heatmap.shape[1].intValue
    }
    var width: Int {
        return heatmap.shape[2].intValue
    }

    init(results: [VNCoreMLFeatureValueObservation], modelInputSize: CGSize, modelOutputStride: Int) {

        for res in results {
            switch res.featureName {
            case Feature.heatmap.rawValue:
                self.heatmap = res.featureValue.multiArrayValue!
            case Feature.offsets.rawValue:
                self.offsets = res.featureValue.multiArrayValue!
            case Feature.backwardDisplacementMap.rawValue:
                self.backwardDisplacementMap = res.featureValue.multiArrayValue!
            case Feature.forwardDisplacementMap.rawValue:
                self.forwardDisplacementMap = res.featureValue.multiArrayValue!
            default:
                fatalError("Invalid output at posenet")
            }
        }
        self.modelInputSize = modelInputSize
        self.modelOutputStride = modelOutputStride
    }
}

// MARK: - Utility and accessor methods

extension PoseNetOutput {
    /// Calculates and returns the position for a given joint type at the specified grid cell.
    ///
    /// The joint's position is calculated by multiplying the y and x indices by the model's output stride
    /// plus the associated offset encoded in the PoseNet model's `offsets` array.
    ///
    /// - parameters:
    ///     - jointName: Query joint used to index the `offsets` array.
    ///     - cell: The coordinates in `offsets` output for the given joint name.
    /// - returns: Calculated position for the specified joint and grid cell.
    func position(for jointName: Joint.Name, at cell: Cell) -> CGPoint {
        let jointOffset = offset(for: jointName, at: cell)

        // First, calculate the joint’s coarse position.
        var jointPosition = CGPoint(x: cell.xIndex * modelOutputStride,
                                    y: cell.yIndex * modelOutputStride)

        // Then, add the offset to get a precise position.
        jointPosition += jointOffset

        return jointPosition
    }

    /// Returns the cell for a given position.
    ///
    /// - parameters:
    ///     - position: Position to map to an index.
    /// - returns: Mapped cell index.
    func cell(for position: CGPoint) -> Cell? {
        let yIndex = Int((position.y / CGFloat(modelOutputStride))
            .rounded())
        let xIndex = Int((position.x / CGFloat(modelOutputStride))
            .rounded())

        guard yIndex >= 0 && yIndex < height
            && xIndex >= 0 && xIndex < width else {
                return nil
        }

        return Cell(yIndex, xIndex)
    }

    /// Returns the associated offset for a joint at the specified cell index.
    ///
    /// Queries the `offsets` array at position `[jointName, cell.yIndex, cell.xIndex]` for the vertical
    /// component and `[jointName + <number of joints>, cell.yIndex, cell.xIndex]` for the
    /// horizontal component.
    ///
    /// - parameters:
    ///     - jointName: Joint name whose `rawValue` is used as the index of the first dimension of the `offsets` array.
    ///     - cell: The coordinates in the `offsets` output for the given joint name.
    func offset(for jointName: Joint.Name, at cell: Cell) -> CGVector {
        // Create the index for the y and x component of the offset.
        let yOffsetIndex = [jointName.rawValue, cell.yIndex, cell.xIndex]
        let xOffsetIndex = [jointName.rawValue + Joint.numberOfJoints, cell.yIndex, cell.xIndex]

        // Obtain y and x component of the offset from the offsets array.
        let offsetY: Double = offsets[yOffsetIndex].doubleValue
        let offsetX: Double = offsets[xOffsetIndex].doubleValue

        return CGVector(dx: CGFloat(offsetX), dy: CGFloat(offsetY))
    }

    /// Returns the associated confidence for a joint at the specified index.
    ///
    /// Queries the `heatmap` array at position `[jointName, index.y, index.x]` for the joint's
    /// associated confidence value.
    ///
    /// - parameters:
    ///     - jointName: Joint name whose `rawValue` is used as the index of the first dimension of the `heatmap` array.
    ///     - cell: The coordinates in `heatmap` output for the given joint name.
    func confidence(for jointName: Joint.Name, at cell: Cell) -> Double {
        let multiArrayIndex = [jointName.rawValue, cell.yIndex, cell.xIndex]
        return heatmap[multiArrayIndex].doubleValue
    }

    /// Returns the forward displacement vector for the specified edge and index.
    ///
    /// - parameters:
    ///     - edgeIndex: Index of the first dimension of the `forwardDisplacementMap` array.
    ///     - cell: The coordinates in `forwardDisplacementMap` output for the given edge.
    /// - returns: Displacement vector for `edge` at index `yIndex` and `xIndex`.
    func forwardDisplacement(for edgeIndex: Int, at cell: Cell) -> CGVector {
        // Create the MLMultiArray index
        let yEdgeIndex = [edgeIndex, cell.yIndex, cell.xIndex]
        let xEdgeIndex = [edgeIndex + Pose.edges.count, cell.yIndex, cell.xIndex]

        // Extract the displacements from MultiArray
        let displacementY = forwardDisplacementMap[yEdgeIndex].doubleValue
        let displacementX = forwardDisplacementMap[xEdgeIndex].doubleValue

        return CGVector(dx: displacementX, dy: displacementY)
    }

    /// Returns the backwards displacement vector for the specified edge and cell.
    ///
    /// - parameters:
    ///     - edgeIndex: Index of the first dimension of the `backwardDisplacementMap` array.
    ///     - cell: The coordinates in `backwardDisplacementMap` output for the given edge.
    /// - returns: Displacement vector for `edge` at index `yIndex` and `xIndex`.
    func backwardDisplacement(for edgeIndex: Int, at cell: Cell) -> CGVector {
        // Create the MLMultiArray index
        let yEdgeIndex = [edgeIndex, cell.yIndex, cell.xIndex]
        let xEdgeIndex = [edgeIndex + Pose.edges.count, cell.yIndex, cell.xIndex]

        // Extract the displacements from MultiArray
        let displacementY = backwardDisplacementMap[yEdgeIndex].doubleValue
        let displacementX = backwardDisplacementMap[xEdgeIndex].doubleValue

        return CGVector(dx: displacementX, dy: displacementY)
    }
}


