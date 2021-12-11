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
    private var state = AppState.initialState
    
    public var arViewer: ARView?
    public var mapNavigator = MapNavigator()
    
    func initialize() {
        InvisibleMapController.shared.arViewer?.initialize()
        InvisibleMapController.shared.arViewer?.setupPing()
    }
    
    func process(commands: [AppState.Command]) {
        for command in commands {
            switch (command) {
                case .LoadMap(let mapFileName):
                    FirebaseManager.createMap(from: mapFileName) { newMap in
                         self.mapNavigator.map = newMap
                    }
                case .StartPath(let tagId):
                    self.mapNavigator.endpointTagId = tagId
                    self.mapNavigator.scheduledPathPlanningTimer()
                    self.arViewer?.scheduledPingTimer()
                case .UpdatePoseVIO(let cameraFrame):
                    self.mapNavigator.updateTags(from: cameraFrame)
                case .UpdatePoseTag(let tag, let cameraTransform):
                    let rootToMap = self.mapNavigator.map.computeRootToMap(fromTag: Int(tag.number), withPosition: simd_float4x4(tag.poseData), relativeTo: cameraTransform)
                    if let rootToMap = rootToMap {
                        self.arViewer?.updateRootToMap(to: rootToMap)
                    }
                case .FinishedNavigation:
                    self.arViewer?.playSound(type: "arrived")
                    self.mapNavigator.stopPathPlanning()
                case .LeaveMap:
                    self.mapNavigator.resetMap()
                    self.arViewer?.reset()
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
    
    func process(event: AppState.Event) {
        process(commands: state.handle(event: event))
    }
}
