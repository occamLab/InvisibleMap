//
//  ARView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/19/21.
//

import Foundation
import ARKit
import SwiftUI
import ARCoreCloudAnchors

// ARViewIndicator
struct ARViewIndicator: UIViewControllerRepresentable {
   typealias UIViewControllerType = ARView
   
   func makeUIViewController(context: Context) -> ARView {
      return ARView()
   }
   func updateUIViewController(_ uiViewController:
   ARViewIndicator.UIViewControllerType, context:
   UIViewControllerRepresentableContext<ARViewIndicator>) { }
}

class ARView: UIViewController {
    var aprilTagDetectionDictionary = Dictionary<Int, AprilTagTracker>()
    let memoryChecker : MemoryChecker = MemoryChecker()
    let configuration = ARWorldTrackingConfiguration()
    var garSession: GARSession?
    // Create an AR view
    var arView: ARSCNView {
       return self.view as! ARSCNView
    }
    
    override func loadView() {
      self.view = ARSCNView(frame: .zero)
    }
    
    // Load, assign a delegate, and create a scene
    override func viewDidLoad() {
        super.viewDidLoad()
        arView.session.delegate = self
        arView.scene = SCNScene()
        AppController.shared.arViewer = self
        configuration.planeDetection = [.horizontal, .vertical]
        //if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
        //    configuration.sceneReconstruction = .mesh
        //}
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
        startGARSession()
    }
    override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       arView.session.pause()
    }
    
    private func startGARSession() {
        do {
            garSession = try GARSession(apiKey: garAPIKey, bundleIdentifier: nil)
            var error: NSError?
            let configuration = GARSessionConfiguration()
            configuration.cloudAnchorMode = .enabled
            garSession?.setConfiguration(configuration, error: &error)
            garSession?.delegate = self
            print("gar set configuration error \(error)")
        } catch {
            print("failed to create GARSession")
        }
    }
}

extension ARView: GARSessionDelegate {
    /// This function is called whenever a cloud anchor has been successfully hosted by Google's ARCore library.  This gives our app a chance to store the newly created anchor in various datastructures or databases.
    /// - Parameters:
    ///   - session: the GAR session associated with the anchor
    ///   - garAnchor: the GARAnchor itself (this will have the cloudIdentifier, which is the way to refer to this anchor across session, as well as the anchor identifier, which s the way to refer to the anchor within this session)
    func session(_ session: GARSession, didHost garAnchor:GARAnchor) {
        guard let cloudIdentifier = garAnchor.cloudIdentifier else {
            return
        }
        do {
            // we resolve right away so we can start to include these in the data
            try garSession?.resolveCloudAnchor(cloudIdentifier)
        } catch {
            
        }
    }
    
    func session(_ session: GARSession, didFailToHost garAnchor: GARAnchor) {

    }
    
    func session(_ session: GARSession, didResolve anchor:GARAnchor) {
        print("did resolve cloud anchor")
    }
}

extension ARView: ARSessionDelegate {
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        //NavigationController.shared.trackingStatusChanged(session: session, camera: camera)
    }
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        do {
            if let garFrame = try garSession?.update(frame) {
                AppController.shared.processNewARFrame(frame: frame, garFrame: garFrame)
            }
        } catch {
        }
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // let newAnchors = anchors.compactMap({$0 as? ARPlaneAnchor})
        // AppController.shared.processPlanesUpdated(planes: newAnchors)
    }
    
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // let updatedAnchors = anchors.compactMap({$0 as? ARPlaneAnchor})
        // AppController.shared.processPlanesUpdated(planes: updatedAnchors)
    }
}

extension ARView: ARViewController {
    func hostCloudAnchor() {
        guard let currentFrame = arView.session.currentFrame else {
            return
        }
        do {
            var anchorMatrix = matrix_identity_float4x4
            anchorMatrix.columns.3 = currentFrame.camera.transform.columns.3
            try self.garSession?.hostCloudAnchor(ARAnchor(transform: anchorMatrix))
        } catch {
            
        }
    }
    
