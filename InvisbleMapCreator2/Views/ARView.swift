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
        arView.session.delegate = self
        arView.scene = SCNScene()
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
        print("New Frame")
    }
}
