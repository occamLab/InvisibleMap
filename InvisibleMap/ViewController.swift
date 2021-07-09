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
import Firebase
import FirebaseDatabase
import FirebaseStorage

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
    /// We use the knowledge that the z-axis of the tag should be perpendicular to gravity to adjust the tag detection
    var snapTagsToVertical = true
    
    @IBOutlet var sceneView: ARSCNView!
    var tagFinderTimer = Timer()
    
    /// Speech synthesis objects (reuse these or memory will leak)
    let synth = AVSpeechSynthesizer()
    let voice = AVSpeechSynthesisVoice(language: "en-US")
    var lastSpeechTime : [Int:Date] = [:]

    let f = imageToData()
    var isProcessingFrame = false
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.invisiblemap", qos: DispatchQoS.userInitiated)
    
    override func viewWillAppear(_ animated: Bool) {
        startSession()
        createMap()
    }

    override func viewWillDisappear(_ animated: Bool) {
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
        sceneView.session.pause()
        tagFinderTimer.invalidate()
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
    
    /// Downloads the selected map from firebase
    func createMap() {
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
    
    
    
    /// Processes the pose, april tags, and nearby waypoints on a timer.
    func scheduledLocalizationTimer() {
        tagFinderTimer.invalidate()
        tagFinderTimer = Timer()
        tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.updateLandmarks), userInfo: nil, repeats: true)
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
            for i in 0...f.getNumberOfTags()-1 {
                tagArray.append(f.getTagAt(i))
            }
            /// Add or update the tags that are detected
            for i in 0...tagArray.count-1 {
                addTagDetectionNode(sceneView: sceneView, snapTagsToVertical: snapTagsToVertical, doKalman: true, aprilTagDetectionDictionary: &aprilTagDetectionDictionary, tag: tagArray[i], cameraTransform: cameraTransform)
                /// Update the root to map transform if the tag detected is in the map
                if let tagVertex = tagDictionary[Int(tagArray[i].number)], let originShift = updateRootToMap(vertex: tagVertex) {
                    lastAppliedOriginShift = originShift
                }
            }
            for vertexIndex in stride(from: 0, to: myMap.odometryVertices.count, by: 5) {
                updateRootToMap(vertex: myMap.odometryVertices[vertexIndex])
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
    func updateRootToMap(vertex: Map.OdomVertex) {
        let odomMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
        let odomNode = SCNNode(geometry: SCNSphere(radius: 0.1))
        
        odomNode.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
        odomNode.transform = odomMatrix
        mapNode.addChildNode(odomNode)
        odomNode.name = String("Odom_\(vertex.poseId)")
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
                
                enum CodingKeys: String, CodingKey {
                    case poseId
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

