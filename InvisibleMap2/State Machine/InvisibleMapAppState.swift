//
//  InvisibleMapAppState.swift
//  InvisibleMap2
//
//  Created by Allison Li and Ben Morris on 9/15/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit

indirect enum InvisibleMapAppState: StateType {
    // Higher level app states
    case MainScreen
    case NavigateMap
    case EditMap
    case SelectPath(lastState: InvisibleMapAppState)
    
    // Initial state upon opening the app
    static let initialState = InvisibleMapAppState.MainScreen
    
    // All the effectual inputs from the app which the state can react to
    enum Event {
        // MainScreen events
        case MapSelected(mapFileName: String)
        // SelectPath events
        case PathSelected(locationType: String, Id: Int)
        // NavigateMap events
        case NewARFrame(cameraFrame: ARFrame)
        case TagFound(tag: AprilTags, cameraTransform: simd_float4x4)
        case WaypointReached(finalWaypoint: Bool)
        case EditMapRequested
        case CancelEditRequested
        case SaveEditRequested
        case ViewPathRequested
        case DismissPathRequested
        case LeaveMapRequested(mapFileName: String)
        case PlanPath
    }
    
    // All the effectful outputs which the state desires to have performed on the app
    enum Command {
        case LoadMap(mapFileName: String)
        case StartPath(locationType: String, Id: Int)
        case UpdatePoseVIO(cameraFrame: ARFrame)
        case UpdatePoseTag(tag: AprilTags, cameraTransform: simd_float4x4)
        case GetNewWaypoint
        case EditMap
        case FinishedNavigation
        case LeaveMap(mapFileName: String)
        case PlanPath
        case UpdateInstructionText
    }
    
    // In response to an event, a state may transition to a new state, and it may emit a command
    mutating func handle(event: Event) -> [Command] {
        print("Last State: \(self), \(event)")
        switch (self, event) {
            // Note: loads the selected map each time state changes from mainscreen to selectpath (location list view) state; when users go from selectpath to mainscreen state is reset to mainscreen (laststate before selectpath) -> dismisspathrequested (event)
            case (.MainScreen, .MapSelected(let mapFileName)):
                self = .SelectPath(lastState: InvisibleMapAppState.MainScreen)
                print("Current State: \(self)")
                return [.LoadMap(mapFileName: mapFileName)]
            
            // Note: go back to saved location list [SelectPathView] when cancel button is pressed; lastState of SelectPath must be MainScreen in order to reload maps' location lists in SelectPath view
            case (.NavigateMap, .LeaveMapRequested(let mapFileName)):
                self = .SelectPath(lastState: InvisibleMapAppState.NavigateMap)
                print("Current State: \(self)")
                return [.LeaveMap(mapFileName: mapFileName)]
            
            case (.NavigateMap, .NewARFrame(let cameraFrame)):
                return [.UpdatePoseVIO(cameraFrame: cameraFrame), .UpdateInstructionText]
            
            case (.NavigateMap, .TagFound(let tag, let cameraTransform)):
                return [.UpdatePoseTag(tag: tag, cameraTransform: cameraTransform)]
            
            // Note: As of now this case is when users reach their selected destination
            case (.NavigateMap, .WaypointReached(let finalWaypoint)):
                print("finished navigation!")
               // self = .SelectPath(lastState: InvisibleMapAppState.MainScreen)
                return [.FinishedNavigation]
               // return finalWaypoint ? [.GetNewWaypoint] : [.FinishedNavigation]
            
            case (.NavigateMap, .EditMapRequested):
                self = .EditMap
                return []
            
            case (.NavigateMap, .PlanPath):
                return [.PlanPath]
            
            case (.SelectPath, .NewARFrame(let cameraFrame)):
                return []
            
            case (.SelectPath, .PathSelected(let locationType, let Id)):
                self = .NavigateMap
                return [.StartPath(locationType: locationType, Id: Id)]
            
            // Note: dismiss select path view back and set app state back to main screen
            case (.SelectPath(let lastState), .DismissPathRequested):
                self = lastState
                print("Current State: \(self)")
                return []
            
        /*    case (.EditMap, .CancelEditRequested):
                self = .NavigateMap
                return []
         
            case (.EditMap, .SaveEditRequested):
                self = .NavigateMap
                return [.EditMap] */

            default: break
        }
        return []
    }
}
