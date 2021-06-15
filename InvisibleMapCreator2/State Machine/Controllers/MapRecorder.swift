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
    /// Tracks last recorded frame to set map image to
    var lastRecordedFrame: ARFrame?
    /// Timestamp of frame that was last recorded
    var lastRecordedTimestamp: Double?
    /// Time interval at which pose, tag, location, and node data is recorded
    let recordInterval = 0.5
    /// Allows you to asynchronously run a job on a background thread
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.apriltagfinder", qos: DispatchQoS.userInitiated)
    var poseId: Int = 0
    var poseData: [[String: Any]] = []
    var tagData: [[[String: Any]]] = []
    var locationData: [[String: Any]] = []
    
    /// Tracks whether record data function is processing a frame to prevent queue from being overfilled
    var processingFrame: Bool = false
    /// Tracks any new locations
    var pendingLocation: (String, simd_float4x4)?
    /// Tracks any new location nodes
    var pendingNode: (SCNNode, UIImage, SCNNode)?
    
    /// Correct the orientation estimate such that the normal vector of the tag is perpendicular to gravity
    let snapTagsToVertical = true
    
    let f = imageToData()
    
    var firebaseRef: DatabaseReference!
    var firebaseStorage: Storage!
    var firebaseStorageRef: StorageReference!
    
    func initFirebase() {
        firebaseRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference()
        firebaseStorage = Storage.storage()
        firebaseStorageRef = firebaseStorage.reference()
    }
    
    init() {
        initFirebase()
    }
    
    /// Record pose, tag, location, and node data after a specified period of time
    func recordData(cameraFrame: ARFrame) {
        if lastRecordedTimestamp == nil {
            lastRecordedTimestamp = cameraFrame.timestamp
            lastRecordedFrame = cameraFrame
            poseId += 1
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            recordTags(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            print("Running \(poseId)")
        }
        // Only record data if a specific period of time has passed and if a frame is not already being processed
        else if lastRecordedTimestamp! + recordInterval < cameraFrame.timestamp && !processingFrame {
            processingFrame = true
            lastRecordedTimestamp = lastRecordedTimestamp! + recordInterval
            lastRecordedFrame = cameraFrame
            poseId += 1
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            recordTags(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            if let pendingLocation = pendingLocation {
                locationData.append(getLocationCoordinates(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId, location: pendingLocation))
                AppController.shared.updateLocationListRequested(node: pendingNode!.0, picture: pendingNode!.1, textNode: pendingNode!.2, poseId: poseId)
                self.pendingLocation = nil
                self.pendingNode = nil
            }
            print("Running \(poseId)")
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

    /// Upload pose data, last image frame to Firebase under "maps" and "unprocessed_maps" nodes
    func sendToFirebase(mapName: String) {
        let mapImage = convertToUIImage(cameraFrame: lastRecordedFrame!)
        let mapId = String(lastRecordedTimestamp!).replacingOccurrences(of: ".", with: "") + mapName
        let mapJsonFile: [String: Any] = ["map_id": mapId, "pose_data": poseData, "tag_data": tagData, "location_data": locationData]
        
        let imagePath = "myTestFolder/" + mapId + ".jpg"
        let filePath = "myTestFolder/" + mapId + ".json"
        
        // TODO: handle errors when failing to upload image and json file
        // TODO: let the user pick their image
        // Upload the last image capture to Firebase
        firebaseStorageRef.child(imagePath).putData(mapImage.jpegData(compressionQuality: 0)!, metadata: StorageMetadata(dictionary: ["contentType": "image/jpeg"]))

        // Upload raw file json
        if let jsonData = try? JSONSerialization.data(withJSONObject: mapJsonFile, options: []) {
            firebaseStorageRef.child(filePath).putData(jsonData, metadata: StorageMetadata(dictionary: ["contentType": "application/json"])){ (metadata, error) in
                // Write to maps node in database
                self.firebaseRef.child("maps").child(mapId).setValue(["name": mapName, "image": imagePath, "raw_file": filePath])
                
                // Write to unprocessed maps node in database
                self.firebaseRef.child("unprocessed_maps").child(mapId).setValue(filePath)
            }
        }
    }
    
    /// Clear timestamp, pose, tag, and location data
    func clearData() {
        lastRecordedTimestamp = nil
        lastRecordedFrame = nil
        poseId = 0
        poseData = []
        locationData = []
        tagData = []
        print("Clear data")
    }
}

// Helper functions that are not explicitly commands
extension MapRecorder {
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
    func getCameraCoordinates(cameraFrame: ARFrame, timestamp: Double, poseId: Int) -> [String: Any] {
        let camera = cameraFrame.camera
        let cameraTransform = camera.transform
        currentFrameTransform = cameraTransform
        let scene = SCNMatrix4(cameraTransform)
        
        let cameraInfo: [String: Any] = ["matrix": [scene.m11, scene.m12, scene.m13, scene.m14, scene.m21, scene.m22, scene.m23, scene.m24, scene.m31, scene.m32, scene.m33, scene.m34, scene.m41, scene.m42, scene.m43, scene.m44], "timestamp": timestamp, "poseId": poseId]
        
        return cameraInfo
    }
    
    /// Get location data
    func getLocationCoordinates(cameraFrame: ARFrame, timestamp: Double, poseId: Int, location: (String, simd_float4x4)) -> [String: Any] {
        let (locationName, nodeTransform) = location
        let finalTransform = currentFrameTransform.inverse * nodeTransform
        let locationInfo: [String: Any] = ["matrix": [finalTransform.columns.0.x, finalTransform.columns.1.x, finalTransform.columns.2.x, finalTransform.columns.3.x, finalTransform.columns.0.y, finalTransform.columns.1.y, finalTransform.columns.2.y, finalTransform.columns.3.y, finalTransform.columns.0.z, finalTransform.columns.1.z, finalTransform.columns.2.z, finalTransform.columns.3.z, finalTransform.columns.0.w, finalTransform.columns.1.w, finalTransform.columns.2.w, finalTransform.columns.3.w], "timestamp": timestamp, "poseId": poseId, "name": locationName]
        
        return locationInfo
    }
    
    /// Convert ARFrame to a UIImage
    func convertToUIImage(cameraFrame: ARFrame) -> (UIImage) {
        let pixelBuffer = cameraFrame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let uiImage = UIImage(cgImage: cgImage!)
        return uiImage
    }
}
