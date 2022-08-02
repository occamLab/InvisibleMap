//
//  ViewController.swift
//  InvisibleMap
//
//  Created by djconnolly on 7/30/18.
//  Copyright © 2018 Occam Lab. All rights reserved.
//

import UIKit
import ARKit
import GLKit
import AVFoundation
import AudioToolbox
import MediaPlayer
import Firebase
import FirebaseDatabase
import FirebaseStorage
import SwiftGraph
import SwiftUI

// TODO: can probably just do 1d Kalman filtering for angle
// TODO: if we use ARPlaneAnchor instead of the raw depth data, will that lead to better plane detection accuracy?  This doesn't seem to be the case when we tried to use the depth data directly (also note that we were not using the smoothed depth data)

/// The view controller for displaying a map and announcing waypoints
class ViewController: UIViewController {
    
    //MARK: Properties
    var storageRef: StorageReference!
    var myMap: Map!
    var mapNode: SCNNode!
    var cameraNode: SCNNode!
    var aprilTagDetectionDictionary = Dictionary<Int, AprilTagTracker>()
    var tagDictionary = [Int:ViewController.Map.Vertex]()
    var waypointDictionary = [Int:ViewController.Map.WaypointVertex]()
    var waypointKeyDictionary = [String:Int]()
    let distanceToWaypoint: Float = 1.5
    let tagTiltMin: Float = 0.09
    let tagTiltMax: Float = 0.91
    var mapFileName: String = ""
    var endpointTagKey: Int = 0
    /// We use the knowledge that the z-axis of the tag should be perpendicular to gravity to adjust the tag detection
    var snapTagsToVertical = true
    
    @IBOutlet var sceneView: ARSCNView!
    var tagFinderTimer = Timer()
    var firstTagFound = false
    
    /// Speech synthesis objects (reuse these or memory will leak)
    let synth = AVSpeechSynthesizer()
    let voice = AVSpeechSynthesisVoice(language: "en-US")
    var lastSpeechTime : [Int:Date] = [:]
    
    // audio and haptic feedback
    var audioPlayers: [String: AVAudioPlayer?] = [:]
    var pingTimer = Timer()
    var hapticGenerator : UIImpactFeedbackGenerator?

    let f = imageToData()
    var isProcessingFrame = false
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.invisiblemap", qos: DispatchQoS.userInitiated)
    
    var pathPlanningGraph: WeightedGraph<String, Float>?
    // odometryDict stores a list of nodes by poseID to their xyz data
    var odometryDict: Dictionary<Int, ViewController.Map.OdomVertex.vector3>?
    var pathObjs: [SCNNode] = []
    // runs path planning and visualizations on a timer
    var pathPlanningTimer = Timer()
    
    override func viewWillAppear(_ animated: Bool) {
        startSession()
        setupPing()
        createMap()
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
        self.sceneView.session.pause()
        self.tagFinderTimer.invalidate()
        self.stopPathPlanning()
        self.firstTagFound = false
    }
    
    func stopPathPlanning() {
        self.pathPlanningTimer.invalidate()
        self.pingTimer.invalidate()
    }
    
    /// Initializes the map node, of which all of the tags and waypoints downloaded from firebase are children
    func createMapNode() {
        mapNode = SCNNode()
        mapNode.position = SCNVector3(x: 0, y: 0, z: 0)
        sceneView.scene.rootNode.addChildNode(mapNode)
    }
    
