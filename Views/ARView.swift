//
//  ARView.swift
//
//  Created by Marion Madanguit on 3/19/21.
//

import Foundation
import ARKit
import GLKit
import SwiftUI
import AVFoundation
import AudioToolbox
import MediaPlayer

protocol ARViewController {
    // Commands that interact with the ARView
    var supportsLidar: Bool { get }
    var lastRecordedTimestamp: Double { get set }
    func initialize()
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool)
    func raycastTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) -> simd_float4x4?
    func pinLocation(locationName: String)
    func resetArSession()
}

//TODO: Check if this is needed
// ARViewIndicator
//struct ARViewIndicator: UIViewControllerRepresentable {
//   typealias UIViewControllerType = ARView
//
//   func makeUIViewController(context: Context) -> ARView {
//      return ARView()
//   }
//   func updateUIViewController(_ uiViewController:
//   ARViewIndicator.UIViewControllerType, context:
//   UIViewControllerRepresentableContext<ARViewIndicator>) { }
//}

class ARView: UIViewController {
    let memoryChecker : MemoryChecker = MemoryChecker()
    let configuration = ARWorldTrackingConfiguration()
    #if IS_MAP_CREATOR
        let sharedController = InvisibleMapCreatorController.shared
    #else
        let sharedController = InvisibleMapController.shared
    #endif
    let recordInterval = 0.1
    var lastRecordedTimestamp = -0.1
    let distanceToAnnounceWaypoint: Float = 1.5
    
    var mapNode: SCNNode!
    var detectionNode: SCNNode!
    var cameraNode: SCNNode!
    let locationNodeName = "Locations"
    let tagNodeName = "Tags"
    let crumbNodeName = "Crumbs"
    let edgeNodeName = "Edges"
    
    /// Speech synthesis objects (reuse these or memory will leak)
    let synth = AVSpeechSynthesizer()
    let voice = AVSpeechSynthesisVoice(language: "en-US")
    var lastSpeechTime : [String:Date] = [:]
    
    // audio and haptic feedback
    var audioPlayers: [String: AVAudioPlayer?] = [:]
    var pingTimer = Timer()
    var hapticGenerator : UIImpactFeedbackGenerator?
    
    var pathObjs: [SCNNode] = []
    
    // Create an AR view
    @IBOutlet var arView: ARSCNView! {
        get {
            return self.view as? ARSCNView
        }
        set(newView) {
            self.view = newView
        }
    }
    
    override func loadView() {
      self.view = ARSCNView(frame: .zero)
    }
    
    // Load, assign a delegate, and create a scene
    override func viewDidLoad() {
        super.viewDidLoad()
        arView.session.delegate = self
        arView.scene = SCNScene()
        sharedController.arViewer = self
        configuration.planeDetection = [.horizontal, .vertical]
        //if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
        //    configuration.sceneReconstruction = .mesh
        //}
        sharedController.initialize()
    }
    
    // Functions for standard AR view handling
    override func viewDidAppear(_ animated: Bool) {
       super.viewDidAppear(animated)
    }
    override func viewDidLayoutSubviews() {
       super.viewDidLayoutSubviews()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arView.session.run(configuration)
    }
    override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       arView.session.pause()
    }
}

extension ARView: ARSessionDelegate {
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        //NavigationController.shared.trackingStatusChanged(session: session, camera: camera)
    }
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        #if IS_MAP_CREATOR
            let processingFrame = self.sharedController.mapRecorder.processingFrame
        #else
            let processingFrame = self.sharedController.mapNavigator.processingFrame
        #endif
        
        if lastRecordedTimestamp + recordInterval <= frame.timestamp && !processingFrame {
            let scene = SCNMatrix4(frame.camera.transform)
            if self.cameraNode == nil {
                // TODO: remove camera node when we have some waypoints to test with (we can use ARFrame.camera.transform instead
                cameraNode = SCNNode()
                cameraNode.transform = scene
                cameraNode.name = "camera"
                arView.scene.rootNode.addChildNode(cameraNode)
            } else {
                cameraNode.transform = scene
            }
            lastRecordedTimestamp = frame.timestamp
            print("Timestamp: \(frame.timestamp)")
            sharedController.process(event: .NewARFrame(cameraFrame: frame))
        }
        self.memoryChecker.printRemainingMemory()
        if(self.memoryChecker.getRemainingMemory() < 500) {
            arView.session.pause()
            arView.session.run(configuration, options: [.resetSceneReconstruction])
        }
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // let newAnchors = anchors.compactMap({$0 as? ARPlaneAnchor})
        // InvisibleMapCreatorController.shared.process(event: .PlanesUpdated(planes: newAnchors))
    }
    
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // let updatedAnchors = anchors.compactMap({$0 as? ARPlaneAnchor})
        // InvisibleMapCreatorController.shared.process(event: .PlanesUpdated(planes: updatedAnchors))
    }
}

