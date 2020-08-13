//
//  DebugHelpers.swift
//  InvisibleMap
//
//  Created by Paul Ruvolo on 8/11/20.
//  Copyright © 2020 Occam Lab. All rights reserved.
//

import Foundation
import UIKit
import ARKit
import GLKit

/// Adds or updates a tag node when a tag is detected
///
/// - Parameter tag: the april tag detected by the visual servoing platform
func addTagDetectionNode(sceneView: ARSCNView, capturedImage: UIImage, depthImage: CVPixelBuffer?, snapTagsToVertical: Bool, aprilTagDetectionDictionary: inout Dictionary<Int, AprilTagTracker>, tag: inout AprilTags, cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3) {
 //   let generator = UIImpactFeedbackGenerator(style: .heavy)
//    generator.impactOccurred()
    let pose = tag.poseData

    let originalTagPose = simd_float4x4(rows: [simd_float4(Float(pose.0), Float(pose.1), Float(pose.2),Float(pose.3)), simd_float4(Float(pose.4), Float(pose.5), Float(pose.6), Float(pose.7)), simd_float4(Float(pose.8), Float(pose.9), Float(pose.10), Float(pose.11)), simd_float4(Float(pose.12), Float(pose.13), Float(pose.14), Float(pose.15))])
    
    let aprilTagToARKit = simd_float4x4(diagonal:simd_float4(1, -1, -1, 1))
    // convert from April Tag's convention to ARKit's convention
    let tagPoseARKit = aprilTagToARKit*originalTagPose
    // project into world coordinates
    var scenePose = cameraTransform*tagPoseARKit
    let aprilTagTracker:AprilTagTracker = aprilTagDetectionDictionary[Int(tag.number), default: AprilTagTracker(sceneView, tagId: Int(tag.number))]

    if let depthImage = depthImage {
        scenePose = aprilTagTracker.adjustBasedOnDepth(scenePose: scenePose, tag: &tag, cameraImage: capturedImage, depthImage: depthImage, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
    }

    let transVar = simd_float3(Float(tag.transVecVar.0), Float(tag.transVecVar.1), Float(tag.transVecVar.2))
    let quatVar = simd_float4(x: Float(tag.quatVar.0), y: Float(tag.quatVar.1), z: Float(tag.quatVar.2), w: Float(tag.quatVar.3))

    if snapTagsToVertical {
        scenePose = scenePose.makeZFlat().alignY()
    }
    let transVarMatrix = simd_float3x3(diagonal: transVar)
    let quatVarMatrix = simd_float4x4(diagonal: quatVar)

    // this is the linear transform that takes the original tag pose to the final world pose
    let linearTransform = scenePose*originalTagPose.inverse
    let q = simd_quatf(linearTransform)

    let quatMultiplyAsLinearTransform =
        simd_float4x4(columns: (simd_float4(q.vector.w, q.vector.z, -q.vector.y, -q.vector.x),
                                simd_float4(-q.vector.z, q.vector.w, q.vector.x, -q.vector.y),
                                simd_float4(q.vector.y, -q.vector.x, q.vector.w, -q.vector.z),
                                simd_float4(q.vector.x, q.vector.y, q.vector.z, q.vector.w)))
    let sceneTransVar = linearTransform.getUpper3x3()*transVarMatrix*linearTransform.getUpper3x3().transpose
    let sceneQuatVar = quatMultiplyAsLinearTransform*quatVarMatrix*quatMultiplyAsLinearTransform.transpose

    let scenePoseQuat = simd_quatf(scenePose)
    let scenePoseTranslation = scenePose.getTrans()
    aprilTagDetectionDictionary[Int(tag.number)] = aprilTagTracker

    // TODO: need some sort of logic to discard old detections.  One method that seems good would be to add some process noise (Q_k non-zero)
    aprilTagTracker.updateTagPoseMeans(id: Int(tag.number), detectedPosition: scenePoseTranslation, detectedPositionVar: sceneTransVar, detectedQuat: scenePoseQuat, detectedQuatVar: sceneQuatVar)
    
    let tagNode: SCNNode
    if let existingTagNode = sceneView.scene.rootNode.childNode(withName: "Tag_\(String(tag.number))", recursively: false)  {
        tagNode = existingTagNode
        tagNode.simdPosition = aprilTagTracker.tagPosition
        tagNode.simdOrientation = aprilTagTracker.tagOrientation
    } else {
        tagNode = SCNNode()
        tagNode.simdPosition = aprilTagTracker.tagPosition
        tagNode.simdOrientation = aprilTagTracker.tagOrientation
        tagNode.geometry = SCNBox(width: 0.11, height: 0.11, length: 0.05, chamferRadius: 0)
        tagNode.name = "Tag_\(String(tag.number))"
        tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
        sceneView.scene.rootNode.addChildNode(tagNode)
    }
    
    /// Adds axes to the tag to aid in the visualization
    let xAxis = SCNNode(geometry: SCNBox(width: 1.0, height: 0.05, length: 0.05, chamferRadius: 0))
    xAxis.position = SCNVector3.init(0.75, 0, 0)
    xAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.red
    let yAxis = SCNNode(geometry: SCNBox(width: 0.05, height: 1.0, length: 0.05, chamferRadius: 0))
    yAxis.position = SCNVector3.init(0, 0.75, 0)
    yAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.green
    let zAxis = SCNNode(geometry: SCNBox(width: 0.05, height: 0.05, length: 1.0, chamferRadius: 0))
    zAxis.position = SCNVector3.init(0, 0, 0.75)
    zAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
    tagNode.addChildNode(xAxis)
    tagNode.addChildNode(yAxis)
    tagNode.addChildNode(zAxis)
}

func createTagDebugImage(tagDetections: Array<AprilTags>, image:UIImage)->UIImage? {
    // Create a context of the starting image size and set it as the current one
    UIGraphicsBeginImageContext(image.size)
    
    // Draw the starting image in the current context as background
    image.draw(at: CGPoint.zero)

    // Get the current context
    let context = UIGraphicsGetCurrentContext()!
    context.setFillColor(UIColor.cyan.cgColor)
    context.setAlpha(0.5)
    context.setLineWidth(0.0)
    let visualizationCirclesRadius = 10.0;
    for tag in tagDetections {
        // TODO: convert tuple to array to make this less janky (https://developer.apple.com/forums/thread/72120)
        context.addEllipse(in: CGRect(x: Int(tag.imagePoints.0-visualizationCirclesRadius), y: Int(tag.imagePoints.1-visualizationCirclesRadius), width: Int(visualizationCirclesRadius)*2, height: Int(visualizationCirclesRadius)*2))
        context.drawPath(using: .fillStroke)

        context.addEllipse(in: CGRect(x: Int(tag.imagePoints.2-visualizationCirclesRadius), y: Int(tag.imagePoints.3-visualizationCirclesRadius), width: Int(visualizationCirclesRadius)*2, height: Int(visualizationCirclesRadius)*2))
        context.drawPath(using: .fillStroke)

        context.addEllipse(in: CGRect(x: Int(tag.imagePoints.4-visualizationCirclesRadius), y: Int(tag.imagePoints.5-visualizationCirclesRadius), width: Int(visualizationCirclesRadius)*2, height: Int(visualizationCirclesRadius)*2))
        context.drawPath(using: .fillStroke)

        context.addEllipse(in: CGRect(x: Int(tag.imagePoints.6-visualizationCirclesRadius), y: Int(tag.imagePoints.7-visualizationCirclesRadius), width: Int(visualizationCirclesRadius)*2, height: Int(visualizationCirclesRadius)*2))
        context.drawPath(using: .fillStroke)
    }
    
    // Save the context as a new UIImage
    let myImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return myImage
}
