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
    
    public var arViewer: ARView?
    public var mapNavigator = MapNavigator()
    
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
                    let mapToGlobal = self.mapNavigator.map.computeMapPose(fromTag: Int(tag.number), withPosition: simd_float4x4(tag.poseData), relativeTo: cameraTransform)
                    if let mapToGlobal = mapToGlobal {
                        self.arViewer?.updateMapPose(to: mapToGlobal)
                    }
                
                case .FinishedNavigation:
                    self.arViewer?.playSound(type: "arrived")
                    self.mapNavigator.stopPathPlanning()
                    self.arViewer?.reset()  // stops the ping timer? check if it's needed
                  //  self.arViewer?.endSound()
                    print("navigation finished")
                
                case .LeaveMap(let mapFileName):  //need to fix after setting map to nil: somehow let the app know what map's location list to go back to from navigate screen after leaving map navigation
                  //  self.mapNavigator.resetMap()  //Question: what does setting map to nil do?
                    self.mapNavigator.stopPathPlanning() //in place of resetMap()?
                    self.arViewer?.reset()  // stops the ping timer
                    self.mapNavigator.detectTags = false  //in place of resetMap()?
                //    self.arViewer?.endSound()
                    print("leave map")
                
                case .PlanPath:
                    if let cameraNode = self.arViewer!.cameraNode {
                        let stops = self.mapNavigator.planPath(from: cameraNode.simdTransform.getTrans())
                        if let stops = stops {
                            self.arViewer!.renderGraph(fromStops: stops)
                        }
                    }
                
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

protocol MapsController {
    func deleteMap(mapID: String)
}
