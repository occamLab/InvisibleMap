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
                        self.mapNavigator.endpointTagKey = Id
                        self.mapNavigator.scheduledPathPlanningTimer()
                        self.arViewer?.scheduledPingTimer()
                    }
                    if locationType == "waypoint" {
                        self.mapNavigator.endpointWaypointKey = Id
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
                    self.arViewer?.arrivedSound()
                    self.arViewer?.stopPing()
                    self.mapNavigator.stopPathPlanning()
                    print("navigation finished")
                
                case .LeaveMap(let mapFileName):
                    self.arViewer?.reset()
                    self.mapNavigator.resetMap() // destroys the map
                    process(commands: [.LoadMap(mapFileName: mapFileName)])  // loads the map (with its tag locations and POIs) that the user just left
                    print("leave map")
                
                case .PlanPath:
                if let cameraNode = arViewer?.cameraNode {
                        let cameraPos = arViewer!.convertNodeOrigintoMapFrame(node: cameraNode)
                        let stops = self.mapNavigator.planPath(from: simd_float3(cameraPos!.x, cameraPos!.y, cameraPos!.z))
                            if let stops = stops {
                                self.arViewer!.renderGraph(fromStops: stops)
                            }
                        }
                
                // NavigateViewer commands
                case .UpdateInstructionText:
                    navigateViewer?.updateInstructionText()
                    print("updated instruction text")
                
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

