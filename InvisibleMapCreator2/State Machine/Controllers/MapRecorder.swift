//
//  MapRecorder.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation
import ARKit
import Firebase
import FirebaseDatabase
import FirebaseStorage
import ARCoreCloudAnchors

class MapRecorder: MapRecorderController, ObservableObject {
    var currentFrameTransform: simd_float4x4 = simd_float4x4.init()
    /// Tracks last recorded frame to set map image to
    var lastRecordedFrame: ARFrame?
    /// Timestamp of frame that was last recorded
    var lastRecordedTimestamp: Double?
    /// Time interval at which pose, tag, location, and node data is recorded
    let recordInterval = 0.5
    /// Allows you to asynchronously run a job on a background thread
    let aprilTagQueue = DispatchQueue(label: "edu.occamlab.apriltagfinder", qos: DispatchQoS.userInitiated)
    var poseId: Int = 0
    var cloudAnchorData: [[[String: Any]]] = []
    var dirtyCloudAnchors = Set<String>()
    var poseData: [[String: Any]] = []
    var tagData: [[[String: Any]]] = []
    var locationData: [[String: Any]] = []
    var planeData: [UUID: [String: Any]] = [:]
    
    /// Tracks whether record data function is processing a frame to prevent queue from being overfilled
    var processingFrame: Bool = false
    /// Tracks any new locations
    var pendingLocation: (String, simd_float4x4)?
    /// Tracks any new location nodes
    var pendingNode: (SCNNode, UIImage, SCNNode)?
    /// Tracks current planes seen
    var planesSeen = Set<UUID>()
    
    /// Tracks whether the first tag has been found
    @Published var firstTagFound = false
    /// Tracks whether the user has asked for a tag to be recorded
    @Published var recordTag = false
    @Published var seesTag = false
    /// Tracks whether the user is recording a map
  //  @Published var recordMap = false
    
    /// Correct the orientation estimate such that the normal vector of the tag is perpendicular to gravity
    let snapTagsToVertical = true
    
    let f = imageToData()
    
    var firebaseRef: DatabaseReference!
    var firebaseStorage: Storage!
    var firebaseStorageRef: StorageReference!
    
    func initFirebase() {
        firebaseRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference()
        firebaseStorage = Storage.storage()
        firebaseStorageRef = firebaseStorage.reference()
    }
    
    init() {
        initFirebase()
    }
    
    private func setDirtyBitForCloudAnchors(_ garFrame: GARFrame) {
        let updatedCloudAnchors = garFrame.updatedAnchors.compactMap({$0.cloudIdentifier})
        dirtyCloudAnchors.formUnion(Set<String>(updatedCloudAnchors))
    }
    