    /// Initialize the ARSession
    func startSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // Setup audio elements
      func setupPing() {
        do {
            try self.audioPlayers["startNav"] = AVAudioPlayer(contentsOf: URL(fileURLWithPath: "/System/Library/Audio/UISounds/tweet_sent.caf"))
            try self.audioPlayers["arrived"] = AVAudioPlayer(contentsOf: URL(fileURLWithPath: "/System/Library/Audio/UISounds/New/Fanfare.caf"))
            try self.audioPlayers["ping"] = AVAudioPlayer(contentsOf: URL(fileURLWithPath: "/System/Library/Audio/UISounds/Tock.caf"))
            self.hapticGenerator = UIImpactFeedbackGenerator(style: .light)
            self.hapticGenerator!.prepare()
            for p in self.audioPlayers.values {
                p!.prepareToPlay()
            }
            self.scheduledPingTimer()
        }
        catch let audioError {
          print("Could not setup audio: \(audioError)")
        }
      }

    
    /// Downloads the selected map from firebase
    func createMap() {
        print("creating map \(mapFileName)")
        createMapNode()
        let storage = Storage.storage()
        storageRef = storage.reference()
        let mapRef = storageRef.child(mapFileName)
        mapRef.getData(maxSize: 10 * 1024 * 1024) { mapData, error in
            if let error = error {
                print(error.localizedDescription)
                // Error occurred
            } else {
                if mapData != nil {
                    do {
                        self.myMap =  try JSONDecoder().decode(Map.self, from: mapData!)
                        self.storeTagsInDictionary()
                        self.storeWaypointsInDictionary()
                        self.scheduledPathPlanningTimer()
                    } catch let error {
                        print(error)
                    }
                }
            }
        }
    }
    
    
    /// Stores the waypoints from firebase in a dictionary to speed up lookup of nearby waypoints
    func storeWaypointsInDictionary(){
        var count: Int = 0
        for vertex in myMap.waypointsVertices{
            waypointDictionary[count] = vertex
            waypointKeyDictionary[vertex.id] = count
            let waypointMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
            let waypointNode = SCNNode(geometry: SCNBox(width: 0.25, height: 0.25, length: 0.25, chamferRadius: 0))
            waypointNode.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            waypointNode.transform = waypointMatrix
            mapNode.addChildNode(waypointNode)
            let objectText = SCNText(string: vertex.id, extrusionDepth: 1.0)
            objectText.font = UIFont (name: "Arial", size: 48)
            objectText.firstMaterial!.diffuse.contents = UIColor.red
            let textNode = SCNNode(geometry: objectText)
            textNode.position = SCNVector3(x: 0.0, y: 0.15, z: 0.0)
            textNode.scale = SCNVector3(x: 0.002, y: 0.002, z: 0.002)
            waypointNode.addChildNode(textNode)
            waypointNode.name = String("Waypoint_\(vertex.id)")
            count = count + 1
        }
    }
    
    /// Creates a node for a path edge between two vertices
    func renderEdge(from firstVertex: Map.OdomVertex.vector3, to secondVertex: Map.OdomVertex.vector3, isPath: Bool) {
        var pathObj: SCNNode?
        let verticalOffset: Float = -0.6
        
        let x = (secondVertex.x + firstVertex.x) / 2
        let y = (secondVertex.y + firstVertex.y) / 2
        let z = (secondVertex.z + firstVertex.z) / 2
        let xDist = secondVertex.x - firstVertex.x
        let yDist = secondVertex.y - firstVertex.y
        let zDist = secondVertex.z - firstVertex.z
        let dist = sqrt(pow(xDist, 2) + pow(yDist, 2) + pow(zDist, 2))

        /// SCNNode of the bar path
        pathObj = SCNNode(geometry: SCNBox(width: CGFloat(dist), height: 0.06, length: 0.06, chamferRadius: 1))
        pathObjs.append(pathObj!)

        //configure node attributes
        if !isPath {
            let odometryNode = SCNNode(geometry: SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0))
            odometryNode.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            odometryNode.simdPosition = simd_float3(firstVertex.x, firstVertex.y + verticalOffset, firstVertex.z)
            mapNode.addChildNode(odometryNode)
            
            pathObj!.geometry?.firstMaterial!.diffuse.contents = UIColor.yellow
            pathObj!.opacity = CGFloat(1)
        } else {
            pathObj!.geometry?.firstMaterial!.diffuse.contents = UIColor.red
            pathObj!.opacity = CGFloat(1)
        }
        