extension ARView: ARViewController {
    
    /// Transforms the AprilTag position into world frame
    var supportsLidar: Bool {
        get {
            return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        }
    }
    
    func initialize() {
        self.startSession()
        self.createMapNode()
    }
    
    func reset() {
        self.pingTimer.invalidate()
        self.pingTimer = Timer()
    }
    
    /// Adds or updates a tag node when a tag is detected
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) {
        DispatchQueue.main.async {
            let pose = tag.poseData

            let originalTagPose = simd_float4x4(pose)
            
            let transVar = simd_float3(Float(tag.transVecVar.0), Float(tag.transVecVar.1), Float(tag.transVecVar.2))
            let quatVar = simd_float4(x: Float(tag.quatVar.0), y: Float(tag.quatVar.1), z: Float(tag.quatVar.2), w: Float(tag.quatVar.3))
            
            let scenePose = detectionFrameToGlobal(tagPose: originalTagPose, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
            let transVarMatrix = simd_float3x3(diagonal: transVar)
            let quatVarMatrix = simd_float4x4(diagonal: quatVar)

            // this is the linear transform that takes the original tag pose to the final world pose
            let linearTransform = scenePose*originalTagPose.inverse
            let q = simd_quatf(linearTransform)

            let quatMultiplyAsLinearTransform =
            simd_float4x4(columns: (simd_float4(q.vector.w, q.vector.z, -q.vector.y, -q.vector.x),
                                    simd_float4(-q.vector.z, q.vector.w, q.vector.x, -q.vector.y),
                                    simd_float4(q.vector.y, -q.vector.x, q.vector.w, -q.vector.z),
                                    simd_float4(q.vector.x, q.vector.y, q.vector.z, q.vector.w)))
            let sceneTransVar = linearTransform.getUpper3x3()*transVarMatrix*linearTransform.getUpper3x3().transpose
            let sceneQuatVar = quatMultiplyAsLinearTransform*quatVarMatrix*quatMultiplyAsLinearTransform.transpose
            let scenePoseQuat = simd_quatf(scenePose)
            let scenePoseTranslation = scenePose.getTrans()
                        
            let doKalman = false
            let aprilTagTracker = InvisibleMapController.shared.mapNavigator.map.aprilTagDetectionDictionary[Int(tag.number), default: AprilTagTracker(self.arView, tagId: Int(tag.number))]
            InvisibleMapController.shared.mapNavigator.map.aprilTagDetectionDictionary[Int(tag.number)] = aprilTagTracker

            // TODO: need some sort of logic to discard old detections.  One method that seems good would be to add some process noise (Q_k non-zero)
            aprilTagTracker.updateTagPoseMeans(id: Int(tag.number), detectedPosition: scenePoseTranslation, detectedPositionVar: sceneTransVar, detectedQuat: scenePoseQuat, detectedQuatVar: sceneQuatVar, doKalman: doKalman)

            let tagNode: SCNNode
            if let existingTagNode = self.detectionNode.childNode(withName: "Tag_\(String(tag.number))", recursively: false)  {
                tagNode = existingTagNode
                tagNode.simdPosition = aprilTagTracker.tagPosition
                tagNode.simdOrientation = aprilTagTracker.tagOrientation
            } else {
                tagNode = SCNNode()
                tagNode.simdPosition = aprilTagTracker.tagPosition
                tagNode.simdOrientation = aprilTagTracker.tagOrientation
                tagNode.geometry = SCNBox(width: 0.19, height: 0.19, length: 0.05, chamferRadius: 0)
                tagNode.name = "Tag_\(String(tag.number))"
                tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
                self.detectionNode.addChildNode(tagNode)
            }

            /// Adds axes to the tag to aid in the visualization
            let xAxis = SCNNode(geometry: SCNBox(width: 1.0, height: 0.05, length: 0.05, chamferRadius: 0))
            xAxis.position = SCNVector3.init(0.75, 0, 0)
            xAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            let yAxis = SCNNode(geometry: SCNBox(width: 0.05, height: 1.0, length: 0.05, chamferRadius: 0))
            yAxis.position = SCNVector3.init(0, 0.75, 0)
            yAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            let zAxis = SCNNode(geometry: SCNBox(width: 0.05, height: 0.05, length: 1.0, chamferRadius: 0))
            zAxis.position = SCNVector3.init(0, 0, 0.75)
            zAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            tagNode.addChildNode(xAxis)
            tagNode.addChildNode(yAxis)
            tagNode.addChildNode(zAxis)
        }
    }
    
    /// Raycasts from camera to tag and places tag on the nearest mesh if the device supports LiDAR
    func raycastTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) -> simd_float4x4? {
        let pose = tag.poseData

        let originalTagPose = simd_float4x4(pose)
        
        let scenePose = detectionFrameToGlobal(tagPose: originalTagPose, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
        
        let tagPos = simd_float3(scenePose.columns.3.x, scenePose.columns.3.y, scenePose.columns.3.z)
        let cameraPos = simd_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        
        let raycastQuery = ARRaycastQuery(origin: cameraPos, direction: tagPos - cameraPos, allowing: .existingPlaneGeometry, alignment: .any)
        let raycastResult = self.arView.session.raycast(raycastQuery)
        
        if raycastResult.count == 0 {
            return nil
        } else {
            let meshTransform = raycastResult[0].worldTransform
            let raycastTagTransform: simd_float4x4 = simd_float4x4(diagonal:simd_float4(1, -1, -1, 1)) * cameraTransform.inverse * meshTransform
            
            return raycastTagTransform
        }
    }
    
    /// Creates location node when a location is added
    func pinLocation(locationName: String) {
        DispatchQueue.main.async {
            // Generate UUID here and pass it in with the recordLocation data
            let box = SCNBox(width: 0.05, height: 0.2, length: 0.05, chamferRadius: 0)
            
            let text = SCNText(string: locationName, extrusionDepth: 0)
            
            let cameraNode = self.arView.pointOfView
            let boxNode = SCNNode()
            let textNode = SCNNode()
            boxNode.geometry = box
            boxNode.name = locationName
            textNode.geometry = text
            textNode.name = locationName + "Text"
            let boxPosition = SCNVector3(0,0,0)
            textNode.position = SCNVector3(0,0.1,0)
            
            self.updatePositionAndOrientationOf(boxNode, withPosition: boxPosition, relativeTo: cameraNode!)
            
            textNode.scale = SCNVector3(0.005,0.005,0.005)
            
            self.mapNode.childNode(withName: self.locationNodeName, recursively: false)!.addChildNode(boxNode)
            boxNode.addChildNode(textNode)
            
            let snapshot = self.arView.snapshot()
            #if IS_MAP_CREATOR
            self.sharedController.cacheLocationRequested(node: boxNode, picture: snapshot, textNode: textNode)
            #endif
        }
    }
    
    /// Move node position relative to another node's position.
    func updatePositionAndOrientationOf(_ node: SCNNode, withPosition position: SCNVector3, relativeTo referenceNode: SCNNode) {
        let referenceNodeTransform = matrix_float4x4(referenceNode.transform)
        
        var translationMatrix = matrix_identity_float4x4
        translationMatrix.columns.3.x = position.x
        translationMatrix.columns.3.y = position.y
        translationMatrix.columns.3.z = position.z
        
        let updatedTransform = matrix_multiply(referenceNodeTransform, translationMatrix)
        node.transform = SCNMatrix4(updatedTransform)
    }
    
    /// Reset ARSession after a map recording has been exited
    func resetArSession() {
        arView.session.pause()
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
    }
    
    /// Initializes the map node, of which all of the tags and waypoints downloaded from firebase are children
    func createMapNode() {
        mapNode = SCNNode()
        mapNode.position = SCNVector3(x: 0, y: 0, z: 0)
        arView.scene.rootNode.addChildNode(mapNode)
        for nodeName in [locationNodeName, tagNodeName, crumbNodeName, edgeNodeName] {
            let node = SCNNode()
            node.name = nodeName
            node.position = SCNVector3(x: 0, y: 0, z: 0)
            mapNode.addChildNode(node)
        }
        
        self.createDetectionNode()
    }
    
    /// Initializes the detection node, which all tag detections are children of
    func createDetectionNode() {
        detectionNode = SCNNode()
        detectionNode.position = SCNVector3(x: 0, y: 0, z: 0)
        arView.scene.rootNode.addChildNode(detectionNode)
    }
    
    /// Initialize the ARSession
    func startSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
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

    /// Creates a node for a path edge between two vertices
    func renderEdge(from firstVertex: RawMap.OdomVertex.vector3, to secondVertex: RawMap.OdomVertex.vector3, isPath: Bool) {
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
            mapNode.childNode(withName: crumbNodeName, recursively: false)!.addChildNode(odometryNode)
            
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
            mapNode.childNode(withName: edgeNodeName, recursively: false)!.addChildNode(pathObj!)
        }
    }
    
    func renderEdges(fromList vertices: [RawMap.OdomVertex.vector3], isPath: Bool) {
        pathObjs.map({$0.removeFromParentNode()})
        pathObjs = []
        for i in 0...vertices.count-2 {
            self.renderEdge(from: vertices[i], to: vertices[i + 1], isPath: isPath)
        }
        
        if isPath {
            /// Ping audio from a few nodes down to ensure direction
            if vertices.count < 3 {
                #if !IS_MAP_CREATOR
                InvisibleMapController.shared.process(event: .WaypointReached(finalWaypoint: true))
                #endif
            } else {
                let audioSource = vertices[2]
                let directionToSource = vector2(self.cameraNode.position.x, self.cameraNode.position.z) - vector2(audioSource.x, audioSource.z)
                var volumeScale = simd_dot(simd_normalize(directionToSource), vector2(self.cameraNode.transform.m31, self.cameraNode.transform.m33))
                volumeScale = acos(volumeScale) / Float.pi
                volumeScale = 1 - volumeScale
                volumeScale = pow(volumeScale, 3)
                self.audioPlayers["ping"]??.setVolume(volumeScale, fadeDuration: 0)
                print("Volume scale: \(volumeScale)")
            }
        }
    }
    
    /// Renders entire path for debugging
    func renderDebugGraph(){
        #if !IS_MAP_CREATOR
            for vertex in self.sharedController.mapNavigator.map.rawData.odometryVertices {
                for neighbor in vertex.neighbors{
                    // Only render path if it hasn't been rendered yet
                    if (neighbor < vertex.poseId){
                        let neighborVertex = self.sharedController.mapNavigator.map.odometryDict![neighbor]!
                        
                        // Render edge
                        self.renderEdge(from: vertex.translation, to: neighborVertex, isPath: false)
                    }
                }
            }
        #endif
    }
    
    func renderTags() {
        #if !IS_MAP_CREATOR
        for tagId in self.sharedController.mapNavigator.map.tagDictionary.keys {
            let tag = self.sharedController.mapNavigator.map.tagDictionary[tagId]!
            let tagNode = SCNNode()
            tagNode.geometry = SCNBox(width: 0.19, height: 0.19, length: 0.05, chamferRadius: 0)
            tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
            tagNode.name = "Tag_\(tagId)"
            tagNode.transform = SCNMatrix4(simd_float4x4(tag))
            self.mapNode.childNode(withName: self.tagNodeName, recursively: false)?.addChildNode(tagNode)
        }
        #endif
    }
    
    func renderGraph(fromStops stops: [RawMap.OdomVertex.vector3]) {
        self.renderEdges(fromList: stops, isPath: true)
        self.renderTags()
    }
    
    
    
    /// Checks the distance to all of the waypoints and announces those that are closer than a given threshold distance
    func announceNearbyWaypoints(){
        let curr_pose = cameraNode.position
        var potentialAnnouncements : [String:(String, Double)] = [:]
        for waypointNode in self.mapNode.childNode(withName: locationNodeName, recursively: false)!.childNodes {
            let nodeName = waypointNode.name!
            let waypointName = String(nodeName[nodeName.index(nodeName.firstIndex(of: "_")!, offsetBy: 1)...])
            let waypoint_pose = arView.scene.rootNode.convertPosition(waypointNode.position, from: mapNode)
            let distanceToCurrPose = sqrt(pow((waypoint_pose.x - curr_pose.x),2) + pow((waypoint_pose.y - curr_pose.y),2) + pow((waypoint_pose.z - curr_pose.z),2))
            if distanceToCurrPose < self.distanceToAnnounceWaypoint, (lastSpeechTime[waypointName] ?? Date.distantPast).timeIntervalSinceNow < -5.0, !synth.isSpeaking {
                let twoDimensionalDistanceToCurrPose = sqrt(pow((waypoint_pose.x - curr_pose.x),2) + pow((waypoint_pose.y - curr_pose.y),2))
                let announcement: String = waypointName + " is " + String(format: "%.1f", twoDimensionalDistanceToCurrPose) + " meters away."
                potentialAnnouncements[waypointName] = (announcement, (lastSpeechTime[waypointName] ?? Date.distantPast).timeIntervalSinceNow)
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
    
    func scheduledPingTimer() {
         self.pingTimer.invalidate()
         self.pingTimer = Timer()
         self.pingTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.ping), userInfo: nil, repeats: true)
     }
     
     @objc func ping() {
         #if IS_MAP_CREATOR
            return
         #else
             if !self.sharedController.mapNavigator.map.firstTagFound {
                 return
             }
        #endif
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
             try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
             try AVAudioSession.sharedInstance().setActive(true)
             guard let player = self.audioPlayers[type]! else { return }
             player.play()
         } catch let error {
             print(error.localizedDescription)
         }
     }
    
    func updateMapPose(to mapToGlobal: simd_float4x4) {
        self.mapNode.simdTransform = mapToGlobal
    }
}