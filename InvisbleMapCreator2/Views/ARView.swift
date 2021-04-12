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
       arView.delegate = self
       arView.scene = SCNScene()
       //arView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
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
       arView.delegate = self
    }
    override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       arView.session.pause()
    }
}

/*
extension ARView: ARSessionDelegate {
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        NavigationController.shared.trackingStatusChanged(session: session, camera: camera)
    }
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        NavigationController.shared.processNewARFrame(frame: frame)
    }
}
*/

extension ARView: ARSCNViewDelegate { // Protocol that handles content updates- essentially a visual representation of AR ession
    
    // ARSCNViewDelegate
    func sessionWasInterrupted(_ session: ARSession) {}
    func sessionInterruptionEnded(_ session: ARSession) {}
    func session(_ session: ARSession, didFailWithError error: Error) {}
    func session(_ session: ARSession, cameraDidChangeTrackingState
    camera: ARCamera) {}
    
}

// Use the ARSessionDelegate protocol to handle new frames
// Use the ARSessionObserver protocol - session function (cameraDidChangeTrackingState) will keep track of the ARSession lifecycle


// create searate class to handle interface of ar sesion
// defnie relevant function to record when new frame is available
// then trigger event
// class will manage creation of ar session then register the delegate then trigger events related to the ar session (e.g. new
// func sessionDidReceiveNewFrame print(frame.timestamp)
