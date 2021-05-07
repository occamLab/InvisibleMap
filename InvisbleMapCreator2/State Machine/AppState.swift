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
        case OptionsMenuRequested
        // RecordMap events
        case NewARFrame(cameraFrame: ARFrame)
        case FindTagsRequested(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case NewTagFound(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool)
        case SaveLocationRequested(locationName: String)
        case RecordLocationRequested(locationName: String, node: simd_float4x4)
        case ViewLocationsRequested
        case CancelRecordingRequested
        case StopRecordingRequested
        // OptionsMenu events
        case MainScreenRequested
    }
    
    // All the effectful outputs which the state desires to have performed on the app
    enum Command {
        // RecordMap commands
        case RecordData(cameraFrame: ARFrame)
        case RecordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case DetectTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool)
        case EnableAddLocation
        case PinLocation(locationName: String)
        case RecordLocation(locationName: String, node: simd_float4x4)
        case DisplayLocationsUI
        case ClearData
        case ClearTags
        case SaveMap
    }
    
    // In response to an event, a state may transition to a new state, and it may emit a command
    mutating func handleEvent(event: Event) -> [Command] {
        switch (self, event) {
        case (.MainScreen, .StartRecordingRequested):
            self = .RecordMap(.RecordMap)
            return []
        case (.MainScreen, .OptionsMenuRequested):
            self = .OptionsMenu
            return []
        case (.RecordMap, .CancelRecordingRequested):
            self = .MainScreen
            return [.ClearData, .ClearTags]
        case (.RecordMap, .StopRecordingRequested):
            self = .MainScreen
            return [.SaveMap]
        case (.RecordMap(let state), _) where RecordMapState.Event(event) != nil:
            var newState = state
            let commands = newState.handleEvent(event: RecordMapState.Event(event)!)
            self = .RecordMap(newState)
            return commands
        case(.OptionsMenu, .MainScreenRequested):
            self = .MainScreen
            return []
            
        default: break
        }
        return []
    }
}

enum RecordMapState: StateType {
    // Lower level app states nested within RecordMapState
    case RecordMap
    case ViewLocations
        
    // Initial state upon transitioning into the RecordMapState
    static let initialState = RecordMapState.RecordMap
    
    // All the effectual inputs from the app which RecordMapState can react to
    enum Event {
        case NewARFrame(cameraFrame: ARFrame)
        case FindTagsRequested(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case NewTagFound(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool)
        case SaveLocationRequested(locationName: String)
        case RecordLocationRequested(locationName: String, node: simd_float4x4)
        case ViewLocationsRequested
        case CancelRecordingRequested
        case StopRecordingRequested
    }
    
    // Refers to commands defined in AppState
    typealias Command = AppState.Command
    
    // In response to an event, RecordMapState may emit a command
    mutating func handleEvent(event: Event) -> [Command] {
        switch (self, event) {
        case(.RecordMap, .NewARFrame(let cameraFrame)):
            return [.RecordData(cameraFrame: cameraFrame)]
        case(.RecordMap, .FindTagsRequested(let cameraFrame, let timestamp, let poseId)):
            return [.RecordTags(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)]
        case(.RecordMap, .NewTagFound(let tag, let cameraTransform, let snapTagsToVertical)):
            return [.DetectTag(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical), .EnableAddLocation]
        case(.RecordMap, .SaveLocationRequested(let locationName)):
            return [.PinLocation(locationName: locationName)]
        case (.RecordMap, .RecordLocationRequested(let locationName, let node)):
            return [.RecordLocation(locationName: locationName, node: node)]
        case(.RecordMap, .ViewLocationsRequested):
            self = .ViewLocations
            return [.DisplayLocationsUI]
            
        default: break
        }
        return []
    }
}

extension RecordMapState.Event {
    init?(_ event: AppState.Event) {
        switch event {
        case .NewARFrame(let cameraFrame):
            self = .NewARFrame(cameraFrame: cameraFrame)
        case .FindTagsRequested(let cameraFrame, let timestamp, let poseId):
            self = .FindTagsRequested(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)
        case .NewTagFound(let tag, let cameraTransform, let snapTagsToVertical):
            self = .NewTagFound(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
        case .SaveLocationRequested(let locationName):
            self = .SaveLocationRequested(locationName: locationName)
        case .RecordLocationRequested(let locationName, let node):
            self = .RecordLocationRequested(locationName: locationName, node: node)
        case .ViewLocationsRequested:
            self = .ViewLocationsRequested
            
        default: return nil
        }
    }
}
