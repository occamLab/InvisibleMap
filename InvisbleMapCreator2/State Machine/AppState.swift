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
        case NewTagFound(tag: AprilTags, cameraTransform: simd_float4x4)
        case DetectTagRequested(tag: AprilTags, cameraTransform: simd_float4x4, sceneVar: (sceneTransVar: simd_float3x3, sceneQuatVar: simd_float4x4, scenePoseQuat: simd_quatf, scenePoseTranslation: SIMD3<Float>))
        case AddLocationRequested(pose: simd_float4x4, poseId: Int, locationName: String)
        case SaveLocationRequested(locationName: String)
        case ViewLocationsRequested
        case CancelRecordingRequested
        case StopRecordingRequested
        // OptionsMenu events
        case MainScreenRequested
    }
    
    // All the effectful outputs which the state desires to have performed on the app
    enum Command {
        // MainScreen commands
        case DisplayRecordingUI
        case DisplayOptionsMenu
        // RecordMap commands
        case RecordData(cameraFrame: ARFrame)
        case RecordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case TransformTag(tag: AprilTags, cameraTransform: simd_float4x4)
        case DetectTag(tag: AprilTags, cameraTransform: simd_float4x4, sceneVar: (sceneTransVar: simd_float3x3, sceneQuatVar: simd_float4x4, scenePoseQuat: simd_quatf, scenePoseTranslation: SIMD3<Float>))
        case EnableAddLocation
        case AddLocation(pose: simd_float4x4, poseId: Int, locationName: String)
        case PinLocation(locationName: String)
        case DisplayLocationsUI
        case ClearData
        case ClearTags
        case SaveMap
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
        case (.RecordMap, .CancelRecordingRequested):
            self = .MainScreen
            return [.ClearData, .ClearTags, .DisplayMainScreen]
        case (.RecordMap, .StopRecordingRequested):
            self = .MainScreen
            return [.SaveMap, .DisplayMainScreen]
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
    case ViewLocations
        
    // Initial state upon transitioning into the RecordMapState
    static let initialState = RecordMapState.RecordMap
    
    // All the effectual inputs from the app which RecordMapState can react to
    enum Event {
        case NewARFrame(cameraFrame: ARFrame)
        case FindTagsRequested(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
        case NewTagFound(tag: AprilTags, cameraTransform: simd_float4x4)
        case DetectTagRequested(tag: AprilTags, cameraTransform: simd_float4x4, sceneVar: (simd_float3x3, simd_float4x4, simd_quatf, SIMD3<Float>))
        case AddLocationRequested(pose: simd_float4x4, poseId: Int, locationName: String)
        case SaveLocationRequested(locationName: String)
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
        case(.RecordMap, .NewTagFound(let tag, let cameraTransform)):
            return [.TransformTag(tag: tag, cameraTransform: cameraTransform)]
        case(.RecordMap, .DetectTagRequested(let tag, let cameraTransform, let sceneVar)):
            return [.DetectTag(tag: tag, cameraTransform: cameraTransform, sceneVar: sceneVar), .EnableAddLocation]
        case(.RecordMap, .AddLocationRequested(let pose, let poseId, let locationName)):
            return [.AddLocation(pose: pose, poseId: poseId, locationName: locationName)]
        case(.RecordMap, .SaveLocationRequested(let locationName)):
            return [.PinLocation(locationName: locationName)]
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
        case .NewTagFound(let tag, let cameraTransform):
            self = .NewTagFound(tag: tag, cameraTransform: cameraTransform)
        case .DetectTagRequested(let tag, let cameraTransform, let sceneVar):
            self = .DetectTagRequested(tag: tag, cameraTransform: cameraTransform, sceneVar: sceneVar)
        case .AddLocationRequested(let pose, let poseId, let locationName):
            self = .AddLocationRequested(pose: pose, poseId: poseId, locationName: locationName)
        case .SaveLocationRequested(let locationName):
            self = .SaveLocationRequested(locationName: locationName)
        case .ViewLocationsRequested:
            self = .ViewLocationsRequested
            
        default: return nil
        }
    }
}
