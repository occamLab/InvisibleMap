//
//  AppState.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation
import ARKit

enum AppState: StateType {
    // Higher level app states
    case MainScreen
    case RecordMap(RecordMapState)
    case OptionsMenu
    
    // Initial state upon opening the app
    static let initialState = AppState.MainScreen
    
    // All the effectual inputs from the app which the state can react to
    enum Event {
        // MainScreen events
        case StartRecordingRequested
        case StopRecordingRequested/*(mapName: String)*/
        case OptionsMenuRequested
        case MainScreenRequested
        // RecordMap events
        case NewARFrame(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case NewTagFound(pose: simd_float4x4, tagId: Int)
        case AddWaypointRequested(pose: simd_float4x4, poseId: Int, waypointName: String)
        case ViewWaypointsRequested
    }
    
    // All the effectful outputs which the state desires to have performed on the app
    enum Command {
        // MainScreen commands
        case DisplayRecordingUI
        case DisplayOptionsMenu
        // RecordMap commands
        case RecordPoseData(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case RecordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case RecordLocationData(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case AddTag(pose: simd_float4x4, tagId: Int)
        case AddWaypoint(pose: simd_float4x4, poseId: Int, waypointName: String)
        case DisplayWaypointsUI
        case SaveMap(mapName: String)
        // RecordMap and OptionsMenu commands
        case DisplayMainScreen
    }
    
    // In response to an event, a state may transition to a new state, and it may emit a command
    mutating func handleEvent(event: Event) -> [Command] {
        switch (self, event) {
        case (.MainScreen, .StartRecordingRequested):
            self = .RecordMap(.RecordMap)
            return [.DisplayRecordingUI]
        case (.MainScreen, .OptionsMenuRequested):
            self = .OptionsMenu
            return [.DisplayOptionsMenu]
        case (.RecordMap, .StopRecordingRequested/*(let mapName)*/):
            self = .MainScreen
            return [.DisplayMainScreen/*, .SaveMap(mapName: mapName)*/]
        case (.RecordMap(let state), _) where RecordMapState.Event(event) != nil:
            var newState = state
            let commands = newState.handleEvent(event: RecordMapState.Event(event)!)
            self = .RecordMap(newState)
            return commands
        case(.OptionsMenu, .MainScreenRequested):
            self = .MainScreen
            return [.DisplayMainScreen]
            
        default: break
        }
        return []
    }
}

enum RecordMapState: StateType {
    // Lower level app states nested within RecordMapState
    case RecordMap
    case ViewWaypoints
    // Add Waypoint state
        
    // Initial state upon transitioning into the RecordMapState
    static let initialState = RecordMapState.RecordMap
    
    // All the effectual inputs from the app which RecordMapState can react to
    enum Event {
        case NewARFrame(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case NewTagFound(pose: simd_float4x4, tagId: Int)
        case AddWaypointRequested(pose: simd_float4x4, poseId: Int, waypointName: String)
        case ViewWaypointsRequested
    }
    
    // Refers to commands defined in AppState
    typealias Command = AppState.Command
    
    // In response to an event, RecordMapState may emit a command
    mutating func handleEvent(event: Event) -> [Command] {
        switch (self, event) {
        case(.RecordMap, .NewARFrame(let cameraFrame, let timestamp, let poseId)):
            return [.RecordPoseData(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId),
                    .RecordTags(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId),
                    .RecordLocationData(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)]
        case(.RecordMap, .NewTagFound(let pose, let tagId)):
            return [.AddTag(pose: pose, tagId: tagId)]
        case(.RecordMap, .AddWaypointRequested(let pose, let poseId, let waypointName)):
            return [.AddWaypoint(pose: pose, poseId: poseId, waypointName: waypointName)]
        case(.RecordMap, .ViewWaypointsRequested):
            self = .ViewWaypoints
            return [.DisplayWaypointsUI]
            
        default: break
        }
        return []
    }
}

extension RecordMapState.Event {
    init?(_ event: AppState.Event) {
        switch event {
        case .NewTagFound(let pose, let tagId):
            self = .NewTagFound(pose: pose, tagId: tagId)
        case .AddWaypointRequested(let pose, let poseId, let waypointName):
            self = .AddWaypointRequested(pose: pose, poseId: poseId, waypointName: waypointName)
        case .ViewWaypointsRequested:
            self = .ViewWaypointsRequested
            
        default: return nil
        }
    }
}
