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


class AprilTagTracker {
    let id: Int
    var scenePositions: Array<simd_float3> = []
    var sceneQuats: Array<simd_quatf> = []
    var scenePositionCovariances: Array<simd_float3x3> = []
    var sceneQuatCovariances: Array<simd_float4x4> = []
    private(set) var tagPosition = simd_float3()
    private(set) var tagOrientation = simd_quatf()

    func updateTagPoseMeans(id: Int, detectedPosition: simd_float3, detectedPositionVar: simd_float3x3, detectedQuat: simd_quatf, detectedQuatVar: simd_float4x4) {
        scenePositions.append(detectedPosition)
        scenePositionCovariances.append(detectedPositionVar)
        sceneQuats.append(detectedQuat)
        sceneQuatCovariances.append(detectedQuatVar)
        tagPosition = uncertaintyWeightedAverage(zs: scenePositions, sigmas: scenePositionCovariances)
        tagOrientation = averageQuaternions(quats: sceneQuats, quatCovariances: sceneQuatCovariances)
    }
    
    func uncertaintyWeightedAverage(zs: Array<simd_float3>, sigmas: Array<simd_float3x3>)->simd_float3 {
        // Strategy is to use the Kalman equations (https://en.wikipedia.org/wiki/Kalman_filter#Predict) with F_k set to identity, H_k set to identity, Q_k set to zero matix, R_k set to sigmas[k]
        // TODO: allow incremental updating to save time
        // TODO: this might be numerically unstable when we have a lot of measurements
        // DEBUG: this seems to drift all over the place when tag is far from origin
        // DEBUG: I think it's fixed now.   Need to test more.
        
        guard var xhat_kk = zs.first, var Pkk = sigmas.first else {
            return float3(Float.nan, Float.nan, Float.nan)
        }
        for i in 1..<zs.count {
            // Qk is the process noise.  Let's assume that there is a small drift of the tag position in the map frame over time
            let Qk = matrix_identity_float3x3*1e-5
            Pkk = Pkk + Qk;
            let Kk = Pkk*(Pkk + sigmas[i]).inverse
            Pkk = (matrix_identity_float3x3 - Kk)*Pkk
            xhat_kk = xhat_kk + Kk*(zs[i] - xhat_kk)
        }
        return xhat_kk
    }
    
    private func averageQuaternions(quats: Array<simd_quatf>, quatCovariances: Array<simd_float4x4>)->simd_quatf {
        var quatAverage = simd_quatf(vector: simd_float4(0, 0, 0, 1))  // initialize with no rotation
        var converged = false
        var epsilons = Array<Float>.init(repeating: 1.0, count: quats.count)
        while !converged {
            var xhat_kk = simd_quatf(angle: 0, axis: simd_float3(0, 0, 1)).vector
            var Pkk = matrix_identity_float4x4
            
            let epsilonTimesQuats = zip(quats, epsilons).map { $0.0*$0.1 }
            for (epsilonTimesQuat, quatCovariance) in zip(epsilonTimesQuats, quatCovariances) {
                // Qk is the process noise.  Let's assume that there is a small drift of the tag orientation in the map frame over time
                let Qk = matrix_identity_float4x4*1e-5
                Pkk = Pkk + Qk;
                let Kk = Pkk*(Pkk + quatCovariance).inverse
                Pkk = (matrix_identity_float4x4 - Kk)*Pkk
                xhat_kk = xhat_kk + Kk*(epsilonTimesQuat.vector - xhat_kk)
            }

            quatAverage = simd_quatf(vector: xhat_kk).normalized
            let newEpsilons = zip(epsilonTimesQuats, epsilons).map { simd_length($0.0 - quatAverage) < simd_length(-$0.0 - quatAverage) ? $0.1 : -$0.1 }
            converged = zip(epsilons, newEpsilons).reduce(true, {x,y in x && y.0 == y.1})
            epsilons = newEpsilons
        }
        return quatAverage
    }

