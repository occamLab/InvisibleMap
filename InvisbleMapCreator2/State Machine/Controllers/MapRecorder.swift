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

    var waypoints: [(simd_float4x4, Int)] = []
    
    func addTag(pose: simd_float4x4, tagId: Int) {
    }
    
    func addWaypoint(pose: simd_float4x4, poseId: Int, waypointName: String) {
        waypoints.append((pose, poseId))
    }
    
    func displayWaypointsUI() {
    }
    
    func saveMap(mapName: String) {
    }
    
    func recordData(cameraFrame: ARFrame) {
        if lastRecordedTimestamp == nil {
            lastRecordedTimestamp = cameraFrame.timestamp
        }
        else if lastRecordedTimestamp! + 0.1 < cameraFrame.timestamp {
            lastRecordedTimestamp = lastRecordedTimestamp! + 0.1
        }
    }

}
