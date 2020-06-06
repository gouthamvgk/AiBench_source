//
//  poseBuilderConfiguration.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 31/05/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import CoreGraphics
enum Algorithm: Int {
    case single
    case multiple
}

struct PoseBuilderConfiguration {
    var jointConfidenceThreshold = 0.1
    var poseConfidenceThreshold = 0.5
    var matchingJointDistance = 40.0
    var localSearchRadius = 3
    var maxPoseCount = 15
    var adjacentJointOffsetRefinementSteps = 3
}

struct PoseBuilder {
    let output: PoseNetOutput
    let modelToInputTransformation: CGAffineTransform
    var configuration: PoseBuilderConfiguration
    init(output: PoseNetOutput, configuration: PoseBuilderConfiguration, imageWidth: CGFloat, imageHeight: CGFloat) {
        self.output = output
        self.configuration = configuration
        modelToInputTransformation = CGAffineTransform(scaleX: imageWidth / output.modelInputSize.width,
                                                       y: imageHeight / output.modelInputSize.height)
    }
}


extension PoseBuilder {
    /// Returns a pose constructed using the outputs from the PoseNet model.
    var pose: Pose {
        var pose = Pose()
        pose.joints.values.forEach { joint in
            configure(joint: joint)
        }
        pose.confidence = pose.joints.values
            .map { $0.confidence }.reduce(0, +) / Double(Joint.numberOfJoints)

        // Map the pose joints positions back onto the original image.
        pose.joints.values.forEach { joint in
            joint.position = joint.position.applying(modelToInputTransformation)
        }

        return pose
    }

    private func configure(joint: Joint) {
        var bestCell = PoseNetOutput.Cell(0, 0)
        var bestConfidence = 0.0
        for yIndex in 0..<output.height {
            for xIndex in 0..<output.width {
                let currentCell = PoseNetOutput.Cell(yIndex, xIndex)
                let currentConfidence = output.confidence(for: joint.name, at: currentCell)

                // Keep track of the cell with the greatest confidence.
                if currentConfidence > bestConfidence {
                    bestConfidence = currentConfidence
                    bestCell = currentCell
                }
            }
        }
        joint.cell = bestCell
        joint.position = output.position(for: joint.name, at: joint.cell)
        joint.confidence = bestConfidence
        joint.isValid = joint.confidence >= configuration.jointConfidenceThreshold
    }
}