        let xAxis = simd_normalize(simd_float3(xDist, yDist, zDist))
        let yAxis: simd_float3
        if xDist == 0 && zDist == 0 {
            // this is the case where the path goes straight up and we can set yAxis more or less arbitrarily
            yAxis = simd_float3(1, 0, 0)
        } else if xDist == 0 {
            // zDist must be non-zero, which means that for yAxis to be perpendicular to the xAxis and have a zero y-component, we must make yAxis equal to simd_float3(1, 0, 0)
            yAxis = simd_float3(1, 0, 0)
        } else if zDist == 0 {
            // xDist must be non-zero, which means that for yAxis to be perpendicular to the xAxis and have a zero y-component, we must make yAxis equal to simd_float3(0, 0, 1)
            yAxis = simd_float3(0, 0, 1)
        } else {
            // TODO: real math
            let yAxisZComponent = sqrt(1 / (zDist*zDist/(xDist*xDist) + 1))
            let yAxisXComponent = -zDist*yAxisZComponent/xDist
            yAxis = simd_float3(yAxisXComponent, 0, yAxisZComponent)
        }
        let zAxis = simd_cross(xAxis, yAxis)
        let pathTransform = simd_float4x4(columns: (simd_float4(xAxis, 0), simd_float4(yAxis, 0), simd_float4(zAxis, 0), simd_float4(x, y + verticalOffset, z, 1)))

        pathObj!.simdTransform = pathTransform
        
