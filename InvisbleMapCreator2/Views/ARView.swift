//
//  ARView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/19/21.
//

import Foundation
import ARKit
import SwiftUI

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
       let configuration = ARWorldTrackingConfiguration()
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
        AppController.shared.processNewARFrame(frame: frame)
    }
}

extension ARView: ARViewController {
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, sceneVar: (sceneTransVar: simd_float3x3, sceneQuatVar: simd_float4x4, scenePoseQuat: simd_quatf, scenePoseTranslation: SIMD3<Float>)) {
        DispatchQueue.main.async {
            let doKalman = false
            
            let aprilTagTracker = self.aprilTagDetectionDictionary[Int(tag.number), default: AprilTagTracker(self.arView, tagId: Int(tag.number))]
            self.aprilTagDetectionDictionary[Int(tag.number)] = aprilTagTracker

            // TODO: need some sort of logic to discard old detections.  One method that seems good would be to add some process noise (Q_k non-zero)
            let sceneTransVar = sceneVar.sceneTransVar
            let sceneQuatVar = sceneVar.sceneQuatVar
            let scenePoseQuat = sceneVar.scenePoseQuat
            let scenePoseTranslation = sceneVar.scenePoseTranslation
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
    
    func pinLocation(locationName: String) {
        DispatchQueue.main.async {
            // will save current box object in control
            var currentBoxNode: SCNNode = SCNNode()
            var currentTextNode: SCNNode = SCNNode()
            
            let box = SCNBox(width: 0.05, height: 0.2, length: 0.05, chamferRadius: 0)
            
            let text = SCNText(string: locationName, extrusionDepth: 0)
            
            let cameraNode = self.arView.pointOfView
            let boxNode = SCNNode()
            let textNode = SCNNode()
            boxNode.geometry = box
            boxNode.name = locationName
            textNode.geometry = text
            textNode.name = locationName + "Text"
            let boxPosition = SCNVector3(0,0,-0.6)
            let textPosition = SCNVector3(0,0.1,0)
            
            self.updatePositionAndOrientationOf(boxNode, withPosition: boxPosition, relativeTo: cameraNode!)
            self.updatePositionAndOrientationOf(textNode, withPosition: textPosition, relativeTo: boxNode)
            
            textNode.scale = SCNVector3(0.005,0.005,0.005)
            
            self.arView.scene.rootNode.addChildNode(boxNode)
            self.arView.scene.rootNode.addChildNode(textNode)
            
            currentBoxNode = boxNode
            currentTextNode = textNode
            
            //isMovingBox = true
        }
    }
    
    // move node position relative to another node's position.
    func updatePositionAndOrientationOf(_ node: SCNNode, withPosition position: SCNVector3, relativeTo referenceNode: SCNNode) {
        let referenceNodeTransform = matrix_float4x4(referenceNode.transform)
        
        var translationMatrix = matrix_identity_float4x4
        translationMatrix.columns.3.x = position.x
        translationMatrix.columns.3.y = position.y
        translationMatrix.columns.3.z = position.z
        
        let updatedTransform = matrix_multiply(referenceNodeTransform, translationMatrix)
        node.transform = SCNMatrix4(updatedTransform)
    }
}



/*
 func addBox(locationName: String) {
     let box = SCNBox(width: 0.05, height: 0.2, length: 0.05, chamferRadius: 0)
     
     let text = SCNText(string: locationName, extrusionDepth: 0)
     
     let cameraNode = sceneView.pointOfView
     let boxNode = SCNNode()
     let textNode = SCNNode()
     boxNode.geometry = box
     boxNode.name = locationName
     textNode.geometry = text
     textNode.name = locationName + "Text"
     let boxPosition = SCNVector3(0,0,-0.6)
     let textPosition = SCNVector3(0,0.1,0)
     
     updatePositionAndOrientationOf(boxNode, withPosition: boxPosition, relativeTo: cameraNode!)
     updatePositionAndOrientationOf(textNode, withPosition: textPosition, relativeTo: boxNode)
     
     textNode.scale = SCNVector3(0.005,0.005,0.005)
     
     sceneView.scene.rootNode.addChildNode(boxNode)
     sceneView.scene.rootNode.addChildNode(textNode)
     
     currentBoxNode = boxNode
     currentTextNode = textNode
     
     isMovingBox = true
 }
 
 */
