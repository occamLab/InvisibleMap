//
//  MapRecorder.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation
import ARKit

class MapRecorder: MapRecorderController {

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
    
    func recordPoseData(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
    }
    
    func recordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
    }
    
    func recordLocationData(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
    }
    
}
