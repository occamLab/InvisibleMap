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


/// The view controller for displaying a map and announcing waypoints
class ViewController: UIViewController {
    
    //MARK: Properties
    var storageRef: StorageReference!
    var myMap: Map!
    var mapNode: SCNNode!
    var cameraNode: SCNNode!
    var aprilTagDetectionDictionary = Dictionary<Int, Array<Float>>()
    var tagDictionary = [Int:ViewController.Map.Vertex]()
    var waypointDictionary = [Int:ViewController.Map.WaypointVertex]()
    var waypointKeyDictionary = [String:Int]()
    let distanceToWaypoint: Float = 1.5
    let tagTiltMin: Float = 0.09
    let tagTiltMax: Float = 0.91
    var mapFileName: String = ""
    
    @IBOutlet var sceneView: ARSCNView!
    
    var tagFinderTimer = Timer()
    

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
            //waypointMatrix = convertRosToIosCoordinates(matrix: waypointMatrix)
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
        for count in waypointDictionary.keys{
            if mapNode.childNode(withName: "Waypoint_" + (waypointDictionary[count]?.id)!, recursively: false) != nil{
                let waypoint_pose_map = mapNode.childNode(withName: "Waypoint_" + (waypointDictionary[count]?.id)!, recursively: false)?.position
                let waypoint_pose = sceneView.scene.rootNode.convertPosition(waypoint_pose_map!, from: mapNode)
                let distanceToCurrPose = sqrt(pow((waypoint_pose.x - curr_pose.x),2) + pow((waypoint_pose.y - curr_pose.y),2) + pow((waypoint_pose.z - curr_pose.z),2))
                if distanceToCurrPose < distanceToWaypoint{
                    let twoDimensionalDistanceToCurrPose = sqrt(pow((waypoint_pose.x - curr_pose.x),2) + pow((waypoint_pose.y - curr_pose.y),2))
                    let announcement: String = (waypointDictionary[count]?.id)! + " is " + String(format: "%.1f", twoDimensionalDistanceToCurrPose) + " meters away."
                    let utterance = AVSpeechUtterance(string: announcement)
                    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                    let synth = AVSpeechSynthesizer()
                    synth.speak(utterance)
            }
            
            }
        }
    }
    
    
    
    /// Stores the april tags from firebase in a dictionary to speed up lookup of tags
    func storeTagsInDictionary() {
        for vertex in myMap.tagVertices{
            tagDictionary[vertex.id] = vertex
            let tagMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
            //tagMatrix = convertRosToIosCoordinates(matrix: tagMatrix)
            let tagNode = SCNNode(geometry: SCNBox(width: 0.165, height: 0.165, length: 0.05, chamferRadius: 0))
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
        tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.updateLandmarks), userInfo: nil, repeats: true)
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
                self.checkTagDetection(image: image, timestamp: time, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
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
    func checkTagDetection(image: UIImage, timestamp: Double, cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3) {
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
        // TODO: for debugging make an impact
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        let pose = tag.poseData
        var simdPose = simd_float4x4(rows: [float4(Float(pose.0), Float(pose.1), Float(pose.2),Float(pose.3)), float4(Float(pose.4), Float(pose.5), Float(pose.6), Float(pose.7)), float4(Float(pose.8), Float(pose.9), Float(pose.10), Float(pose.11)), float4(Float(pose.12), Float(pose.13), Float(pose.14), Float(pose.15))])
        // convert from April Tags conventions to Apple's (TODO: could this be done in one rotation?)
        simdPose = simdPose.rotate(radians: Float.pi, 0, 1, 0)
        simdPose = simdPose.rotate(radians: Float.pi, 0, 0, 1)

        let tagNode: SCNNode
        if let existingTagNode = sceneView.scene.rootNode.childNode(withName: "Tag_\(String(tag.number))", recursively: false)  {
             print("disable axis check")
            // if true || checkTagAxis(rootTagNode: rootTagNode){
            existingTagNode.transform = SCNMatrix4(cameraTransform*simdPose)
            //}
            tagNode = existingTagNode
        } else {
            tagNode = SCNNode()
            tagNode.transform = SCNMatrix4(cameraTransform*simdPose)
            tagNode.geometry = SCNBox(width: 0.165, height: 0.165, length: 0.05, chamferRadius: 0)
            tagNode.name = "Tag_\(String(tag.number))"
            tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
            sceneView.scene.rootNode.addChildNode(tagNode)
        }
        
        /// Adds axes to the tag to aid in the visualization
        let xAxis = SCNNode(geometry: SCNBox(width: 1.0, height: 0.1, length: 0.1, chamferRadius: 0))
        xAxis.position = SCNVector3.init(1, 0, 0)
        xAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        let yAxis = SCNNode(geometry: SCNBox(width: 0.1, height: 1.0, length: 0.1, chamferRadius: 0))
        yAxis.position = SCNVector3.init(0, 1, 0)
        yAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        let zAxis = SCNNode(geometry: SCNBox(width: 0.1, height: 0.1, length: 1.0, chamferRadius: 0))
        zAxis.position = SCNVector3.init(0, 0, 1)
        zAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        tagNode.addChildNode(xAxis)
        tagNode.addChildNode(yAxis)
        tagNode.addChildNode(zAxis)

        let tagPose = [tagNode.position.x, tagNode.position.y, tagNode.position.z, tagNode.orientation.x, tagNode.orientation.y, tagNode.orientation.z, tagNode.orientation.w]
        
        aprilTagDetectionDictionary[Int(tag.number)] = tagPose
    }
    
    /// Rotates an image clockwise by a given angle
    ///
    /// - Parameters:
    ///   - oldImage: the original image
    ///   - degrees: the angle by which the image is to be rotated
    /// - Returns: the rotated image
    func imageRotatedByDegrees(oldImage: UIImage, deg degrees: CGFloat) -> UIImage {
        //Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.width, height: oldImage.size.height))
        let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
        rotatedViewBox.transform = t
        let rotatedSize: CGSize = rotatedViewBox.frame.size
        //Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap: CGContext = UIGraphicsGetCurrentContext()!
        //Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        //Rotate the image context
        bitmap.rotate(by: (degrees * CGFloat.pi / 180))
        //Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: 1.0, y: -1.0)
        bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width / 2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    
    /// Updates the root to map transform if a tag currently being detected exists in the map
    ///
    /// - Parameter vertex: the tag vertex from firebase corresponding to the tag currently being detected
    func updateRootToMap(vertex: Map.Vertex) {
        let tagMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
        // TODO: hopefully this will be obsoleted by new data collection pipeline
        //tagMatrix = convertRosToIosCoordinates(matrix: tagMatrix)
        let tagNode = SCNNode(geometry: SCNBox(width: 0.165, height: 0.165, length: 0.05, chamferRadius: 0))
        tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
        tagNode.transform = tagMatrix
        mapNode.addChildNode(tagNode)
        tagNode.name = String("Tag_\(vertex.id)")
        computeRootToMap(tagId: vertex.id)
    }
    
    /// Converts from the coordinate system in firebase data to iOS coordinates
    ///
    /// - Parameter matrix: a transformation matrix in the firebase coordinate system
    /// - Returns: a transformation matrix in the iOS coordinate system
    func convertRosToIosCoordinates(matrix: SCNMatrix4) -> SCNMatrix4 {
        var mat = matrix.transpose()
        let rotate180aboutX = SCNMatrix4.init(m11: 1, m12: 0, m13: 0, m14: 0, m21: 0, m22: -1, m23: 0, m24: 0, m31: 0, m32: 0, m33: -1, m34: 0, m41: 0, m42: 0, m43: 0, m44: 1)
        let rotate90aboutZ = SCNMatrix4.init(m11: 0, m12: -1, m13: 0, m14: 0, m21: 1, m22: 0, m23: 0, m24: 0, m31: 0, m32: 0, m33: 1, m34: 0, m41: 0, m42: 0, m43: 0, m44: 1)
        mat = SCNMatrix4Mult(rotate180aboutX, mat)
        mat = SCNMatrix4Mult(rotate90aboutZ, mat)
        mat = mat.transpose()
        return mat
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