    /// Record pose, tag, location, and node data after a specified period of time
    func recordData(cameraFrame: ARFrame, garFrame: GARFrame) {
        setDirtyBitForCloudAnchors(garFrame)
        if lastRecordedTimestamp == nil {
            lastRecordedTimestamp = cameraFrame.timestamp
            lastRecordedFrame = cameraFrame
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            recordTags(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            recordPlaneData(cameraFrame: cameraFrame, poseId: poseId)
            recordCloudAnchorData(cameraFrame: cameraFrame, garFrame: garFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            poseId += 1
            
            print("Running \(poseId)")
        }
        // Only record data if a specific period of time has passed and if a frame is not already being processed
        else if lastRecordedTimestamp! + recordInterval < cameraFrame.timestamp && !processingFrame {
            processingFrame = true
            lastRecordedTimestamp = lastRecordedTimestamp! + recordInterval
            lastRecordedFrame = cameraFrame
            
            recordPoseData(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            recordTags(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            recordPlaneData(cameraFrame: cameraFrame, poseId: poseId)
            recordCloudAnchorData(cameraFrame: cameraFrame, garFrame: garFrame, timestamp: lastRecordedTimestamp!, poseId: poseId)
            poseId += 1
            
            if let pendingLocation = pendingLocation {
                locationData.append(getLocationCoordinates(cameraFrame: cameraFrame, timestamp: lastRecordedTimestamp!, poseId: poseId, location: pendingLocation))
                AppController.shared.updateLocationListRequested(node: pendingNode!.0, picture: pendingNode!.1, textNode: pendingNode!.2, poseId: poseId)
                self.pendingLocation = nil
                self.pendingNode = nil
            }
            print("Running \(poseId)")
            processingFrame = false
        }
        else {
            return
        }
    }
    
    /// Add new planes and update existing planes
    func updatePlanes(planes: [ARPlaneAnchor]) {
        for plane in planes {
            planesSeen.insert(plane.identifier)
            planeData[plane.identifier] = getPlaneData(plane: plane)
        }
    }
    
    /// Cache the location and node data so that it is recorded the next time recordData is called and matches up with the corresponding poseId
    func cacheLocation(node: SCNNode, picture: UIImage, textNode: SCNNode) {
        pendingLocation = (node.name!, node.simdTransform)
        pendingNode = (node, picture, textNode)
    }

    /// Upload pose data, last image frame to Firebase under "maps" and "unprocessed_maps" nodes
    func sendToFirebase(mapName: String) {
        let mapImage = convertToUIImage(cameraFrame: lastRecordedFrame!)
        let mapId =  mapName + " " + String(lastRecordedTimestamp!).replacingOccurrences(of: ".", with: "")
        var planeDataList: [[String: Any]] = planeData.keys.map({planeData[$0]}) as! [[String: Any]]
        planeDataList.sort{
            ($0["id"] as! Int) < ($1["id"] as! Int)
        }
        
        let mapJsonFile: [String: Any] = ["map_id": mapId, "pose_data": poseData, "tag_data": tagData, "location_data": locationData, "plane_data": planeDataList, "cloud_data": cloudAnchorData]
        
        let folderPath = "rawMapData/" + String(describing: Auth.auth().currentUser!.uid)
        let imagePath = folderPath + "/" + mapId + ".jpg"
        let filePath = folderPath + "/" + mapId + ".json"
        
        // TODO: handle errors when failing to upload image and json file
        // TODO: let the user pick their image
        // Upload the last image capture to Firebase
        firebaseStorageRef.child(imagePath).putData(mapImage.jpegData(compressionQuality: 0)!, metadata: StorageMetadata(dictionary: ["contentType": "image/jpeg"]))
        
        var log = ""
        if JSONSerialization.isValidJSONObject(mapJsonFile) {
            if !JSONSerialization.isValidJSONObject(["map_id": mapId]) {
                log += "map_id \(mapId) is invalid\n"
            }
            if !JSONSerialization.isValidJSONObject(["pose_data": poseData]) {
                log += "pose_data is invalid:\n\(poseData)\n"
            }
            if !JSONSerialization.isValidJSONObject(["tag_data": tagData]) {
                log += "tag_data is invalid:\n\(tagData)\n"
            }
            if !JSONSerialization.isValidJSONObject(["location_data": locationData]) {
                log += "location_data is invalid:\n\(locationData)\n"
            }
            if !JSONSerialization.isValidJSONObject(["plane_data": planeDataList]) {
                log += "plane_data is invalid:\n\(planeDataList)\n"
            }
        }
        else {
            log += "mapJsonFile is valid"
        }
        print(log)
        try? firebaseStorageRef.child(folderPath + "/\(mapId) serialization error.json").putData(JSONSerialization.data(withJSONObject: ["log": log]))

        // Upload raw file json
        if let jsonData = try? JSONSerialization.data(withJSONObject: mapJsonFile, options: []) {
            firebaseStorageRef.child(filePath).putData(jsonData, metadata: StorageMetadata(dictionary: ["contentType": "application/json"])){ (metadata, error) in
                // Write to maps node in database
                self.firebaseRef.child("maps").child(String(describing: Auth.auth().currentUser!.uid)).child(mapId).setValue(["name": mapName, "image": imagePath, "raw_file": filePath])
                
                // Write to unprocessed maps node in database
                self.firebaseRef.child("unprocessed_maps").child(String(describing: Auth.auth().currentUser!.uid)).child(mapId).setValue(filePath)
            }
        }
    }
    
    /// Clear timestamp, pose, tag, and location data
    func clearData() {
        lastRecordedTimestamp = nil
        lastRecordedFrame = nil
        firstTagFound = false
        seesTag = false
        recordTag = false
    //recordMap = false
        poseId = 0
        poseData = []
        locationData = []
        tagData = []
        cloudAnchorData = []
        print("Clear data")
    }
}

// Helper functions that are not explicitly commands
extension MapRecorder {
    /// Append new pose data to list
    func recordPoseData(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
        poseData.append(getCameraCoordinates(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId))
    }
    
    @objc func recordCloudAnchorData(cameraFrame: ARFrame, garFrame: GARFrame, timestamp: Double, poseId: Int) {
        let anchors = garFrame.anchors.filter({ dirtyCloudAnchors.contains($0.cloudIdentifier ?? "") })
        cloudAnchorData.append(
            anchors.map(
                {[
                    // convert the pose so it is relative to the camera transform
                    "pose": (cameraFrame.camera.transform.inverse * $0.transform).toRowMajorOrder(),
                    "poseId": poseId,
                    "timestamp": timestamp,
                    "cloudIdentifier": $0.cloudIdentifier!
                ]}
           )
        )
    }
    
    /// Append new april tag data to list
    @objc func recordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
        let uiimage = cameraFrame.convertToUIImage()
        DispatchQueue.main.async {
            let arTags = self.getArTags(cameraFrame: cameraFrame, image: uiimage, timeStamp: timestamp, poseId: poseId)
            self.seesTag = !arTags.isEmpty
            if !self.firstTagFound && self.seesTag {
                self.firstTagFound = true
            }
            if self.recordTag && self.seesTag {
                self.tagData.append(arTags)
            }
            if !self.seesTag {
                self.recordTag = false
            }
        }
    }
    
    /// Append/Modify new plane data to list
    func recordPlaneData(cameraFrame: ARFrame, poseId: Int) {
        var planeInfo: [[String: Any]] = []
        for plane in planesSeen {
            guard let currentPlane = planeData[plane], let planePoseList = currentPlane["pose"] as? [Float], let planeId = currentPlane["id"] as? Int else {
                continue
            }
            let planePose = simd_float4x4(columns: (simd_float4(planePoseList[0], planePoseList[1], planePoseList[2], planePoseList[3]), simd_float4(planePoseList[4], planePoseList[5], planePoseList[6], planePoseList[7]), simd_float4(planePoseList[8], planePoseList[9], planePoseList[10], planePoseList[11]), simd_float4(planePoseList[12], planePoseList[13], planePoseList[14], planePoseList[15])))
            let transform = matrix_multiply(planePose, currentFrameTransform.inverse)
            planeInfo.append(["transform": [transform.columns.0.x, transform.columns.1.x, transform.columns.2.x, transform.columns.3.x, transform.columns.0.y, transform.columns.1.y, transform.columns.2.y, transform.columns.3.y, transform.columns.0.z, transform.columns.1.z, transform.columns.2.z, transform.columns.3.z, transform.columns.0.w, transform.columns.1.w, transform.columns.2.w, transform.columns.3.w], "id": planeId])
        }
        poseData[poseId]["planes"] = planeInfo
        planesSeen.removeAll()
    }
    
    /// Finds all april tags in the frame
    func getArTags(cameraFrame: ARFrame, image: UIImage, timeStamp: Double, poseId: Int) -> [[String:Any]] {
        let intrinsics = cameraFrame.camera.intrinsics.columns
        f.findTags(image, intrinsics.0.x, intrinsics.1.y, intrinsics.2.x, intrinsics.2.y)
        var tagArray: Array<AprilTags> = Array()
        var allTags: [[String:Any]] = []
        let numTags = f.getNumberOfTags()
        if numTags > 0 {
            for i in 0...f.getNumberOfTags()-1 {
                tagArray.append(f.getTagAt(i))
            }

            for i in 0...tagArray.count-1 {
                var tagDict:[String:Any] = [:]
                
                
                if ((AppController.shared.arViewer?.supportsLidar) != nil ? AppController.shared.arViewer?.supportsLidar as! Bool : false) {
                    let raycastPose: simd_float4x4? = AppController.shared.arViewer?.raycastTag(tag: tagArray[i], cameraTransform: cameraFrame.camera.transform, snapTagsToVertical: snapTagsToVertical)
                    
                    if raycastPose == nil {
                        continue
                    } else {
                        tagArray[i].poseData = raycastPose!.toRowMajorOrder()
                    }
                }
                
                AppController.shared.processNewTag(tag: tagArray[i], cameraTransform: cameraFrame.camera.transform, snapTagsToVertical: snapTagsToVertical) // Generates event to detect new tag
                
                var pose = tagArray[i].poseData
                
                if snapTagsToVertical {
                    var simdPose = simd_float4x4(rows: [simd_float4(Float(pose.0), Float(pose.1), Float(pose.2),Float(pose.3)), simd_float4(Float(pose.4), Float(pose.5), Float(pose.6), Float(pose.7)), simd_float4(Float(pose.8), Float(pose.9), Float(pose.10), Float(pose.11)), simd_float4(Float(pose.12), Float(pose.13), Float(pose.14), Float(pose.15))])
                    // convert from April Tags conventions to Apple's (TODO: could this be done in one rotation?)
                    simdPose = simdPose.rotate(radians: Float.pi, 0, 1, 0)
                    simdPose = simdPose.rotate(radians: Float.pi, 0, 0, 1)
                    let worldPose = cameraFrame.camera.transform*simdPose
                    // TODO: the alignY() seems to break things, possibly because we aren't properly remapping the covariance matrices.  I made an attempt to try to do this using LASwift, but ran into issues with conflicts with VISP3
                    let worldPoseFlat = worldPose.makeZFlat()//.alignY()
                    // back calculate what the camera pose should be so that the pose in the global frame is flat
                    var correctedCameraPose = cameraFrame.camera.transform.inverse*worldPoseFlat
                    // go back to April Tag Conventions
                    correctedCameraPose = correctedCameraPose.rotate(radians: Float.pi, 0, 0, 1)
                    correctedCameraPose = correctedCameraPose.rotate(radians: Float.pi, 0, 1, 0)
                    pose = correctedCameraPose.toRowMajorOrder()
                }
                tagDict["tag_id"] = tagArray[i].number
                tagDict["tag_pose"] = [pose.0, pose.1, pose.2, pose.3, pose.4, pose.5, pose.6, pose.7, pose.8, pose.9, pose.10, pose.11, pose.12, pose.13, pose.14, pose.15]
                tagDict["camera_intrinsics"] = [intrinsics.0.x, intrinsics.1.y, intrinsics.2.x, intrinsics.2.y]
                tagDict["tag_corners_pixel_coordinates"] = [tagArray[i].imagePoints.0, tagArray[i].imagePoints.1, tagArray[i].imagePoints.2, tagArray[i].imagePoints.3, tagArray[i].imagePoints.4, tagArray[i].imagePoints.5, tagArray[i].imagePoints.6, tagArray[i].imagePoints.7]
                tagDict["tag_position_variance"] = [tagArray[i].transVecVar.0, tagArray[i].transVecVar.1, tagArray[i].transVecVar.2]
                tagDict["tag_orientation_variance"] = [tagArray[i].quatVar.0, tagArray[i].quatVar.1, tagArray[i].quatVar.2, tagArray[i].quatVar.3]
                tagDict["timestamp"] = timeStamp
                tagDict["pose_id"] = poseId
                var jointCovarList: [Double] = []
                let mirror = Mirror(reflecting: tagArray[i].jointCovar)
                for child in mirror.children {
                    jointCovarList.append(child.value as! Double)
                }
                tagDict["joint_covar"] = jointCovarList
                allTags.append(tagDict)
            }
        }
        return allTags
    }
    
    /// Get dictionary of plane data
    func getPlaneData(plane: ARPlaneAnchor) -> [String: Any] {
        let planeId: Int
        if let id = planeData[plane.identifier]?["id"] as? Int {
            planeId = id
        } else {
            planeId = planeData.count
        }
        let planeTransform = plane.transform
        let boundaryVertices: [[Float]] = plane.geometry.boundaryVertices.map({[$0.x, $0.y, $0.z]})
        let planeDict: [String: Any] = ["pose": [planeTransform.columns.0.x, planeTransform.columns.1.x, planeTransform.columns.2.x, planeTransform.columns.3.x, planeTransform.columns.0.y, planeTransform.columns.1.y, planeTransform.columns.2.y, planeTransform.columns.3.y, planeTransform.columns.0.z, planeTransform.columns.1.z, planeTransform.columns.2.z, planeTransform.columns.3.z, planeTransform.columns.0.w, planeTransform.columns.1.w, planeTransform.columns.2.w, planeTransform.columns.3.w], "boundaries": boundaryVertices, "id": planeId]
        return planeDict
    }
    
    /// Get pose data (transformation matrix, time)
    func getCameraCoordinates(cameraFrame: ARFrame, timestamp: Double, poseId: Int) -> [String: Any] {
        let camera = cameraFrame.camera
        let cameraTransform = camera.transform
        currentFrameTransform = cameraTransform
        let scene = SCNMatrix4(cameraTransform)
        
        let cameraInfo: [String: Any] = ["pose": [scene.m11, scene.m12, scene.m13, scene.m14, scene.m21, scene.m22, scene.m23, scene.m24, scene.m31, scene.m32, scene.m33, scene.m34, scene.m41, scene.m42, scene.m43, scene.m44], "timestamp": timestamp, "id": poseId]
        
        return cameraInfo
    }
    
    /// Get location data
    func getLocationCoordinates(cameraFrame: ARFrame, timestamp: Double, poseId: Int, location: (String, simd_float4x4)) -> [String: Any] {
        let (locationName, nodeTransform) = location
        let finalTransform = currentFrameTransform.inverse * nodeTransform
        let locationInfo: [String: Any] = ["transform": [finalTransform.columns.0.x, finalTransform.columns.1.x, finalTransform.columns.2.x, finalTransform.columns.3.x, finalTransform.columns.0.y, finalTransform.columns.1.y, finalTransform.columns.2.y, finalTransform.columns.3.y, finalTransform.columns.0.z, finalTransform.columns.1.z, finalTransform.columns.2.z, finalTransform.columns.3.z, finalTransform.columns.0.w, finalTransform.columns.1.w, finalTransform.columns.2.w, finalTransform.columns.3.w], "timestamp": timestamp, "pose_id": poseId, "name": locationName]
        
        return locationInfo
    }
    
    /// Convert ARFrame to a UIImage
    func convertToUIImage(cameraFrame: ARFrame) -> (UIImage) {
        let pixelBuffer = cameraFrame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let uiImage = UIImage(cgImage: cgImage!)
        return uiImage
    }
}
