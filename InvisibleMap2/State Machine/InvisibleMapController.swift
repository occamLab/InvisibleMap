//
//  InvisibleMapController.swift
//  InvisibleMap2
//
//  Created by tad on 9/22/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit

class InvisibleMapController: AppController {
    public static var shared = InvisibleMapController()
    private var state = InvisibleMapAppState.initialState
    
    // Various controllers for handling commands
    public var mapNavigator = MapNavigator()
    public var arViewer: ARView?
    var navigateViewer: NavigateViewController?
    
    
    func initialize() {
        InvisibleMapController.shared.arViewer?.initialize()
        InvisibleMapController.shared.arViewer?.setupPing()
    }
    
    func process(commands: [InvisibleMapAppState.Command]) {
        for command in commands {
            switch (command) {
                case .LoadMap(let mapFileName):
                    FirebaseManager.createMap(from: mapFileName) { newMap in
                         self.mapNavigator.map = newMap
                    }
                
                case .StartPath(let locationType, let Id):
                    // check: if ping was not invalidated, stop it before starting navigation?
                // Question: ping sound from previous navigation to a POI continues for navigation to another POI (navmap -> selectpath -> navmap (ping starts before detecting first tag)
                    self.mapNavigator.locationType = locationType
                    if locationType == "tag" {
                        self.mapNavigator.endpointTagId = Id
                        self.mapNavigator.scheduledPathPlanningTimer()
                        self.arViewer?.scheduledPingTimer()
                    }
                    if locationType == "waypoint" {
                        self.mapNavigator.endpointLocationId = Id
                        self.mapNavigator.scheduledPathPlanningTimer()
                        self.arViewer?.scheduledPingTimer()
                    }
                
                
                case .UpdatePoseVIO(let cameraFrame):
                    self.mapNavigator.updateTags(from: cameraFrame)
                
                case .UpdatePoseTag(let tag, let cameraTransform):
                    let mapToGlobal = self.mapNavigator.map?.computeMapPose(fromTag: Int(tag.number), withPosition: simd_float4x4(tag.poseData), relativeTo: cameraTransform)
                    if let mapToGlobal = mapToGlobal {
                        self.arViewer?.updateMapPose(to: mapToGlobal)
                    }
                
                case .FinishedNavigation:
                    self.arViewer?.playSound(type: "arrived")
                    self.mapNavigator.stopPathPlanning()
                    self.arViewer?.reset()  // stops the ping timer? check if it's needed
                    print("navigation finished")
                
                case .LeaveMap(let mapFileName):
                    self.mapNavigator.resetMap() // destroys the map
                    self.arViewer?.reset()  // stops the ping timer
                process(commands: [.LoadMap(mapFileName: mapFileName)])
                    print("leave map")
                
                case .PlanPath:
                if let mapNode = arViewer?.mapNode, let cameraNode = arViewer?.cameraNode {
                    let cameraPositionRelativeToMapNode = cameraNode.convertPosition(SCNVector3(), to: mapNode)
                    let stops = self.mapNavigator.planPath(from: simd_float3(cameraPositionRelativeToMapNode.x, cameraPositionRelativeToMapNode.y, cameraPositionRelativeToMapNode.z))
                        if let stops = stops {
                            self.arViewer!.renderGraph(fromStops: stops)
                        }
                    }
                
                // NavigateViewer commands
                case .UpdateInstructionText:
                    navigateViewer?.updateInstructionText()
                
                // TODO: Add functionality for these
                case .GetNewWaypoint:
                    continue
                case .EditMap:
                    continue
            }
        }
    }
    
    func process(event: InvisibleMapAppState.Event) {
        process(commands: state.handle(event: event))
    }
}

protocol NavigateViewController {
    // Commands that impact the navigate map view UI
    func updateInstructionText()
}

