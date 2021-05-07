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
    let mapRecorder = MapRecorder()
    let tagFinder = TagFinder()
    var arViewer: ARViewController?
    var recordViewer: RecordViewController?
    
    private init() {
    }

    private func processCommands(commands: [AppState.Command]) {
        for command in commands {
            switch command {
            // MapRecorder commands
            case .RecordData(cameraFrame: let cameraFrame):
                mapRecorder.recordData(cameraFrame: cameraFrame)
            case .RecordLocation(let locationName, let node):
                mapRecorder.recordLocation(locationName: locationName, node: node)
            case .DisplayLocationsUI:
                mapRecorder.displayLocationsUI()
            case .ClearData:
                mapRecorder.clearData()
            case .SaveMap:
                mapRecorder.saveMap()
            // TagFinder commands
            case .RecordTags(let cameraFrame, let timestamp, let poseId):
                tagFinder.recordTags(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)
            case .ClearTags:
                tagFinder.clearTags()
            // ARViewer commands
            case .DetectTag(let tag, let cameraTransform, let snapTagsToVertical):
                arViewer?.detectTag(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
            case .PinLocation(let locationName):
                arViewer?.pinLocation(locationName: locationName)
            // RecordViewer commands
            case .EnableAddLocation:
                recordViewer?.enableAddLocation()
            }
        }
    }
}

extension AppController {
    // MainScreen events
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
    
    // RecordMap events
    func processNewARFrame(frame: ARFrame) {
        processCommands(commands: state.handleEvent(event: .NewARFrame(cameraFrame: frame)))
    }
    
    func findTagsRequested(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
        processCommands(commands: state.handleEvent(event: .FindTagsRequested(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)))
    }

    func processNewTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) {
        processCommands(commands: state.handleEvent(event: .NewTagFound(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)))
        print("New tag found")
    }
    
    func saveLocationRequested(locationName: String) {
        processCommands(commands: state.handleEvent(event: .SaveLocationRequested(locationName: locationName)))
    }
    
    func recordLocationRequested(locationName: String, node: simd_float4x4) {
        processCommands(commands: state.handleEvent(event: .RecordLocationRequested(locationName: locationName, node: node)))
    }
    
    func viewLocationsRequested() {
        processCommands(commands: state.handleEvent(event: .ViewLocationsRequested))
    }
    
    func cancelRecordingRequested() {
        processCommands(commands: state.handleEvent(event: .CancelRecordingRequested))
        print(state)
    }
    
    func stopRecordingRequested() {
        processCommands(commands: state.handleEvent(event: .StopRecordingRequested/*(mapName: "placeholder")*/))
        print(state)
    }
}

protocol MapRecorderController {
    func recordData(cameraFrame: ARFrame)
    func recordLocation(locationName: String, node: simd_float4x4)
    func displayLocationsUI()
    func clearData()
    func saveMap()
}

protocol TagFinderController {
    func recordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
    func clearTags()
}

protocol ARViewController {
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool)
    func pinLocation(locationName: String)
}

protocol RecordViewController {
    func enableAddLocation()
}
