//
//  AppController.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation
import ARKit

class AppController {
    public static var shared = AppController()
    private var state = AppState.initialState
    var contentViewer: ContentViewController?
    let mapRecorder = MapRecorder()
    
    private init() {
    }
    
    private func processCommands(commands: [AppState.Command]) {
        for command in commands {
            switch command {
            case .DisplayRecordingUI:
                contentViewer?.displayRecordingUI()
            case .DisplayMainScreen:
                contentViewer?.displayMainScreen()
            case .DisplayOptionsMenu:
                contentViewer?.displayOptionsMenu()
            case .AddTag(let pose, let tagId):
                mapRecorder.addTag(pose: pose, tagId: tagId)
            case .AddWaypoint(let pose, let poseId, let waypointName):
                mapRecorder.addWaypoint(pose: pose, poseId: poseId, waypointName: waypointName)
            case .DisplayWaypointsUI:
                mapRecorder.displayWaypointsUI()
            case .SaveMap(let mapName):
                mapRecorder.saveMap(mapName: mapName)
            case .RecordPoseData(cameraFrame: let cameraFrame, timestamp: let timestamp, poseId: let poseId):
                mapRecorder.recordPoseData(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)
            case .RecordTags(cameraFrame: let cameraFrame, timestamp: let timestamp, poseId: let poseId):
                mapRecorder.recordTags(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)
            case .RecordLocationData(cameraFrame: let cameraFrame, timestamp: let timestamp, poseId: let poseId):
                mapRecorder.recordLocationData(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)
            }
        }
    }
}

extension AppController {
    // contentViewer event functions
    func mainScreenRequested() {
        processCommands(commands: state.handleEvent(event: .MainScreenRequested))
        print(state)
    }
    func optionsMenuRequested() {
        processCommands(commands: state.handleEvent(event: .OptionsMenuRequested))
        print(state)
    }
    func startRecordingRequested() {
        processCommands(commands: state.handleEvent(event: .StartRecordingRequested))
        print(state)
    }
    
    func stopRecordingRequested() {
        processCommands(commands: state.handleEvent(event: .StopRecordingRequested/*(mapName: "placeholder")*/))
        print(state)
    }
}

protocol ContentViewController {
    func displayRecordingUI()
    func displayMainScreen()
    func displayOptionsMenu()
}

protocol MapRecorderController {
    func addTag(pose: simd_float4x4, tagId: Int)
    func addWaypoint(pose: simd_float4x4, poseId: Int, waypointName: String)
    func displayWaypointsUI()
    func saveMap(mapName: String)
    func recordPoseData(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
    func recordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
    func recordLocationData(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
}
