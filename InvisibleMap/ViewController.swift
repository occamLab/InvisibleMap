//
//  ViewController.swift
//  InvisibleMap
//
//  Created by Occam Lab on 7/30/18.
//  Copyright © 2018 Occam Lab. All rights reserved.
//

import UIKit
import ARKit
import GLKit
import Firebase
import FirebaseDatabase
import FirebaseStorage

extension SCNMatrix4 {
//    public func transpose(m: SCNMatrix4) -> SCNMatrix4 {
//        return SCNMatrix4(
//            m11: m.m11, m12: m.m21, m13: m.m31, m14: m.m41,
//            m21: m.m12, m22: m.m22, m23: m.m32, m24: m.m42,
//            m31: m.m13, m32: m.m23, m33: m.m33, m34: m.m43,
//            m41: m.m14, m42: m.m24, m43: m.m34, m44: m.m44)
//    }
    public func transpose() -> SCNMatrix4 {
        return SCNMatrix4(
            m11: m11, m12: m21, m13: m31, m14: m41,
            m21: m12, m22: m22, m23: m32, m24: m42,
            m31: m13, m32: m23, m33: m33, m34: m43,
            m41: m14, m42: m24, m43: m34, m44: m44)
    }
}

class ViewController: UIViewController {
    
    var storageRef: StorageReference!
    var myMap: Map!
    var jsonMap: NSDictionary!
    var mapNode: SCNNode!
    var cameraNode: SCNNode!
    var tagDict: Dictionary<Int, Array<Float>>!
    var aprilTagDetectionDictionary = Dictionary<Int, Array<Float>>()
    var tag_dictionary = [Int:ViewController.Map.Vertex]()
    var waypointDictionary = [Int:ViewController.Map.WaypointVertex]()
    var waypointKeyDictionary = [String:Int]()
    var count: Int = 0
    let distanceToWaypoint: Float = 1.5
    let tagTiltMin: Float = 0.09
    let tagTiltMax: Float = 0.91
    var mapFileName: String = ""
    
    @IBOutlet var sceneView: ARSCNView!
    
    var tagFinderTimer = Timer()
    

    let f = imageToData()
    var isProcessingFrame = false
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.invisiblemap", qos: DispatchQoS.userInitiated)
    
    func createMapNode() {
        mapNode = SCNNode()
        mapNode.position = SCNVector3(x: 0, y: 0, z: 0)
        sceneView.scene.rootNode.addChildNode(mapNode)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print(mapFileName)
        // Do any additional setup after loading the view, typically from a nib.
        startSession()
        createMap()

    }
    
