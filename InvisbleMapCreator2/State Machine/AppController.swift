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
    var recordViewer: RecordViewController?
    
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
            case .ClearData:
                mapRecorder.clearData()
            case .SaveMap:
                mapRecorder.saveMap()
            // TagFinder commands
            case .RecordTags(let cameraFrame, let timestamp, let poseId):
                tagFinder.recordTags(cameraFrame: cameraFrame, timestamp: timestamp, poseId: poseId)
            case .TransformTag(let tag, let cameraTransform):
                tagFinder.transformTag(tag: tag, cameraTransform: cameraTransform)
            case .ClearTags:
                tagFinder.clearTags()
            // ARViewer commands
            case .DetectTag(let tag, let cameraTransform, let sceneVar):
                arViewer?.detectTag(tag: tag, cameraTransform: cameraTransform, sceneVar: sceneVar)
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

    func processNewTag(tag: AprilTags, cameraTransform: simd_float4x4) {
        processCommands(commands: state.handleEvent(event: .NewTagFound(tag: tag, cameraTransform: cameraTransform)))
        print("New tag found")
    }
    
    func detectTagRequested(tag: AprilTags, cameraTransform: simd_float4x4, sceneVar: (sceneTransVar: simd_float3x3, sceneQuatVar: simd_float4x4, scenePoseQuat: simd_quatf, scenePoseTranslation: SIMD3<Float>)) {
        processCommands(commands: state.handleEvent(event: .DetectTagRequested(tag: tag, cameraTransform: cameraTransform, sceneVar: sceneVar)))
        print("Tag detected!")
    }
    
    func addLocationRequested(pose: simd_float4x4, poseId: Int, locationName: String) {
        processCommands(commands: state.handleEvent(event: .AddLocationRequested(pose: pose, poseId: poseId, locationName: locationName)))
    }
    
    func saveLocationRequested(locationName: String) {
        processCommands(commands: state.handleEvent(event: .SaveLocationRequested(locationName: locationName)))
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
    func clearData()
    func saveMap()
}

protocol TagFinderController {
    func recordTags(cameraFrame: ARFrame, timestamp: Double, poseId: Int)
    func transformTag(tag: AprilTags, cameraTransform: simd_float4x4)
    func clearTags()
}

protocol ARViewController {
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, sceneVar: (sceneTransVar: simd_float3x3, sceneQuatVar: simd_float4x4, scenePoseQuat: simd_quatf, scenePoseTranslation: SIMD3<Float>))
    func pinLocation(locationName: String)
}

protocol RecordViewController {
    func enableAddLocation()
}
