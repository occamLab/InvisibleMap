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
    //public var arView = ARView()
    public var arViewer: ARView?
    var navigateViewer: NavigateViewController?
    
    // state of whether the current app is in the process of leaving the app
    var exitingMap = false
    
    func initialize() {
        InvisibleMapController.shared.arViewer?.initialize()
        InvisibleMapController.shared.arViewer?.setupPing()
    }
    
    func process(commands: [InvisibleMapAppState.Command]) {
        for command in commands {
            //print("last command: \(command)")
            switch (command) {
                case .LoadMap(let mapFileName):
                print("loading select path view")
                    FirebaseManager.createMap(from: mapFileName) { newMap in
                         self.mapNavigator.map = newMap
                    }
                
                case .StartPath(let locationType, let Id):
                    // check: if ping was not invalidated, stop it before starting navigation?
                // Question: ping sound from previous navigation to a POI continues for navigation to another POI (navmap -> selectpath -> navmap (ping starts before detecting first tag)
                 //   self.arViewer?.session.run(ARWorldTrackingConfiguration())
                
                    // need to re-initialize NavigateGlobalState which is a property of NavigateGlobalStateSingleton to update instructions for new ARSessions
                    NavigateGlobalStateSingleton.shared = NavigateGlobalState()
                
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
                
                case .PrepareToLeaveMap(let mapFileName):
                    // stops processing frame in AR Session
                    self.exitingMap = true
                    // pauses the app for a split second
                    let timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { (timer) in
                        InvisibleMapController.shared.process(event: .ReadyToLeaveMap(mapFileName: mapFileName))
                        }

                    //let secondsToDelay = 2.0
                    /*perform(#selector(mapNavigator.waitBeforeLeavingMap(mapFileName: mapFileName)), with: nil, afterDelay: secondsToDelay)*/
                    print("preparing to leave map - stop processing frame")
                
                case .LeaveMap(let mapFileName):
                    self.arViewer?.resetNavigatingSession()
                    self.mapNavigator.resetMap() // destroys the map
                    self.exitingMap = false
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
                case .GetNewEndpoint:
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

