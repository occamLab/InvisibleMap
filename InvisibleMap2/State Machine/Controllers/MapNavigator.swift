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

class MapNavigator {
    var map: Map!
    var endpointTagId: Int = 0
    let tagFinder = imageToData()
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
    func planPath(from currentLocation: simd_float3) -> [String]? {
        if !self.map.firstTagFound {
            return nil
        }

        let tagLocation = self.map.rawData.tagVertices.first(where: {$0.id == self.endpointTagId})!.translation
        
        let endpoint = self.map.getClosestGraphNode(to: simd_float3(tagLocation.x, tagLocation.y, tagLocation.z))!
        let startpoint = self.map.getClosestGraphNode(to: currentLocation, ignoring: endpoint)

        let (_, pathDict) = self.map.pathPlanningGraph!.dijkstra(root: String(startpoint!), startDistance: Float(0.0))
        print("startpoint:", startpoint!)
        print("endpoint:", endpoint)
        // find path from startpoint to endpointß
        let path: [WeightedEdge<Float>] = pathDictToPath(from: self.map.pathPlanningGraph!.indexOfVertex(String(startpoint!))!, to: self.map.pathPlanningGraph!.indexOfVertex(String(endpoint))!, pathDict: pathDict)
        return self.map.pathPlanningGraph!.edgesToVertices(edges: path)
    }
    
    /// Check if tag is detected and update the tag and map transforms
    ///
    /// - Parameters:
    ///   - rotatedImage: the camera frame rotated by 90 degrees to enable accurate tag detection
    ///   - timestamp: the timestamp of the current frame
    func checkTagDetection(image: UIImage, cameraIntrinsics: simd_float3x3)->Array<AprilTags> {
        let intrinsics = cameraIntrinsics.columns
        tagFinder.findTags(image, intrinsics.0.x, intrinsics.1.y, intrinsics.2.x, intrinsics.2.y)
        var tagArray: Array<AprilTags> = Array()
        let numTags = tagFinder.getNumberOfTags()
        if numTags > 0 {
            if !self.map.firstTagFound {
                print("Starting path planning")
                self.map.renderGraphPath()
                self.map.firstTagFound = true
            }
            
            for i in 0...tagFinder.getNumberOfTags()-1 {
                tagArray.append(tagFinder.getTagAt(i))
            }
        }
        return tagArray;
    }
    
    /// Processes the pose, april tags, and nearby waypoints.
    func updateTags(from cameraFrame: ARFrame) {
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
            let _ = self.checkTagDetection(image: uiImage, cameraIntrinsics: cameraFrame.camera.intrinsics)
            self.processingFrame = false
        }
    }
    
    func resetMap() {
        self.stopPathPlanning()
        self.map = nil
    }
}
