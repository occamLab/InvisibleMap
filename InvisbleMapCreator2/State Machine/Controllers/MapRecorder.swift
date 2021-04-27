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

    
    var lastRecordedTimestamp: Double?
    var poseData: [[Any]] = []
    var locationData: [[Any]] = []
    var poseId: Int = 0
    
    var locations: [(simd_float4x4, Int)] = []
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
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            //recordLocationData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            AppController.shared.findTags(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
        }
        else if lastRecordedTimestamp! + 0.1 < cameraFrame.timestamp {
            lastRecordedTimestamp = lastRecordedTimestamp! + 0.1
            poseId += 1
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            //recordLocationData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            AppController.shared.findTags(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
        }
        else {
            return
        }
    }

    func addLocation(pose: simd_float4x4, poseId: Int, locationName: String) {
        locations.append((pose, poseId))
    }
    
    func displayLocationsUI() {
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
    
    @objc func recordPoseData(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
        poseData.append(getCameraCoordinates(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId))
    }
}

// record data
/*

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
