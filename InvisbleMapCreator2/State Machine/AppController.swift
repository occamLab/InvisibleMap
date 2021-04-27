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
    let tagFinder = TagFinder()
    var arViewer: ARViewController?
    
    private init() {
    }

    private func processCommands(commands: [AppState.Command]) {
        for command in commands {
            switch command {
            // ContentViewer commands
            case .DisplayRecordingUI:
                contentViewer?.displayRecordingUI()
            case .DisplayOptionsMenu:
                contentViewer?.displayOptionsMenu()
            case .DisplayMainScreen:
                contentViewer?.displayMainScreen()
            // MapRecorder commands
            case .RecordData(cameraFrame: let cameraFrame):
                mapRecorder.recordData(cameraFrame: cameraFrame)
            case .AddLocation(let pose, let poseId, let locationName):
                mapRecorder.addLocation(pose: pose, poseId: poseId, locationName: locationName)
            case .DisplayLocationsUI:
                mapRecorder.displayLocationsUI()
            case .CancelMap:
                mapRecorder.cancelMap()
            case .SaveMap:
                mapRecorder.saveMap()
            // TagFinder commands
            case .RecordTags(let cameraFrame, let timestamp, let poseId):
                tagFinder.recordTags(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)
            case .UpdateTagFound(let aprilTagDetectionDictionary, let tag, let cameraTransform):
                tagFinder.updateTagFound(aprilTagDetectionDictionary: aprilTagDetectionDictionary, tag: tag, cameraTransform: cameraTransform)
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
        print("New AR frame processed!")
    }
    
    func findTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int) {
        processCommands(commands: state.handleEvent(event: .FindTagsRequested(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)))
        print("Found tags in frame!")
    }

    func processNewTag(aprilTagDetectionDictionary: Dictionary<Int, AprilTagTracker>, tag: AprilTags, cameraTransform: simd_float4x4) {
        processCommands(commands: state.handleEvent(event: .NewTagFound(aprilTagDetectionDictionary: aprilTagDetectionDictionary, tag: tag, cameraTransform: cameraTransform)))
    }
    
    func addLocationRequested(pose: simd_float4x4, poseId: Int, locationName: String) {
        processCommands(commands: state.handleEvent(event: .AddLocationRequested(pose: pose, poseId: poseId, locationName: locationName)))
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

protocol ContentViewController {
    func displayRecordingUI()
    func displayMainScreen()
    func displayOptionsMenu()
}

protocol MapRecorderController {
    func recordData(cameraFrame: ARFrame)
    func addLocation(pose: simd_float4x4, poseId: Int, locationName: String)
    func displayLocationsUI()
    func cancelMap()
    func saveMap()
}

protocol TagFinderController {
    func recordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
    func updateTagFound(aprilTagDetectionDictionary: Dictionary<Int, AprilTagTracker>, tag: AprilTags, cameraTransform: simd_float4x4)
}

protocol ARViewController {
    func detectTagFound(aprilTagDetectionDictionary: Dictionary<Int, AprilTagTracker>, tag: AprilTags, cameraTransform: simd_float4x4)
}