        if isPath {
            mapNode.addChildNode(pathObj!)
        }
    }
    
    /// Renders graph used for path planning and initializes dictionary and graph used
    func renderGraphPath(){
        // Initializes dictionary and graph
        odometryDict = Dictionary<Int, ViewController.Map.OdomVertex.vector3>(uniqueKeysWithValues: zip(myMap.odometryVertices.map({$0.poseId}), myMap.odometryVertices.map({$0.translation})))
        pathPlanningGraph = WeightedGraph<String, Float>(vertices: Array(odometryDict!.keys).sorted().map({String($0)}))

        for vertex in myMap.odometryVertices {
            for neighbor in vertex.neighbors{
                // Only render path if it hasn't been rendered yet
                if (neighbor < vertex.poseId){
                    let neighborVertex = odometryDict![neighbor]!
                    
                    let vertexVec = simd_float3(vertex.translation.x, vertex.translation.y, vertex.translation.z)
                    let neighborVertexVec = simd_float3(neighborVertex.x, neighborVertex.y, neighborVertex.z)
                    let total_dist = simd_distance(vertexVec, neighborVertexVec)
        
                    // Adding edge from vertex to neighbor
                    pathPlanningGraph!.addEdge(from: String(vertex.poseId), to:String(neighbor), weight:total_dist)
                    // Render edge
                    self.renderEdge(from: vertex.translation, to: neighborVertex, isPath: false)
                }
            }
        }
    }
    
    
    
    /// Gets the poseID of the node closest to the current camera position that is not the desired endpoint
    func getClosestGraphNode(to location: simd_float3? = nil, ignoring endpoint: Int? = nil) -> Int?{
        var coordinates = location
        // get user's phone location
        if coordinates == nil {
            let (_, _, cameraTransform, _) = self.getVideoFrames()
            guard let cameraTransform = cameraTransform else {
                return nil
            }
            coordinates = simd_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        }
        
        // get node closest to the current camera position
        var closestNode: Int = 0
        var minDist = 100000.0
        for node in odometryDict!{
            let nodeVec = simd_float3(node.value.x, node.value.y, node.value.z)
            let dist = simd_distance(nodeVec, coordinates!)
            
            if (Double)(dist) < minDist && (endpoint == nil || node.key != endpoint) {
                minDist = (Double)(dist)
                closestNode = node.key
            }
        }
        return closestNode
    }
    
    
    // Plans a path from the current location to the end and visualizes it in red
    @objc func pathPlanning(){
        if !self.firstTagFound {
            return
        }
        
        print("path planning!")

        let tagLocation = myMap.tagVertices.first(where: {$0.id == self.endpointTagKey})!.translation
        
        let endpoint = getClosestGraphNode(to: simd_float3(tagLocation.x, tagLocation.y, tagLocation.z))!
        let startpoint = getClosestGraphNode(ignoring: endpoint)

        let (_, pathDict) = pathPlanningGraph!.dijkstra(root: String(startpoint!), startDistance: Float(0.0))
        print("startpoint:", startpoint!)
        print("endpoint:", endpoint)
        // find path from startpoint to endpointß
        let path: [WeightedEdge<Float>] = pathDictToPath(from: pathPlanningGraph!.indexOfVertex(String(startpoint!))!, to: pathPlanningGraph!.indexOfVertex(String(endpoint))!, pathDict: pathDict)
        let stops: [String] = pathPlanningGraph!.edgesToVertices(edges: path)
        
        //remove all previous paths and clear scene from past paths
        pathObjs.map({$0.removeFromParentNode()})
        pathObjs = []
        
        //Render current path
        for i in 0...stops.count-2{
            let pathCurrentVertex = odometryDict![Int(stops[i])!]!
            let pathNextVertex = odometryDict![Int(stops[i+1])!]!
            
            self.renderEdge(from: pathCurrentVertex, to: pathNextVertex, isPath: true)
        }
        
        /// Ping audio from a few nodes down to ensure direction
        if stops.count < 3 {
            self.playSound(type: "arrived")
            self.stopPathPlanning()
        } else {
            let audioSource = odometryDict![Int(stops[2])!]!
            let directionToSource = vector2(self.cameraNode.position.x, self.cameraNode.position.z) - vector2(audioSource.x, audioSource.z)
            var volumeScale = simd_dot(simd_normalize(directionToSource), vector2(self.cameraNode.transform.m31, self.cameraNode.transform.m33))
            volumeScale = acos(volumeScale) / Float.pi
            volumeScale = 1 - volumeScale
            volumeScale = pow(volumeScale, 3)
            self.audioPlayers["ping"]??.setVolume(volumeScale, fadeDuration: 0)
            print("Volume scale: \(volumeScale)")
        }
    }
    

    
    /// Checks the distance to all of the waypoints and announces those that are closer than a given threshold distance
    func detectNearbyWaypoints(){
        let curr_pose = cameraNode.position
        var potentialAnnouncements : [Int:(String, Double)] = [:]
        for count in waypointDictionary.keys{
            if let waypointName = waypointDictionary[count]?.id, let waypointNode = mapNode.childNode(withName: "Waypoint_" + waypointName, recursively: false) {
                let waypoint_pose = sceneView.scene.rootNode.convertPosition(waypointNode.position, from: mapNode)
                let distanceToCurrPose = sqrt(pow((waypoint_pose.x - curr_pose.x),2) + pow((waypoint_pose.y - curr_pose.y),2) + pow((waypoint_pose.z - curr_pose.z),2))
                if distanceToCurrPose < distanceToWaypoint, (lastSpeechTime[count] ?? Date.distantPast).timeIntervalSinceNow < -5.0, !synth.isSpeaking {
                    let twoDimensionalDistanceToCurrPose = sqrt(pow((waypoint_pose.x - curr_pose.x),2) + pow((waypoint_pose.y - curr_pose.y),2))
                    let announcement: String = waypointName + " is " + String(format: "%.1f", twoDimensionalDistanceToCurrPose) + " meters away."
                    potentialAnnouncements[count] = (announcement, (lastSpeechTime[count] ?? Date.distantPast).timeIntervalSinceNow)
                }
            }
        }
        // If multiple announcements are possible, pick the one that was least recently spoken
        let leastRecentlyAnnounced = potentialAnnouncements.min { a, b in a.value.1 < b.value.1 }
        if let leastRecentlyAnnounced = leastRecentlyAnnounced {
            let utterance = AVSpeechUtterance(string: leastRecentlyAnnounced.value.0)
            utterance.voice = voice
            lastSpeechTime[leastRecentlyAnnounced.key] = Date()
            synth.speak(utterance)
        }
    }
    
    
    
    /// Stores the april tags from firebase in a dictionary to speed up lookup of tags
    func storeTagsInDictionary() {
        for (tagId, vertex) in myMap.tagVertices.enumerated() {
            if snapTagsToVertical {
                let tagPose = simd_float4x4(translation: simd_float3(vertex.translation.x, vertex.translation.y, vertex.translation.z), rotation: simd_quatf(ix: vertex.rotation.x, iy: vertex.rotation.y, iz: vertex.rotation.z, r: vertex.rotation.w))
                
                // Note that the process of leveling the tag doesn't change translation
                let modifiedOrientation = simd_quatf(tagPose.makeZFlat().alignY())

                var newVertex = vertex
                newVertex.rotation.x = modifiedOrientation.imag.x
                newVertex.rotation.y = modifiedOrientation.imag.y
                newVertex.rotation.z = modifiedOrientation.imag.z
                newVertex.rotation.w = modifiedOrientation.real
                myMap.tagVertices[tagId] = newVertex
            }
            // rebind this variable in case it has changed (e.g., through snapTagsToVertical being true)
            let vertex = myMap.tagVertices[tagId]
            tagDictionary[vertex.id] = vertex
            let tagMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
            let tagNode = SCNNode(geometry: SCNBox(width: 0.19, height: 0.19, length: 0.05, chamferRadius: 0))
            tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
            tagNode.transform = tagMatrix
            mapNode.addChildNode(tagNode)
            tagNode.name = String("Tag_\(vertex.id)")

        }
    }
    
    // Finds and visualizes path to the endpoint on a timer
    func scheduledPathPlanningTimer() {
        pathPlanningTimer.invalidate()
        pathPlanningTimer = Timer()
        pathPlanningTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.pathPlanning), userInfo: nil, repeats: true)
    }
    
    /// Processes the pose, april tags, and nearby waypoints on a timer.
    func scheduledLocalizationTimer() {
        tagFinderTimer.invalidate()
        tagFinderTimer = Timer()
        tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.updateTags), userInfo: nil, repeats: true)
    }
    
    func scheduledPingTimer() {
         self.pingTimer.invalidate()
         self.pingTimer = Timer()
         self.pingTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.ping), userInfo: nil, repeats: true)
     }
     
     @objc func ping() {
         if !self.firstTagFound {
             return
         }
         self.playSound(type: "ping")
         let volume = self.audioPlayers["ping"]!!.volume
         // Audio volume was set to a cubic scale, revert back to linear
         let hapticScale = pow(volume, 1.0 / 3.0)
         if hapticScale > 0.75 {
             self.hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
         } else if hapticScale > 0.5 {
             self.hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
         } else if hapticScale > 0.25 {
             self.hapticGenerator = UIImpactFeedbackGenerator(style: .light)
         } else {
             self.hapticGenerator = nil
         }
         self.hapticGenerator?.impactOccurred()
     }
     @objc func playSound(type: String) {
         do {
             try AVAudioSession.sharedInstance().setCategory(AVAudioSession.C)
             try AVAudioSession.sharedInstance().setActive(true)
             guard let player = self.audioPlayers[type]! else { return }
             player.play()
         } catch let error {
             print(error.localizedDescription)
         }
     }
    
    
    /// Starts and stops the live detection of april tags.
    ///
    /// - Parameter sender: UIButton that reacts to being pressed
    @IBAction func startTagDetection(_ sender: UIButton) {
        if sender.currentTitle == "Start Tag Detection" {
            sender.setTitle("Stop Tag Detection", for: .normal)
            sender.accessibilityLabel = "Stop Tag Detection Button"
            scheduledLocalizationTimer()
            
        } else {
            sender.setTitle("Start Tag Detection", for: .normal)
            sender.accessibilityLabel = "Start Tag Detection Button"
            tagFinderTimer.invalidate()
            tagFinderTimer = Timer()
        }
    }

    func createTagDebugImage(tagDetections: Array<AprilTags>, image:UIImage)->UIImage? {
        // Create a context of the starting image size and set it as the current one
        UIGraphicsBeginImageContext(image.size)
        
        // Draw the starting image in the current context as background
        image.draw(at: CGPoint.zero)

        // Get the current context
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.cyan.cgColor)
        context.setAlpha(0.5)
        context.setLineWidth(0.0)
        let visualizationCirclesRadius = 10.0;
        for tag in tagDetections {
            // TODO: convert tuple to array to make this less janky (https://developer.apple.com/forums/thread/72120)
            context.addEllipse(in: CGRect(x: Int(tag.imagePoints.0-visualizationCirclesRadius), y: Int(tag.imagePoints.1-visualizationCirclesRadius), width: Int(visualizationCirclesRadius)*2, height: Int(visualizationCirclesRadius)*2))
            context.drawPath(using: .fillStroke)

            context.addEllipse(in: CGRect(x: Int(tag.imagePoints.2-visualizationCirclesRadius), y: Int(tag.imagePoints.3-visualizationCirclesRadius), width: Int(visualizationCirclesRadius)*2, height: Int(visualizationCirclesRadius)*2))
            context.drawPath(using: .fillStroke)

            context.addEllipse(in: CGRect(x: Int(tag.imagePoints.4-visualizationCirclesRadius), y: Int(tag.imagePoints.5-visualizationCirclesRadius), width: Int(visualizationCirclesRadius)*2, height: Int(visualizationCirclesRadius)*2))
            context.drawPath(using: .fillStroke)

            context.addEllipse(in: CGRect(x: Int(tag.imagePoints.6-visualizationCirclesRadius), y: Int(tag.imagePoints.7-visualizationCirclesRadius), width: Int(visualizationCirclesRadius)*2, height: Int(visualizationCirclesRadius)*2))
            context.drawPath(using: .fillStroke)
        }
        
        // Save the context as a new UIImage
        let myImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return myImage
    }

    /// Processes the pose, april tags, and nearby waypoints.
    @objc func updateLandmarks() {
        if isProcessingFrame {
            return
        }
        isProcessingFrame = true
        let (image, time, cameraTransform, cameraIntrinsics) = self.getVideoFrames()
        if let image = image, let time = time, let cameraTransform = cameraTransform, let cameraIntrinsics = cameraIntrinsics {
            print(cameraTransform.columns.3.x ,cameraTransform.columns.3.y, cameraTransform.columns.3.z)

            aprilTagQueue.async {
                let _ = self.checkTagDetection(image: image, timestamp: time, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
                self.detectNearbyWaypoints()
                self.isProcessingFrame = false
            }
        } else {
            isProcessingFrame = false
        }
    }
    
    /// Gets the current frames from the camera
    ///
    /// - Returns: the current camera frame as a UIImage and its timestamp
    func getVideoFrames() -> (UIImage?, Double?, simd_float4x4?, simd_float3x3?) {
        guard let cameraFrame = sceneView.session.currentFrame, let cameraTransform = sceneView.session.currentFrame?.camera.transform else {
            return (nil, nil, nil, nil)
        }
        let scene = SCNMatrix4(cameraTransform)
        if sceneView.scene.rootNode.childNode(withName: "camera", recursively: false) == nil {
            // TODO: remove camera node when we have some waypoints to test with (we can use ARFrame.camera.transform instead
            cameraNode = SCNNode()
            cameraNode.transform = scene
            cameraNode.name = "camera"
            sceneView.scene.rootNode.addChildNode(cameraNode)
        } else {
            cameraNode.transform = scene
        }
        
        // Convert ARFrame to a UIImage
        let pixelBuffer = cameraFrame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let uiImage = UIImage(cgImage: cgImage!)
        return (uiImage, cameraFrame.timestamp, cameraTransform, cameraFrame.camera.intrinsics)
    }
    
    /// Check if tag is detected and update the tag and map transforms
    ///
    /// - Parameters:
    ///   - rotatedImage: the camera frame rotated by 90 degrees to enable accurate tag detection
    ///   - timestamp: the timestamp of the current frame
    func checkTagDetection(image: UIImage, timestamp: Double, cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3)->Array<AprilTags> {
        let intrinsics = cameraIntrinsics.columns
        f.findTags(image, intrinsics.0.x, intrinsics.1.y, intrinsics.2.x, intrinsics.2.y)
        var tagArray: Array<AprilTags> = Array()
        let numTags = f.getNumberOfTags()
        var lastAppliedOriginShift: simd_float4x4?
        if numTags > 0 {
            if !self.firstTagFound {
                print("Starting path planning")
                self.renderGraphPath()
                self.playSound(type: "startNav")
                self.firstTagFound = true
            }
            
            for i in 0...f.getNumberOfTags()-1 {
                tagArray.append(f.getTagAt(i))
            }
            /// Add or update the tags that are detected
            for i in 0...tagArray.count-1 {
                addTagDetectionNode(detectionNodes: sceneView.scene.rootNode, snapTagsToVertical: snapTagsToVertical, doKalman: false, aprilTagDetectionDictionary: &aprilTagDetectionDictionary, tag: tagArray[i], cameraTransform: cameraTransform)
                /// Update the root to map transform if the tag detected is in the map
                if let tagVertex = tagDictionary[Int(tagArray[i].number)], let originShift = updateRootToMap(vertex: tagVertex) {
                    lastAppliedOriginShift = originShift
                }
            }
            
        }
        if let lastAppliedOriginShift = lastAppliedOriginShift {
            for detector in aprilTagDetectionDictionary.values {
                detector.willUpdateWorldOrigin(relativeTransform: lastAppliedOriginShift)
            }
        }
        return tagArray;
    }
    
    /// Ensures a tag detection is only used if the tag's z axis is nearly perpendicular or parallel to the gravity vector
    ///
    /// - Parameters:
    ///   - rootTagNode: A dummy node with a tag's potential updated transform
    /// - Returns: A boolean value indicating whether the updated transform should be used to update the tag node transform
    func checkTagAxis(rootTagNode: SCNNode) -> Bool {
        let tagZinRoot = rootTagNode.convertVector(SCNVector3(0,0,1), to: sceneView.scene.rootNode)
        let tagvector = SCNVector3ToGLKVector3(tagZinRoot)
        let gravityvector = GLKVector3Make(0.0, 1.0, 0.0)
        let dotproduct = GLKVector3DotProduct(tagvector,gravityvector)
        if tagTiltMin < abs(dotproduct) && abs(dotproduct) < tagTiltMax{
            return false
        }else{
            return true
        }
    }

    /// Updates the root to map transform if a tag currently being detected exists in the map
    ///
    /// - Parameter vertex: the tag vertex from firebase corresponding to the tag currently being detected
    func updateRootToMap(vertex: Map.Vertex)->simd_float4x4? {
        let tagMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
        let tagNode = SCNNode(geometry: SCNBox(width: 0.19, height: 0.19, length: 0.05, chamferRadius: 0))
        // TODO: we need to be doing something with setWorldOrigin here so corrections are not applied multiple times (also of interest is to look at the discrepancies between the turquoise square and the black square.  The turquoise square seems to track the AR session adjustments in a way that the black one doesn't).
        
        tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
        tagNode.transform = tagMatrix
        mapNode.addChildNode(tagNode)
        tagNode.name = String("Tag_\(vertex.id)")
        return computeRootToMap(tagId: vertex.id)
    }
    
    /// Computes and updates the root to map transform
    ///
    /// - Parameter tagId: the id number of an april tag as an integer
    func computeRootToMap(tagId: Int)->simd_float4x4? {
        if aprilTagDetectionDictionary[tagId] != nil {
            let rootToTag = simd_float4x4(sceneView.scene.rootNode.childNode(withName: "Tag_\(tagId)", recursively: false)!.transform)
            let mapToTag = simd_float4x4(mapNode.childNode(withName: "Tag_\(tagId)", recursively: false)!.transform)
            // the call to .alignY() flattens the transform so that it only rotates about the globoal y-axis (translation can happen along all dimensions)
            let originTransform = (rootToTag*mapToTag.inverse).alignY()
            mapNode.transform = SCNMatrix4(originTransform)
            // TODO: there still seems to be a little ringing going on
            sceneView.session.setWorldOrigin(relativeTransform: originTransform)
            mapNode.geometry = SCNBox(width: 0.25, height: 0.25, length: 0.25, chamferRadius: 0)
            mapNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            return originTransform
        }
        return nil
    }

    
    /// Automatically decodes the map Json files from firebase
    struct Map: Decodable {
        var tagVertices: [Vertex]
        let odometryVertices: [OdomVertex]
        let waypointsVertices: [WaypointVertex]
        
        enum CodingKeys: String, CodingKey {
            case tagVertices = "tag_vertices"
            case odometryVertices = "odometry_vertices"
            case waypointsVertices = "waypoints_vertices"
        }
        
        struct WaypointVertex: Decodable {
            let id: String
            let translation: vector3
            let rotation: quaternion
            
            enum CodingKeys: String, CodingKey {
                case id
                case translation = "translation"
                case rotation = "rotation"
            }
            
            struct vector3: Decodable {
                let x: Float
                let y: Float
                let z: Float
                
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                    case y = "y"
                    case z = "z"
                }
            }
            
            struct quaternion:Decodable {
                let x: Float
                let y: Float
                let z: Float
                let w: Float
                
                
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                    case y = "y"
                    case z = "z"
                    case w = "w"
                }
            }
        }
        
        struct Vertex: Decodable {
            let id: Int
            let translation: vector3
            var rotation: quaternion
            
            enum CodingKeys: String, CodingKey {
                case id
                case translation = "translation"
                case rotation = "rotation"
            }
            
            struct vector3: Decodable {
                let x: Float
                let y: Float
                let z: Float
                
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                    case y = "y"
                    case z = "z"
                }
            }
            
            struct quaternion:Decodable {
                var x: Float
                var y: Float
                var z: Float
                var w: Float
                
                
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                    case y = "y"
                    case z = "z"
                    case w = "w"
                }
            }
            
        }
        
        
        struct OdomVertex: Decodable {
            let poseId: Int
            let translation: vector3
            var rotation: quaternion
            var neighbors: [Int] = []

            
            enum CodingKeys: String, CodingKey {
                case poseId
                case translation = "translation"
                case rotation = "rotation"
                case neighbors = "neighbors"
            }
            
            struct vector3: Decodable {
                let x: Float
                let y: Float
                let z: Float
                
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                    case y = "y"
                    case z = "z"
                }
            }
            
            struct quaternion:Decodable {
                var x: Float
                var y: Float
                var z: Float
                var w: Float
                
                
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                    case y = "y"
                    case z = "z"
                    case w = "w"
                }
            }
            
        }
    }
    
    
    /// Dispose of any resources that can be recreated.
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


}

extension SCNMatrix4 {
    
    public func transpose() -> SCNMatrix4 {
        return SCNMatrix4(
            m11: m11, m12: m21, m13: m31, m14: m41,
            m21: m12, m22: m22, m23: m32, m24: m42,
            m31: m13, m32: m23, m33: m33, m34: m43,
            m41: m14, m42: m24, m43: m34, m44: m44)
    }
}

