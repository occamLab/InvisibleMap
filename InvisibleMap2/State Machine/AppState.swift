//
//  AppState.swift
//  InvisibleMap2
//
//  Created by Ben Morris on 9/15/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit

enum AppState: StateType {
    // Higher level app states
    case MainScreen
    case NavigateMap(NavigateMapState)
    
    // Initial state upon opening the app
    static let initialState = AppState.MainScreen
    
    // All the effectual inputs from the app which the state can react to
    enum Event {
        // MainScreen events
        case MapSelected
        // NavigateMap events
        case NewARFrame(cameraFrame: ARFrame)
        case TagFound(tag: AprilTags, cameraTransform: simd_float4x4)
        case WaypointReached
        case EditMapRequested
        case CancelEditRequested
        case SaveEditRequested
        case ViewPathRequested
        case DismissPathRequested
        case LeaveMapRequested
    }
    
    // All the effectful outputs which the state desires to have performed on the app
    enum Command {
        // NavigateMap commands
        case UpdatePose(cameraFrame: ARFrame)
        case GetNewWaypoint
        case EditMap
        case FinishedNavigation
        case LeaveMap
    }
    
    // In response to an event, a state may transition to a new state, and it may emit a command
    mutating func handleEvent(event: Event) -> [Command] {
        switch (self, event) {
            case (.MainScreen, .MapSelected):
                self = .NavigateMap(.SelectPath)
                return []
            case (.NavigateMap, .LeaveMapRequested):
                self = .MainScreen
                return [.LeaveMap]
            case (.NavigateMap(let state), _) where NavigateMapState.Event(event) != nil:
                var newState = state
                let commands = newState.handleEvent(event: NavigateMapState.Event(event)!)
                self = .NavigateMap(newState)
                return commands
            default: break
        }
        return []
    }
}

enum NavigateMapState: StateType {
    // Lower level app states nested within NavigateMapState
    case Navigate
    case EditMap
    case SelectPath
        
    // Initial state upon transitioning into the NavigateMapState
    static let initialState = NavigateMapState.SelectPath
    
    // All the effectual inputs from the app which NavigateMapState can react to
    enum Event {
        case NewARFrame(cameraFrame: ARFrame)
        case TagFound(tag: AprilTags, cameraTransform: simd_float4x4)
        case WaypointReached
        case EditMapRequested
        case CancelEditRequested
        case SaveEditRequested
        case ViewPathRequested
        case DismissPathRequested
        case LeaveMapRequested
    }
    
    // Refers to commands defined in AppState
    typealias Command = AppState.Command
    
    // In response to an event, NavigateMapState may emit a command
    mutating func handleEvent(event: Event) -> [Command] {
        switch (self, event) {
            case (.SelectPath, .DismissPathRequested):
                self = .Navigate
                return []
            case (.Navigate, .NewARFrame(let cameraFrame)):
                return [.UpdatePose(cameraFrame: cameraFrame)]
            default: break
        }
        return []
    }
}

extension NavigateMapState.Event {
    init?(_ event: AppState.Event) {
        // Translate between events in AppState and events in NavigateMapState
        switch event {
            case .NewARFrame(let cameraFrame):
                self = .NewARFrame(cameraFrame: cameraFrame)
            case .TagFound(let tag, let cameraTransform):
                self = .TagFound(tag: tag, cameraTransform: cameraTransform)
            case .WaypointReached:
                self = .WaypointReached
            case .EditMapRequested:
                self = .EditMapRequested
            case .CancelEditRequested:
                self = .CancelEditRequested
            case .SaveEditRequested:
                self = .SaveEditRequested
            case .ViewPathRequested:
                self = .ViewPathRequested
            case .DismissPathRequested:
                self = .DismissPathRequested
            case .LeaveMapRequested:
                self = .LeaveMapRequested
            default: return nil
        }
    }
}

