//
//  AppState.swift
//  InvisibleMap2
//
//  Created by Allison Li and Ben Morris on 9/15/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit

indirect enum AppState: StateType {
    // Higher level app states
    case MainScreen
    case NavigateMap
    case EditMap
    case SelectPath(lastState: AppState)
    
    // Initial state upon opening the app
    static let initialState = AppState.MainScreen
    
    // All the effectual inputs from the app which the state can react to
    enum Event {
        // MainScreen events
        case MapSelected(mapFileName: String)
        // SelectPath events
        case PathSelected(tagId: Int)
        // NavigateMap events
        case NewARFrame(cameraFrame: ARFrame)
        case TagFound(tag: AprilTags, cameraTransform: simd_float4x4)
        case WaypointReached(finalWaypoint: Bool)
        case EditMapRequested
        case CancelEditRequested
        case SaveEditRequested
        case ViewPathRequested
        case DismissPathRequested
        case LeaveMapRequested
        case PlanPath
    }
    
    // All the effectful outputs which the state desires to have performed on the app
    enum Command {
        case LoadMap(mapFileName: String)
        case StartPath(tagId: Int)
        case UpdatePoseVIO(cameraFrame: ARFrame)
        case UpdatePoseTag(tag: AprilTags, cameraTransform: simd_float4x4)
        case GetNewWaypoint
        case EditMap
        case FinishedNavigation
        case LeaveMap
        case PlanPath
    }
    
    // In response to an event, a state may transition to a new state, and it may emit a command
    mutating func handle(event: Event) -> [Command] {
        print("Current State: \(self), \(event)")
        switch (self, event) {
            case (.MainScreen, .MapSelected(let mapFileName)):
                self = .SelectPath(lastState: AppState.MainScreen)
                return [.LoadMap(mapFileName: mapFileName)]
            case (.NavigateMap, .LeaveMapRequested):
                self = .MainScreen
                return [.LeaveMap]
            case (.NavigateMap, .NewARFrame(let cameraFrame)):
                return [.UpdatePoseVIO(cameraFrame: cameraFrame)]
            case (.NavigateMap, .TagFound(let tag, let cameraTransform)):
                return [.UpdatePoseTag(tag: tag, cameraTransform: cameraTransform)]
            case (.NavigateMap, .WaypointReached(let finalWaypoint)):
                return finalWaypoint ? [.GetNewWaypoint] : [.FinishedNavigation]
            case (.NavigateMap, .EditMapRequested):
                self = .EditMap
                return []
            case (.NavigateMap, .ViewPathRequested):
                self = .SelectPath(lastState: .NavigateMap)
                return []
            case (.SelectPath, .PathSelected(let tagId)):
                self = .NavigateMap
                return [.StartPath(tagId: tagId)]
            case (.SelectPath(let lastState), .DismissPathRequested):
                self = lastState
                return []
            case (.NavigateMap, .PlanPath):
                return [.PlanPath]
            case (.EditMap, .CancelEditRequested):
                self = .NavigateMap
                return []
            case (.EditMap, .SaveEditRequested):
                self = .NavigateMap
                return [.EditMap]
            default: break
        }
        return []
    }
}
