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
    var poseId: Int = 0
    var locationData: [[Any]] = []
    var locations: [(simd_float4x4, Int)] = []
    var pendingLocation: (String, simd_float4x4)? // Keep track of whether location has been added

    var processingFrame: Bool = false
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
            AppController.shared.findTagsRequested(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
        }
        else if lastRecordedTimestamp! + 0.3 < cameraFrame.timestamp && !processingFrame {
            processingFrame = true
            lastRecordedTimestamp = lastRecordedTimestamp! + 0.3
            poseId += 1
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            if let pendingLocation = pendingLocation {
                locationData.append(getLocationCoordinates(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId, location: pendingLocation))
                self.pendingLocation = nil
            }
            AppController.shared.findTagsRequested(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            processingFrame = false
        }
        else {
            return
        }
    }
    
    /// Cache the location data so that it is recorded the next time recordData is called
    func recordLocation(locationName: String, node: simd_float4x4) {
        //let snapshot = self.sceneView.snapshot()
        //let tempLocationData = LocationData(node: currentBoxNode, picture: snapshot, textNode: currentTextNode, poseId: poseId)
        //nodeList.append(tempLocationData)
        
        pendingLocation = (locationName, node)
    }
    
    func displayLocationsUI() {
    }
    
    func saveMap(mapName: String) {
    }
    
    /// Clear timestamp, pose, and location data
    func clearData() {
        lastRecordedTimestamp = nil
        poseData = []
        poseId = 0
        locationData = []
        locations = []
        print("Clear data")
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
    
    /// Append new pose data to list
    func recordPoseData(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
        poseData.append(getCameraCoordinates(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId))
    }
    
    func getLocationCoordinates(cameraFrame: ARFrame, timestamp: Double, poseId: Int, location: (String, simd_float4x4)) -> [Any] {
        let (locationName, nodeTransform) = location
        let finalTransform = currentFrameTransform.inverse * nodeTransform
        let fullMatrix: [Any] = [finalTransform.columns.0.x, finalTransform.columns.1.x, finalTransform.columns.2.x, finalTransform.columns.3.x, finalTransform.columns.0.y, finalTransform.columns.1.y, finalTransform.columns.2.y, finalTransform.columns.3.y, finalTransform.columns.0.z, finalTransform.columns.1.z, finalTransform.columns.2.z, finalTransform.columns.3.z, finalTransform.columns.0.w, finalTransform.columns.1.w, finalTransform.columns.2.w, finalTransform.columns.3.w, timestamp, poseId, locationName]
        
        return fullMatrix
    }
    
}
