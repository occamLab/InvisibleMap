//
//  MapRecorder.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation
import ARKit
import Firebase
import FirebaseDatabase
import FirebaseStorage

class MapRecorder: MapRecorderController {
    
    var currentFrameTransform: simd_float4x4 = simd_float4x4.init()
    var lastRecordedTimestamp: Double?
    var poseId: Int = 0
    var poseData: [[Any]] = []
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.apriltagfinder", qos: DispatchQoS.userInitiated) // Allows you to asynchronously run a job on a background thread
    var tagData: [[Any]] = []
    var pendingLocation: (String, simd_float4x4)? // Keep track of any new locations
    var locationData: [[Any]] = []
    var pendingNode: (SCNNode, UIImage, SCNNode)? // Keep track of any new location nodes

    var processingFrame: Bool = false // Keep track of whether record data function is processing a frame
    
    var firebaseRef: DatabaseReference!
    var firebaseStorage: Storage!
    var firebaseStorageRef: StorageReference!
    
    func initFirebase() {
        FirebaseApp.configure()
        firebaseRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference()
        firebaseStorage = Storage.storage()
        firebaseStorageRef = firebaseStorage.reference()
    }
    
    init() {
        initFirebase()
    }
    
    func recordData(cameraFrame: ARFrame) {
        if lastRecordedTimestamp == nil {
            lastRecordedTimestamp = cameraFrame.timestamp
            poseId += 1
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            recordTags(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
        }
        else if lastRecordedTimestamp! + 0.5 < cameraFrame.timestamp && !processingFrame {
            processingFrame = true
            lastRecordedTimestamp = lastRecordedTimestamp! + 0.5
            poseId += 1
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            recordTags(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            if let pendingLocation = pendingLocation {
                locationData.append(getLocationCoordinates(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId, location: pendingLocation))
                AppController.shared.updateLocationListRequested(node: pendingNode!.0, picture: pendingNode!.1, textNode: pendingNode!.2, poseId: poseId)
                self.pendingLocation = nil
                self.pendingNode = nil
            }
            processingFrame = false
        }
        else {
            return
        }
    }
    
    /// Cache the location and node data so that it is recorded the next time recordData is called and matches up with the corresponding poseId
    func cacheLocation(node: SCNNode, picture: UIImage, textNode: SCNNode) {
        pendingLocation = (node.name!, node.simdTransform)
        pendingNode = (node, picture, textNode)
    }
    
    func displayLocationsUI() {
    }
    
    func saveMap(mapName: String) {
    }
    
    /// Clear timestamp, pose, tag, and location data
    func clearData() {
        lastRecordedTimestamp = nil
        poseId = 0
        poseData = []
        locationData = []
        tagData = []
        print("Clear data")
    }
    
    func saveMap() {
    }
    
}

extension MapRecorder { // recordData functions
    
    /// Append new pose data to list
    func recordPoseData(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
        poseData.append(getCameraCoordinates(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId))
    }
    
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
        /// Correct the orientation estimate such that the normal vector of the tag is perpendicular to gravity
        let snapTagsToVertical = true
        let f = imageToData()
        
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
                AppController.shared.processNewTag(tag: tagArray[i], cameraTransform: cameraFrame.camera.transform, snapTagsToVertical: snapTagsToVertical) // Generates event to detect new tag
                
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
        }
        return allTags
    }
    
    /// Get pose data (transformation matrix, time)
    func getCameraCoordinates(cameraFrame: ARFrame, timestamp: Double, poseId: Int) -> [Any] {
        let camera = cameraFrame.camera
        let cameraTransform = camera.transform
        currentFrameTransform = cameraTransform
        let scene = SCNMatrix4(cameraTransform)
        
        let fullMatrix: [Any] = [scene.m11, scene.m12, scene.m13, scene.m14, scene.m21, scene.m22, scene.m23, scene.m24, scene.m31, scene.m32, scene.m33, scene.m34, scene.m41, scene.m42, scene.m43, scene.m44, timestamp, poseId]
        
        return fullMatrix
    }
    
    /// Get location data
    func getLocationCoordinates(cameraFrame: ARFrame, timestamp: Double, poseId: Int, location: (String, simd_float4x4)) -> [Any] {
        let (locationName, nodeTransform) = location
        let finalTransform = currentFrameTransform.inverse * nodeTransform
        let fullMatrix: [Any] = [finalTransform.columns.0.x, finalTransform.columns.1.x, finalTransform.columns.2.x, finalTransform.columns.3.x, finalTransform.columns.0.y, finalTransform.columns.1.y, finalTransform.columns.2.y, finalTransform.columns.3.y, finalTransform.columns.0.z, finalTransform.columns.1.z, finalTransform.columns.2.z, finalTransform.columns.3.z, finalTransform.columns.0.w, finalTransform.columns.1.w, finalTransform.columns.2.w, finalTransform.columns.3.w, timestamp, poseId, locationName]
        
        return fullMatrix
    }
    
}
