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
    var arViewer: ARViewController?
    
    private init() {
    }

    private func processCommands(commands: [AppState.Command]) {
        for command in commands {
            switch command {
            // MainScreen commands
            case .DisplayRecordingUI:
                contentViewer?.displayRecordingUI()
            case .DisplayMainScreen:
                contentViewer?.displayMainScreen()
            case .DisplayOptionsMenu:
                contentViewer?.displayOptionsMenu()
            // RecordMap commands
            case .RecordData(cameraFrame: let cameraFrame):
                mapRecorder.recordData(cameraFrame: cameraFrame)
            case .DetectTagFound(let tag, let cameraTransform):
                mapRecorder.detectTagFound(tag: tag, cameraTransform: cameraTransform)
            case .AddWaypoint(let pose, let poseId, let waypointName):
                mapRecorder.addWaypoint(pose: pose, poseId: poseId, waypointName: waypointName)
            case .DisplayWaypointsUI:
                mapRecorder.displayWaypointsUI()
            case .CancelMap:
                mapRecorder.cancelMap()
            case .SaveMap:
                mapRecorder.saveMap()
            }
        }
    }
}

extension AppController {
    // contentViewer events
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
    
    // mapRecorder events
    func cancelRecordingRequested() {
        processCommands(commands: state.handleEvent(event: .CancelRecordingRequested))
        print(state)
    }
    
    func stopRecordingRequested() {
        processCommands(commands: state.handleEvent(event: .StopRecordingRequested/*(mapName: "placeholder")*/))
        print(state)
    }
    
    func processNewARFrame(frame: ARFrame) {
        processCommands(commands: state.handleEvent(event: .NewARFrame(cameraFrame: frame)))
        print("New AR Frame processed!")
    }
    
    func processNewTag(tag: AprilTags, cameraTransform: simd_float4x4) {
        processCommands(commands: state.handleEvent(event: .NewTagFound(tag: tag, cameraTransform: cameraTransform)))
    }
}

protocol ContentViewController {
    func displayRecordingUI()
    func displayMainScreen()
    func displayOptionsMenu()
}

protocol MapRecorderController {
    func recordData(cameraFrame: ARFrame)
    func detectTagFound(tag: AprilTags, cameraTransform: simd_float4x4)
    func addWaypoint(pose: simd_float4x4, poseId: Int, waypointName: String)
    func displayWaypointsUI()
    func cancelMap()
    func saveMap()
}

protocol ARViewController {
}
