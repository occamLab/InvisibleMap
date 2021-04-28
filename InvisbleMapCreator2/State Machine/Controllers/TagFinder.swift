//
//  TagFinder.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/27/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit

class TagFinder: TagFinderController {
        
    /// Correct the orientation estimate such that the normal vector of the tag is perpendicular to gravity
    let snapTagsToVertical = true
    let f = imageToData()
    
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.apriltagfinder", qos: DispatchQoS.userInitiated) //Allows you to asynchronously run a job on a background thread
    var tagData: [[Any]] = []
    
    /// Append new april tag data to list
    @objc func recordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
        let uiimage = cameraFrame.convertToUIImage()
        aprilTagQueue.async {
            let arTags = self.getArTags(cameraFrame: cameraFrame, image: uiimage, timeStamp: timestamp, poseId: poseId)
            if !arTags.isEmpty {
                self.tagData.append(arTags)
            }
        }
    }
    
    /// Finds all april tags in the frame
    func getArTags(cameraFrame: ARFrame, image: UIImage, timeStamp: Double, poseId: Int) -> [[String:Any]] {
        let intrinsics = cameraFrame.camera.intrinsics.columns
        f.findTags(image, intrinsics.0.x, intrinsics.1.y, intrinsics.2.x, intrinsics.2.y)
        var tagArray: Array<AprilTags> = Array()
        var allTags: [[String:Any]] = []
        let numTags = f.getNumberOfTags()
        if numTags > 0 {
            for i in 0...f.getNumberOfTags()-1 {
                tagArray.append(f.getTagAt(i))
            }

            for i in 0...tagArray.count-1 {
                AppController.shared.processNewTag(tag: tagArray[i], cameraTransform: cameraFrame.camera.transform) // Generates event to transform tag
                
                var tagDict:[String:Any] = [:]
                var pose = tagArray[i].poseData

                if snapTagsToVertical {
                    var simdPose = simd_float4x4(rows: [float4(Float(pose.0), Float(pose.1), Float(pose.2),Float(pose.3)), float4(Float(pose.4), Float(pose.5), Float(pose.6), Float(pose.7)), float4(Float(pose.8), Float(pose.9), Float(pose.10), Float(pose.11)), float4(Float(pose.12), Float(pose.13), Float(pose.14), Float(pose.15))])
                    // convert from April Tags conventions to Apple's (TODO: could this be done in one rotation?)
                    simdPose = simdPose.rotate(radians: Float.pi, 0, 1, 0)
                    simdPose = simdPose.rotate(radians: Float.pi, 0, 0, 1)
                    let worldPose = cameraFrame.camera.transform*simdPose
                    // TODO: the alignY() seems to break things, possibly because we aren't properly remapping the covariance matrices.  I made an attempt to try to do this using LASwift, but ran into issues with conflicts with VISP3
                    let worldPoseFlat = worldPose.makeZFlat()//.alignY()
                    // back calculate what the camera pose should be so that the pose in the global frame is flat
                    var correctedCameraPose = cameraFrame.camera.transform.inverse*worldPoseFlat
                    // go back to April Tag Conventions
                    correctedCameraPose = correctedCameraPose.rotate(radians: Float.pi, 0, 0, 1)
                    correctedCameraPose = correctedCameraPose.rotate(radians: Float.pi, 0, 1, 0)
                    pose = correctedCameraPose.toRowMajorOrder()
                }
                tagDict["tagId"] = tagArray[i].number
                tagDict["tagPose"] = [pose.0, pose.1, pose.2, pose.3, pose.4, pose.5, pose.6, pose.7, pose.8, pose.9, pose.10, pose.11, pose.12, pose.13, pose.14, pose.15]
                tagDict["cameraIntrinsics"] = [intrinsics.0.x, intrinsics.1.y, intrinsics.2.x, intrinsics.2.y]
                tagDict["tagCornersPixelCoordinates"] = [tagArray[i].imagePoints.0, tagArray[i].imagePoints.1, tagArray[i].imagePoints.2, tagArray[i].imagePoints.3, tagArray[i].imagePoints.4, tagArray[i].imagePoints.5, tagArray[i].imagePoints.6, tagArray[i].imagePoints.7]
                tagDict["tagPositionVariance"] = [tagArray[i].transVecVar.0, tagArray[i].transVecVar.1, tagArray[i].transVecVar.2]
                tagDict["tagOrientationVariance"] = [tagArray[i].quatVar.0, tagArray[i].quatVar.1, tagArray[i].quatVar.2, tagArray[i].quatVar.3]
                tagDict["timeStamp"] = timeStamp
                tagDict["poseId"] = poseId
                // TODO: resolve the unsafe dangling pointer warning
                tagDict["jointCovar"] = [Double](UnsafeBufferPointer(start: &tagArray[i].jointCovar.0, count: MemoryLayout.size(ofValue: tagArray[i].jointCovar)/MemoryLayout.stride(ofValue: tagArray[i].jointCovar.0)))
                allTags.append(tagDict)
            }
            // TODO: Enable add location button after first tag is found
            /*DispatchQueue.main.async {
                if self.foundTag == false {
                    self.foundTag = true
                    self.moveToButton.setTitleColor(.blue, for: .normal)
                    self.explainLabel.text = "Tag Found! Now you can save location"
                }
            }*/
            
        }
        return allTags
    }
    
    func transformTag(tag: AprilTags, cameraTransform: simd_float4x4) {
                
        let pose = tag.poseData
        let transVar = simd_float3(Float(tag.transVecVar.0), Float(tag.transVecVar.1), Float(tag.transVecVar.2))
        let quatVar = simd_float4(x: Float(tag.quatVar.0), y: Float(tag.quatVar.1), z: Float(tag.quatVar.2), w: Float(tag.quatVar.3))

        let originalTagPose = simd_float4x4(rows: [float4(Float(pose.0), Float(pose.1), Float(pose.2),Float(pose.3)), float4(Float(pose.4), Float(pose.5), Float(pose.6), Float(pose.7)), float4(Float(pose.8), Float(pose.9), Float(pose.10), Float(pose.11)), float4(Float(pose.12), Float(pose.13), Float(pose.14), Float(pose.15))])

        let aprilTagToARKit = simd_float4x4(diagonal:simd_float4(1, -1, -1, 1))
        // convert from April Tag's convention to ARKit's convention
        let tagPoseARKit = aprilTagToARKit*originalTagPose
        // project into world coordinates
        var scenePose = cameraTransform*tagPoseARKit

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
        let sceneVar = (sceneTransVar: sceneTransVar, sceneQuatVar: sceneQuatVar, scenePoseQuat: scenePoseQuat, scenePoseTranslation: scenePoseTranslation)
        
        AppController.shared.detectTagRequested(tag: tag, cameraTransform: cameraTransform, sceneVar: sceneVar) // Generates event to detect tag in AR view
    }
}
