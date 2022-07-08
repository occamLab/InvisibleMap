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
    var map: Map! {
        didSet {
       //     print(map.waypointDictionary)
            objectWillChange.send()
        }
    }
    
    // endpoints are either tag locations or waypoint locations
    var locationType: String = "tag"
    
    // updates every time .StartPath command is called, depending on type of endpoint user selects (i.e. if tag is clicked endpointTagKey updates, if POI is clicked endpointLocation Id updates)
    var endpointTagKey: Int = -1
    var endpointWaypointKey: Int = -1
    
    // the April tag id of the most currently scanned/detected tag
    var currentTagId: Int32 = -1
    
    // the name of the waypoint that user is currently at (if they are at a waypoint)
    var currentWaypointName: String = "waypoint name"
    
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
    func planPath(from currentLocation: simd_float3) -> [RawMap.OdomVertex.vector3]? {
        if !self.map.firstTagFound {
            return nil
        }

        // end point for navigating to tag locations
        // searching for first instance of match between id and given endpointTagKey
        let tagLocation = self.map.rawData.tagVertices.first(where: {$0.id == self.endpointTagKey})!.translation
        
        // closest graph node from current location to endpoint
        var endpoint = self.map.getClosestGraphNode(to: simd_float3(tagLocation.x, tagLocation.y, tagLocation.z))!
        
        // end point for navigating to waypoints/POIs
        if locationType == "waypoint" {
            let waypointLocation = self.map.rawData.waypointsVertices.first(where: {$0.id == self.map.waypointDictionary[endpointWaypointKey]!.id})!.translation
            
            endpoint = self.map.getClosestGraphNode(to: simd_float3(waypointLocation.x, waypointLocation.y, waypointLocation.z))!
        }
        
        let startpoint = self.map.getClosestGraphNode(to: currentLocation, ignoring: endpoint)

        let (_, pathDict) = self.map.pathPlanningGraph!.dijkstra(root: String(startpoint!), startDistance: Float(0.0))
        print("startpoint:", startpoint!)
        print("endpoint:", endpoint)
        print("current location:", currentLocation)
      //  print("tag dictionary:", Array(self.map.tagDictionary.values))
     //   print("waypoint dictionary:", Array(self.map.waypointDictionary.values))
        // find path from startpoint to endpoint
        let path: [WeightedEdge<Float>] = pathDictToPath(from: self.map.pathPlanningGraph!.indexOfVertex(String(startpoint!))!, to: self.map.pathPlanningGraph!.indexOfVertex(String(endpoint))!, pathDict: pathDict)
        let stops = self.map.pathPlanningGraph!.edgesToVertices(edges: path)
        return stops.map({self.map.odometryDict![Int($0)!]!})
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
        /*    print("Tags found!")
            if let map = self.map {
                if !map.firstTagFound {
                    print("Starting path planning")
                    map.renderGraphPath()
                    map.firstTagFound = true
                }
            } */
            
            for child in InvisibleMapController.shared.arViewer!.detectionNode.childNodes {
                child.removeFromParentNode()
            }
            for i in 0...tagFinder.getNumberOfTags()-1 {
                let tag = tagFinder.getTagAt(i)
                self.currentTagId = tag.number
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
        // only continue if user chooses to detect tags
        if !detectTags {
            // don't allow camera to see tags if user did not start tag detection
            self.seesTag = false
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
        // process the frame in NavigateMap view if it's not doing that yet
        processingFrame = true
        
        aprilTagQueue.async {
            let arTags = self.checkTagDetection(image: uiImage,cameraIntrinsics: cameraFrame.camera.intrinsics, cameraTransform: cameraFrame.camera.transform)
            print("arTags array of detected tags: \(arTags)")
            DispatchQueue.main.async {
                // checks if tags were detected and assigns seesTag depending on that
                self.seesTag = !arTags.isEmpty
                print("seesTag: \(self.seesTag)")
                if let map = self.map {
                    if !map.firstTagFound && self.seesTag {
                        print("Starting path planning")
                        map.renderGraphPath()
                        map.firstTagFound = true
                        print("firstTagFound: \(map.firstTagFound)")
                    }
                    self.processingFrame = false
                }
            }
        }
    }
    
    // clears data for map
    func resetMap() {
        self.stopPathPlanning()
        self.map = nil  // this also resets firstTagFound var to false 
        self.detectTags = false
        self.seesTag = false
    }
}