    /// Initialize the ARSession
    func startSession() {
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
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
                        self.store_tagvertex_in_dictionary()
                        self.store_waypointvertex_in_dictionary()

                    } catch let error {
                        print(error)
                    }
                }
            }
        }
    }
    
    func store_waypointvertex_in_dictionary(){
        var count: Int = 0
        for vertex in myMap.waypointsVertices{
            waypointDictionary[count] = vertex
            waypointKeyDictionary[vertex.id] = count
            var waypointMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
            waypointMatrix = convertRosToIosCoordinates(matrix: waypointMatrix)
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
    
    func detectNearbyWaypoints(){
        let curr_pose = cameraNode.position
        for count in waypointDictionary.keys{
            if mapNode.childNode(withName: "Waypoint_" + (waypointDictionary[count]?.id)!, recursively: false) != nil{
                let waypoint_pose_map = mapNode.childNode(withName: "Waypoint_" + (waypointDictionary[count]?.id)!, recursively: false)?.position
                let waypoint_pose = sceneView.scene.rootNode.convertPosition(waypoint_pose_map!, from: mapNode)
                let distanceToCurrPose = sqrt(pow((waypoint_pose.x - curr_pose.x),2) + pow((waypoint_pose.y - curr_pose.y),2) + pow((waypoint_pose.z - curr_pose.z),2))
                if distanceToCurrPose < distanceToWaypoint{
                    let announcement: String = (waypointDictionary[count]?.id)! + " is " + String(distanceToCurrPose) + " away."
                    let utterance = AVSpeechUtterance(string: announcement)
                    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                    let synth = AVSpeechSynthesizer()
                    synth.speak(utterance)
            }
            
            }
        }
    }
    
    
    func store_tagvertex_in_dictionary(){
        for vertex in myMap.tagVertices{
            tag_dictionary[vertex.id] = vertex
            var tagMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
            tagMatrix = convertRosToIosCoordinates(matrix: tagMatrix)
            let tagNode = SCNNode(geometry: SCNBox(width: 0.165, height: 0.165, length: 0.05, chamferRadius: 0))
            tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
            tagNode.transform = tagMatrix
            mapNode.addChildNode(tagNode)
            tagNode.name = String("Tag_\(vertex.id)")

        }
    }
    
    
    
    func scheduledLocalizationTimer() {
        tagFinderTimer.invalidate()
        tagFinderTimer = Timer()
        tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateLandmarks), userInfo: nil, repeats: true)

    }
    
    @IBAction func enterMap(_ sender: UIButton) {
        if sender.currentTitle == "Enter Map" {
            sender.setTitle("Exit Map", for: .normal)
            scheduledLocalizationTimer()
            
        } else {
            sender.setTitle("Enter Map", for: .normal)
            tagFinderTimer.invalidate()
            tagFinderTimer = Timer()
        }
        
    }
    
    @objc func updateLandmarks() {
        if isProcessingFrame {
            return
        }
        isProcessingFrame = true
        //let (image, time) = getVideoFrames()
        //let rotatedImage = imageRotatedByDegrees(oldImage: image, deg: 90)
        aprilTagQueue.async {
            print(self.count)
            let (image, time) = self.getVideoFrames()
            let rotatedImage = self.imageRotatedByDegrees(oldImage: image, deg: 90)
            self.checkTagDetection(rotatedImage: rotatedImage, timestamp: time)
            self.detectNearbyWaypoints()
            self.isProcessingFrame = false
            self.count += 1
        }
       
       

    }
    
    /// Get video frames.
    func getVideoFrames() -> (UIImage, Double) {
        let cameraFrame = sceneView.session.currentFrame
        let cameraTransform = sceneView.session.currentFrame?.camera.transform
        let scene = SCNMatrix4(cameraTransform!)
        if sceneView.scene.rootNode.childNode(withName: "camera", recursively: false) == nil {
            cameraNode = SCNNode()
            cameraNode.transform = scene
            cameraNode.name = "camera"
            sceneView.scene.rootNode.addChildNode(cameraNode)
        } else {
            cameraNode.transform = scene
        }
        let stampedTime = cameraFrame?.timestamp
        
        // Convert ARFrame to a UIImage
        let pixelBuffer = cameraFrame?.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer!)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let uiImage = UIImage(cgImage: cgImage!)
        return (uiImage, stampedTime!)
    }
    
    /// Check if tag is detected
    func checkTagDetection(rotatedImage: UIImage, timestamp: Double) {
        let intrinsics = sceneView.session.currentFrame?.camera.intrinsics.columns
        f.findTags(rotatedImage, intrinsics!.1.y, intrinsics!.0.x, intrinsics!.2.y, intrinsics!.2.x)
        var tagArray: Array<AprilTags> = Array()
        let numTags = f.getNumberOfTags()
        if numTags > 0 {
            for i in 0...f.getNumberOfTags()-1 {
                tagArray.append(f.getTagAt(i))
            }
            for i in 0...tagArray.count-1 {
                addTagDetectionNode(tag: tagArray[i])
                //print("tag detected in frame:", tagArray)
                if tag_dictionary[Int(tagArray[i].number)] != nil {
                    updateRootToMap(vertex: tag_dictionary[Int(tagArray[i].number)]!)

                }
            }
            
        }
    }
    
    /// Check Tag Axis
    func checkTagAxis(tagNum: String, rootTagNode: SCNNode) -> Bool {
        //let tagZinRoot = sceneView.scene.rootNode.childNode(withName: "Tag_\(tagNum)", recursively: false)?.convertVector(SCNVector3(0,0,1), to: sceneView.scene.rootNode)
        let tagZinRoot = rootTagNode.convertVector(SCNVector3(0,0,1), to: sceneView.scene.rootNode)
        let tagvector = SCNVector3ToGLKVector3(tagZinRoot)
        let gravityvector = GLKVector3Make(0.0, 1.0, 0.0)
        let dotproduct = GLKVector3DotProduct(tagvector,gravityvector)
        if tagTiltMin < abs(dotproduct) && abs(dotproduct) < tagTiltMax{
            print("Not Used")
            print(dotproduct)
            return false
        }else{
            print("Used")
            print(dotproduct)
            return true
        }
    }
    
    
    /// Add Tag node when tag is detected
    func addTagDetectionNode(tag: AprilTags) {
        let pose = tag.poseData
        var poseMatrix = SCNMatrix4.init(m11: Float(pose.0), m12: Float(pose.1), m13: Float(pose.2), m14: Float(pose.3), m21: Float(pose.4), m22: Float(pose.5), m23: Float(pose.6), m24: Float(pose.7), m31: Float(pose.8), m32: Float(pose.9), m33: Float(pose.10), m34: Float(pose.11), m41: Float(pose.12), m42: Float(pose.13), m43: Float(pose.14), m44: Float(pose.15))
        let rotate180aboutX = SCNMatrix4.init(m11: 1, m12: 0, m13: 0, m14: 0, m21: 0, m22: -1, m23: 0, m24: 0, m31: 0, m32: 0, m33: -1, m34: 0, m41: 0, m42: 0, m43: 0, m44: 1)
        let rotate90aboutZ = SCNMatrix4.init(m11: 0, m12: -1, m13: 0, m14: 0, m21: 1, m22: 0, m23: 0, m24: 0, m31: 0, m32: 0, m33: 1, m34: 0, m41: 0, m42: 0, m43: 0, m44: 1)
        poseMatrix = SCNMatrix4Mult(rotate180aboutX, poseMatrix)
        poseMatrix = SCNMatrix4Mult(rotate90aboutZ, poseMatrix)
        // SCNMatrix4 Transformations are stored transposed [R' 0; t' 1] from poseMatrix
        poseMatrix = poseMatrix.transpose()
        let num = String(tag.number)
        
       //updateCameraCoordinates()
        let rootTag = cameraNode.convertTransform(poseMatrix, to: sceneView.scene.rootNode)
        let rootTagNode = SCNNode()
        rootTagNode.transform = rootTag
        if sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false) == nil {
            rootTagNode.geometry = SCNBox(width: 0.165, height: 0.165, length: 0.05, chamferRadius: 0)
            //let rootTagNode = SCNNode(geometry: SCNBox(width: 0.165, height: 0.165, length: 0.05, chamferRadius: 0))
            //rootTagNode.transform = rootTag
            rootTagNode.name = "Tag_\(num)"
            rootTagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
            sceneView.scene.rootNode.addChildNode(rootTagNode)
        } else {
            //let oldTransform = sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false)?.transform
            //sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false)?.transform = rootTag
            if checkTagAxis(tagNum: num, rootTagNode: rootTagNode){
                sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false)?.transform = rootTag
            }

            
        }
        let xAxis = SCNNode(geometry: SCNBox(width: 1.0, height: 0.1, length: 0.1, chamferRadius: 0))
        xAxis.position = SCNVector3.init(1, 0, 0)
        xAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        let yAxis = SCNNode(geometry: SCNBox(width: 0.1, height: 1.0, length: 0.1, chamferRadius: 0))
        yAxis.position = SCNVector3.init(0, 1, 0)
        yAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        let zAxis = SCNNode(geometry: SCNBox(width: 0.1, height: 0.1, length: 1.0, chamferRadius: 0))
        zAxis.position = SCNVector3.init(0, 0, 1)
        zAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false)?.addChildNode(xAxis)
        sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false)?.addChildNode(yAxis)
        sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false)?.addChildNode(zAxis)

        
        
        let quat2 = sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false)?.orientation
        let trans2 = sceneView.scene.rootNode.childNode(withName: "Tag_\(num)", recursively: false)?.position
        let tagPose = [trans2?.x, trans2?.y, trans2?.z, quat2?.x, quat2?.y, quat2?.z, quat2?.w]
        
        aprilTagDetectionDictionary[Int(tag.number)] = tagPose as? [Float]
    }
    
    /// Get pose data (transformation matrix, time) and send to ROS.
    func updateCameraCoordinates() {
        let camera = sceneView.session.currentFrame?.camera
        let cameraTransform = camera?.transform
        let scene = SCNMatrix4(cameraTransform!)
        if sceneView.scene.rootNode.childNode(withName: "camera", recursively: false) == nil {
            cameraNode = SCNNode()
            cameraNode.transform = scene
            cameraNode.name = "camera"
            sceneView.scene.rootNode.addChildNode(cameraNode)
        } else {
            cameraNode.transform = scene
        }
        
    }

    
    /// Get the camera intrinsics to send to ROS
    func getCameraIntrinsics() -> Data {
        let camera = sceneView.session.currentFrame?.camera
        let intrinsics = camera?.intrinsics
        let columns = intrinsics?.columns
        let res = camera?.imageResolution
        let width = res?.width
        let height = res?.height
        
        return String(format: "%f,%f,%f,%f,%f,%f,%f", columns!.0.x, columns!.1.y, columns!.2.x, columns!.2.y, columns!.2.z, width!, height!).data(using: .utf8)!
    }
    
    /// Rotates an image clockwise
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
    
    
    ///
    ///
    /// - Parameter vertex:
    func updateRootToMap(vertex: Map.Vertex) {
        var tagMatrix = SCNMatrix4Translate(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeWithQuaternion(GLKQuaternionMake(vertex.rotation.x, vertex.rotation.y, vertex.rotation.z, vertex.rotation.w))), vertex.translation.x, vertex.translation.y, vertex.translation.z)
        tagMatrix = convertRosToIosCoordinates(matrix: tagMatrix)
        let tagNode = SCNNode(geometry: SCNBox(width: 0.165, height: 0.165, length: 0.05, chamferRadius: 0))
        tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
        tagNode.transform = tagMatrix
        mapNode.addChildNode(tagNode)
        tagNode.name = String("Tag_\(vertex.id)")
        computeRootToMap(tagId: vertex.id)
    }
    
    /// Convert firebase coordinates to iOS coordinates
    func convertRosToIosCoordinates(matrix: SCNMatrix4) -> SCNMatrix4 {
        var mat = matrix.transpose()
        let rotate180aboutX = SCNMatrix4.init(m11: 1, m12: 0, m13: 0, m14: 0, m21: 0, m22: -1, m23: 0, m24: 0, m31: 0, m32: 0, m33: -1, m34: 0, m41: 0, m42: 0, m43: 0, m44: 1)
        let rotate90aboutZ = SCNMatrix4.init(m11: 0, m12: -1, m13: 0, m14: 0, m21: 1, m22: 0, m23: 0, m24: 0, m31: 0, m32: 0, m33: 1, m34: 0, m41: 0, m42: 0, m43: 0, m44: 1)
        mat = SCNMatrix4Mult(rotate180aboutX, mat)
        mat = SCNMatrix4Mult(rotate90aboutZ, mat)
        mat = mat.transpose()
        return mat
    }
    
    /// Compute root to map
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
