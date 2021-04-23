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

    /// Correct the orientation estimate such that the normal vector of the tag is perpendicular to gravity
    let snapTagsToVertical = true
    let f = imageToData()
    
    var lastRecordedTimestamp: Double?
    var tagData:[[Any]] = []
    var poseData:[[Any]] = []
    var locationData:[[Any]] = []
    var poseId: Int = 0
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.apriltagfinder", qos: DispatchQoS.userInitiated) //Allows you to asynchronously run a job on a background thread
    var aprilTagDetectionDictionary = Dictionary<Int, AprilTagTracker>()
    
    var waypoints: [(simd_float4x4, Int)] = []
    
    var currentFrameTransform: simd_float4x4 = simd_float4x4.init()

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
        print("Firebase initialized")
    }
    
    func recordData(cameraFrame: ARFrame) {
        if lastRecordedTimestamp == nil {
            lastRecordedTimestamp = cameraFrame.timestamp
            poseId += 1
            
            
        }
        else if lastRecordedTimestamp! + 0.1 < cameraFrame.timestamp {
            lastRecordedTimestamp = lastRecordedTimestamp! + 0.1
            poseId += 1
            
            poseData.append(getCameraCoordinates(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)) //Append new pose data to list
        }
    }
    
    func detectTagFound(tag: AprilTags, cameraTransform: simd_float4x4) {
    }

    func addWaypoint(pose: simd_float4x4, poseId: Int, waypointName: String) {
        waypoints.append((pose, poseId))
    }
    
    func displayWaypointsUI() {
    }
    
    func saveMap(mapName: String) {
    }
    
    func cancelMap() {
    }
    
    func saveMap() {
    }
    
}

extension MapRecorder { // recordData functions
    
    /// Get pose data (transformation matrix, time)
    func getCameraCoordinates(cameraFrame: ARFrame, timestamp: Double, poseId: Int) -> [Any] {
        let camera = cameraFrame.camera
        let cameraTransform = camera.transform
        currentFrameTransform = cameraTransform
        let scene = SCNMatrix4(cameraTransform)
        
        let fullMatrix: [Any] = [scene.m11, scene.m12, scene.m13, scene.m14, scene.m21, scene.m22, scene.m23, scene.m24, scene.m31, scene.m32, scene.m33, scene.m34, scene.m41, scene.m42, scene.m43, scene.m44, timestamp, poseId]
        
        return fullMatrix
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
                AppController.shared.processNewTag(tag: tagArray[i], cameraTransform: cameraFrame.camera.transform) // Generates event to detected tag
                
                //addTagDetectionNode(sceneView: sceneView, snapTagsToVertical: snapTagsToVertical, doKalman: false, aprilTagDetectionDictionary: &aprilTagDetectionDictionary, tag: tagArray[i], cameraTransform: cameraFrame.camera.transform)

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
}


// record data
/*@objc func recordData() {
        recordPoseData(cameraFrame: cameraFrame!, timestamp: timestamp!, poseId: poseId)
        recordTags(cameraFrame: cameraFrame!, timestamp: timestamp!, poseId: poseId)
        recordLocationData(cameraFrame: cameraFrame!, timestamp: timestamp!, poseId: poseId)
        poseNumber.text = "Pose #: \(poseId)"
        poseId += 1


@objc func recordLocationData(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
    if recordCurrentLocation == true {
        let snapshot = self.sceneView.snapshot()
        let tempLocationData = LocationData(node: currentBoxNode, picture: snapshot, textNode: currentTextNode, poseId: poseId)
        nodeList.append(tempLocationData)
        locationData.append(getLocationCoordinates(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId))
        recordCurrentLocation = false
        currentTextNode = SCNNode()
        currentBoxNode = SCNNode()
    }
}*/
