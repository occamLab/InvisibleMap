//
//  MapNavigator.swift
//  InvisibleMap2
//
//  Created by Allison Li and Ben Morris on 9/24/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit
import SwiftGraph

class MapNavigator: ObservableObject {
    @Published var map: Map?

    var locationType: String = "tag"
    // updates every time .StartPath command is called, depending on type of endpoint user selects (i.e. if tag is clicked endpointTagId updates, if POI is clicked endpointLocation Id updates)
    var endpointTagId: Int = 0
    var endpointLocationId: Int = 0
    let tagFinder = imageToData()
    
    /// Tracks whether the user has asked for a tag to be detected
    @Published var detectTags = false //changed true -> false - don't start detecting tags until user presses start detect tag button on navigate map view
    /// Tracks whether the tag was found after the user asked a tag to be detected
    @Published var seesTag = false
    
    var processingFrame = false
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.invisiblemap", qos: DispatchQoS.userInitiated)
    var pathPlanningTimer = Timer()
    
    /// Finds and visualizes path to the endpoint on a timer
    func scheduledPathPlanningTimer() {
        pathPlanningTimer.invalidate()
        //pathPlanningTimer = Timer()
        pathPlanningTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.sendPathPlanEvent), userInfo: nil, repeats: true)
    }
    
    func stopPathPlanning() {
        self.pathPlanningTimer.invalidate()
    }
    
    @objc func sendPathPlanEvent() {
        InvisibleMapController.shared.process(event: .PlanPath)
    }
    
    /// Plans a path from the current location to the end and visualizes it in red
    func planPath(from currentLocation: simd_float3) -> [RawMap.OdomVertex]? {
        let start = Date()
        guard let map = map else {
            return nil
        }
        if !map.firstTagFound {
            return nil
        }
        
        let endpoint: Int
        
        if locationType == "waypoint" {
            // end point for navigating to waypoints/POIs
            let waypointLocation = map.rawData.waypointsVertices.first(where: {$0.id == map.waypointDictionary[self.endpointLocationId]!.id})!.translation
            
            endpoint = map.getClosestGraphNode(to: simd_float3(waypointLocation.x, waypointLocation.y, waypointLocation.z))!
        } else {
            // end point for navigating to tag locations
            // searching for first instance of match between id and given endpointTagId
            let tagLocation = map.rawData.tagVertices.first(where: {$0.id == self.endpointTagId})!.translation
            
            endpoint = map.getClosestGraphNode(to: simd_float3(tagLocation.x, tagLocation.y, tagLocation.z))!
        }
        print("currentLocation \(currentLocation)")
        let startpoint = map.getClosestGraphNode(to: currentLocation, ignoring: endpoint)

        let (_, pathDict) = map.pathPlanningGraph!.dijkstra(root: String(startpoint!), startDistance: Float(0.0))
        //print("startpoint:", startpoint!)
        print("startpoint:", startpoint)
        print("endpoint:", endpoint)
        // find path from startpoint to endpointß
        let path: [WeightedEdge<Float>] = pathDictToPath(from: map.pathPlanningGraph!.indexOfVertex(String(startpoint!))!, to: map.pathPlanningGraph!.indexOfVertex(String(endpoint))!, pathDict: pathDict)
        let stops = map.pathPlanningGraph!.edgesToVertices(edges: path)
        print("Time to path plan \(-start.timeIntervalSinceNow)")
        return stops.map({map.odometryDict![Int($0)!]!})
    }
    
    /// Check if tag is detected and update the tag and map transforms
    ///
    /// - Parameters:
    ///   - rotatedImage: the camera frame rotated by 90 degrees to enable accurate tag detection
    ///   - timestamp: the timestamp of the current frame
    func checkTagDetection(image: UIImage, cameraIntrinsics: simd_float3x3, cameraTransform: simd_float4x4)->Array<AprilTags> {
        let intrinsics = cameraIntrinsics.columns
        tagFinder.findTags(image, intrinsics.0.x, intrinsics.1.y, intrinsics.2.x, intrinsics.2.y)
        var tagArray: Array<AprilTags> = Array()
        let numTags = tagFinder.getNumberOfTags()
        if numTags > 0 {
            print("Tags found!")
            DispatchQueue.main.async {
                self.seesTag = true
            }
            if let map = self.map {
                if !map.firstTagFound {
                    print("Starting path planning")
                    map.renderGraphPath()
                    map.firstTagFound = true
                }
            }
            
            for child in InvisibleMapController.shared.arViewer!.detectionNode.childNodes {
                child.removeFromParentNode()
            }
            for i in 0...tagFinder.getNumberOfTags()-1 {
                let tag = tagFinder.getTagAt(i)
                tagArray.append(tag)
                if let map = self.map {
                    if let _ = map.tagDictionary[Int(tag.number)] {
                        InvisibleMapController.shared.process(event: .TagFound(tag: tagArray[tagArray.count-1], cameraTransform: cameraTransform))
                        InvisibleMapController.shared.arViewer?.detectTag(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: map.snapTagsToVertical)
                    }
                }
            }
        }
        return tagArray;
    }
    
    /// Processes the pose, april tags, and nearby waypoints.
    func updateTags(from cameraFrame: ARFrame) {
        if !detectTags {
            return
        }
        print("Update Tags")
        // Convert ARFrame to a UIImage
        let pixelBuffer = cameraFrame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let uiImage = UIImage(cgImage: cgImage!)
        
        if processingFrame {
            return
        }
        processingFrame = true
        aprilTagQueue.async {
            let _ = self.checkTagDetection(image: uiImage,cameraIntrinsics: cameraFrame.camera.intrinsics, cameraTransform: cameraFrame.camera.transform)
            self.processingFrame = false
        }
    }
    
    func resetMap() {
        self.stopPathPlanning()
        self.map = nil
        self.detectTags = false
        self.seesTag = false
    }
}
