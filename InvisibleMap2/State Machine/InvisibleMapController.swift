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
                    self.mapNavigator.map = FirebaseManager.createMap(from: mapFileName)
                case .StartPath(let tagId):
                    self.mapNavigator.endpointTagId = tagId
                    self.mapNavigator.scheduledPathPlanningTimer()
                case .UpdatePoseVIO(let cameraFrame):
                    self.mapNavigator.updateTags(from: cameraFrame)
                case .UpdatePoseTag(let tag, let cameraTransform):
                    let rootToMap = self.mapNavigator.map.computeRootToMap(fromTag: tag.number, withPosition: tag.poseData, relativeTo: cameraTransform)
                    if let rootToMap = rootToMap {
                        self.arViewer?.updateRootToMap(to: rootToMap)
                    }
                case .FinishedNavigation:
                    self.mapNavigator.stopPathPlanning()
                case .LeaveMap:
                    self.mapNavigator.resetMap()
                case .PlanPath
                    self.mapNavigator.planPath(from: self.arViewer!.cameraNode.transform)
                
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