    /// Transforms the AprilTag position into world frame
    var supportsLidar: Bool {
        get {
            return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        }
    }
    
    func tagPoseToWorld(tagPose: simd_float4x4, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) -> simd_float4x4 {
        let aprilTagToARKit = simd_float4x4(diagonal:simd_float4(1, -1, -1, 1))
        // convert from April Tag's convention to ARKit's convention
        let tagPoseARKit = aprilTagToARKit*tagPose
        // project into world coordinates
        var scenePose = cameraTransform*tagPoseARKit

        if snapTagsToVertical {
            scenePose = scenePose.makeZFlat().alignY()
        }
        
        return scenePose
    }
    
    /// Adds or updates a tag node when a tag is detected
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) {
        DispatchQueue.main.async {
            let pose = tag.poseData

            let originalTagPose = simd_float4x4(rows: [simd_float4(Float(pose.0), Float(pose.1), Float(pose.2),Float(pose.3)), simd_float4(Float(pose.4), Float(pose.5), Float(pose.6), Float(pose.7)), simd_float4(Float(pose.8), Float(pose.9), Float(pose.10), Float(pose.11)), simd_float4(Float(pose.12), Float(pose.13), Float(pose.14), Float(pose.15))])
            
            let transVar = simd_float3(Float(tag.transVecVar.0), Float(tag.transVecVar.1), Float(tag.transVecVar.2))
            let quatVar = simd_float4(x: Float(tag.quatVar.0), y: Float(tag.quatVar.1), z: Float(tag.quatVar.2), w: Float(tag.quatVar.3))
            
            let scenePose = self.tagPoseToWorld(tagPose: originalTagPose, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
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
            let aprilTagTracker = self.aprilTagDetectionDictionary[Int(tag.number), default: AprilTagTracker(self.arView, tagId: Int(tag.number))]
            self.aprilTagDetectionDictionary[Int(tag.number)] = aprilTagTracker

            // TODO: need some sort of logic to discard old detections.  One method that seems good would be to add some process noise (Q_k non-zero)
            aprilTagTracker.updateTagPoseMeans(id: Int(tag.number), detectedPosition: scenePoseTranslation, detectedPositionVar: sceneTransVar, detectedQuat: scenePoseQuat, detectedQuatVar: sceneQuatVar, doKalman: doKalman)

            let tagNode: SCNNode
            if let existingTagNode = self.arView.scene.rootNode.childNode(withName: "Tag_\(String(tag.number))", recursively: false)  {
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
                self.arView.scene.rootNode.addChildNode(tagNode)
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

        let originalTagPose = simd_float4x4(rows: [simd_float4(Float(pose.0), Float(pose.1), Float(pose.2),Float(pose.3)), simd_float4(Float(pose.4), Float(pose.5), Float(pose.6), Float(pose.7)), simd_float4(Float(pose.8), Float(pose.9), Float(pose.10), Float(pose.11)), simd_float4(Float(pose.12), Float(pose.13), Float(pose.14), Float(pose.15))])
        
        let scenePose = tagPoseToWorld(tagPose: originalTagPose, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
        
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
            let textPosition = SCNVector3(0,0.1,0)
            
            self.updatePositionAndOrientationOf(boxNode, withPosition: boxPosition, relativeTo: cameraNode!)
            self.updatePositionAndOrientationOf(textNode, withPosition: textPosition, relativeTo: boxNode)
            
            textNode.scale = SCNVector3(0.005,0.005,0.005)
            
            self.arView.scene.rootNode.addChildNode(boxNode)
            self.arView.scene.rootNode.addChildNode(textNode)
            
            let snapshot = self.arView.snapshot()
            AppController.shared.cacheLocationRequested(node: boxNode, picture: snapshot, textNode: textNode)
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
}