    init(tagId: Int) {
        id = tagId
    }
}

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
    
    @IBOutlet weak var axisDebugging: UILabel!
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var tagDebugging: UIImageView!
    var tagFinderTimer = Timer()
    
    /// Speech synthesis objects (reuse these or memory will leak)
    let synth = AVSpeechSynthesizer()
    let voice = AVSpeechSynthesisVoice(language: "en-US")
    var lastSpeechTime : [Int:Date] = [:]

    let f = imageToData()
    var isProcessingFrame = false
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.invisiblemap", qos: DispatchQoS.userInitiated)
    
    
    /// Initializes the ARSession and downloads the selected map data from firebase
    override func viewDidLoad() {
        super.viewDidLoad()
        startSession()
        createMap()
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
        configuration.isAutoFocusEnabled = false
        sceneView.session.run(configuration)
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
        for vertex in myMap.tagVertices{
            tagDictionary[vertex.id] = vertex
            let tagMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
            let tagNode = SCNNode(geometry: SCNBox(width: 0.11, height: 0.11, length: 0.05, chamferRadius: 0))
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

    
    /// Processes the pose, april tags, and nearby waypoints.
    @objc func updateLandmarks() {
        if isProcessingFrame {
            return
        }
        isProcessingFrame = true
        let (image, time, cameraTransform, cameraIntrinsics) = self.getVideoFrames()
        if let image = image, let time = time, let cameraTransform = cameraTransform, let cameraIntrinsics = cameraIntrinsics {
            aprilTagQueue.async {
                let tagDetections = self.checkTagDetection(image: image, timestamp: time, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
                self.detectNearbyWaypoints()
                self.isProcessingFrame = false
                DispatchQueue.main.async {
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
                    self.tagDebugging.image = myImage
                }
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
        if numTags > 0 {
            for i in 0...f.getNumberOfTags()-1 {
                tagArray.append(f.getTagAt(i))
            }
            /// Add or update the tags that are detected
            for i in 0...tagArray.count-1 {
                addTagDetectionNode(tag: tagArray[i], cameraTransform: cameraTransform)
                /// Update the root to map transform if the tag detected is in the map
                if let tagVertex = tagDictionary[Int(tagArray[i].number)] {
                    updateRootToMap(vertex: tagVertex)
                }
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
    
    /// Adds or updates a tag node when a tag is detected
    ///
    /// - Parameter tag: the april tag detected by the visual servoing platform
    func addTagDetectionNode(tag: AprilTags, cameraTransform: simd_float4x4) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        let pose = tag.poseData
        let transStd = simd_float3(x: Float(tag.transVecStdDev.0), y: Float(tag.transVecStdDev.1), z: Float(tag.transVecStdDev.2))
        let quatStd = simd_float4(x: Float(tag.quatStdDev.0), y: Float(tag.quatStdDev.1), z: Float(tag.quatStdDev.2), w: Float(tag.quatStdDev.3))

        var simdPose = simd_float4x4(rows: [float4(Float(pose.0), Float(pose.1), Float(pose.2),Float(pose.3)), float4(Float(pose.4), Float(pose.5), Float(pose.6), Float(pose.7)), float4(Float(pose.8), Float(pose.9), Float(pose.10), Float(pose.11)), float4(Float(pose.12), Float(pose.13), Float(pose.14), Float(pose.15))])
        
        // the axis mapping is used to figure out how the standard deviations should map to the global coordinate system
        var axisMapping = matrix_identity_float4x4
        
        axisMapping = axisMapping.rotate(radians: Float.pi, 0, 1, 0)
        axisMapping = axisMapping.rotate(radians: Float.pi, 0, 0, 1)
        
        // convert from April Tags conventions to Apple's (TODO: could this be done in one rotation?)
        simdPose = simdPose.rotate(radians: Float.pi, 0, 1, 0)
        simdPose = simdPose.rotate(radians: Float.pi, 0, 0, 1)
        var scenePose = cameraTransform*simdPose
        axisMapping = cameraTransform*axisMapping

        if snapTagsToVertical {
            let angleAdjustment = atan2(scenePose.columns.2.y, scenePose.columns.1.y)
            // perform an intrinsic rotation about the x-axis to make sure the z-axis of the tag is flat with respect to gravity
            scenePose = scenePose*simd_float4x4.makeRotate(radians: angleAdjustment, 1, 0, 0)
            axisMapping = axisMapping*simd_float4x4.makeRotate(radians: angleAdjustment, 1, 0, 0)
        }
        

        let transVar = simd_float3x3(diagonal: simd_float3(pow(transStd.x, 2), pow(transStd.y, 2), pow(transStd.z, 2)))
        let quatVar = simd_float4x4(diagonal: simd_float4(pow(quatStd.x, 2), pow(quatStd.y, 2), pow(quatStd.z, 2), pow(quatStd.w, 2)))
        
        let q = simd_quatf(axisMapping)

        let quatMultiplyAsLinearTransform =
            simd_float4x4(columns: (simd_float4(q.vector.w, q.vector.z, -q.vector.y, -q.vector.x),
                                    simd_float4(-q.vector.z, q.vector.w, q.vector.x, -q.vector.y),
                                    simd_float4(q.vector.y, -q.vector.x, q.vector.w, -q.vector.z),
                                    simd_float4(q.vector.x, q.vector.y, q.vector.z, q.vector.w)))
        let sceneTransVar = axisMapping.getUpper3x3()*transVar*axisMapping.getUpper3x3().transpose
        let sceneQuatVar = quatMultiplyAsLinearTransform*quatVar*quatMultiplyAsLinearTransform.transpose

        let scenePoseQuat = simd_quatf(scenePose.getRot())
        let scenePoseTranslation = scenePose.getTrans()
        let aprilTagTracker = aprilTagDetectionDictionary[Int(tag.number), default: AprilTagTracker(tagId: Int(tag.number))]
        aprilTagDetectionDictionary[Int(tag.number)] = aprilTagTracker

        // TODO: need some sort of logic to discard old detections.  One method that seems good would be to add some process noise (Q_k non-zero)
        aprilTagTracker.updateTagPoseMeans(id: Int(tag.number), detectedPosition: scenePoseTranslation, detectedPositionVar: sceneTransVar, detectedQuat: scenePoseQuat, detectedQuatVar: sceneQuatVar)
        
        print(aprilTagTracker.tagOrientation)
        
        DispatchQueue.main.async {
            self.axisDebugging.text = String(format: "%f, %f, %f", scenePose.columns.2.x, scenePose.columns.2.y, scenePose.columns.2.z)
        }
        let tagNode: SCNNode
        if let existingTagNode = sceneView.scene.rootNode.childNode(withName: "Tag_\(String(tag.number))", recursively: false)  {
            tagNode = existingTagNode
            tagNode.simdPosition = aprilTagTracker.tagPosition
            tagNode.simdOrientation = aprilTagTracker.tagOrientation
        } else {
            tagNode = SCNNode()
            tagNode.simdPosition = aprilTagTracker.tagPosition
            tagNode.simdOrientation = aprilTagTracker.tagOrientation
            tagNode.geometry = SCNBox(width: 0.11, height: 0.11, length: 0.05, chamferRadius: 0)
            tagNode.name = "Tag_\(String(tag.number))"
            tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
            sceneView.scene.rootNode.addChildNode(tagNode)
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

    /// Updates the root to map transform if a tag currently being detected exists in the map
    ///
    /// - Parameter vertex: the tag vertex from firebase corresponding to the tag currently being detected
    func updateRootToMap(vertex: Map.Vertex) {
        let tagMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
        let tagNode = SCNNode(geometry: SCNBox(width: 0.11, height: 0.11, length: 0.05, chamferRadius: 0))
        tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
        tagNode.transform = tagMatrix
        mapNode.addChildNode(tagNode)
        tagNode.name = String("Tag_\(vertex.id)")
        computeRootToMap(tagId: vertex.id)
    }
    
    /// Computes and updates the root to map transform
    ///
    /// - Parameter tagId: the id number of an april tag as an integer
    func computeRootToMap(tagId: Int) {
        if aprilTagDetectionDictionary[tagId] != nil {
            let rootToTag = (sceneView.scene.rootNode.childNode(withName: "Tag_\(tagId)", recursively: false)?.transform)!.transpose()
            let tagToMap = SCNMatrix4Invert((mapNode.childNode(withName: "Tag_\(tagId)", recursively: false)?.transform.transpose())!)
            let rootToMap = SCNMatrix4Mult(rootToTag, tagToMap)
            mapNode.transform = rootToMap.transpose()
            mapNode.geometry = SCNBox(width: 0.25, height: 0.25, length: 0.25, chamferRadius: 0)
            mapNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        }
    }

    
    /// Automatically decodes the map Json files from firebase
    struct Map: Decodable {
        let tagVertices: [Vertex]
        let odometryVertices: [Vertex]
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

