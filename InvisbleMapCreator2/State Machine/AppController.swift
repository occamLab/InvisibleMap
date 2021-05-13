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
            case .CacheLocation(let node, let picture, let textNode):
                mapRecorder.cacheLocation(node: node, picture: picture, textNode: textNode)
            case .DisplayLocationsUI:
                mapRecorder.displayLocationsUI()
            case .ClearData:
                mapRecorder.clearData()
            case .SaveMap:
                mapRecorder.saveMap()
            // ARViewer commands
            case .DetectTag(let tag, let cameraTransform, let snapTagsToVertical):
                arViewer?.detectTag(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
            case .PinLocation(let locationName):
                arViewer?.pinLocation(locationName: locationName)
            // RecordViewer commands
            case .EnableAddLocation:
                recordViewer?.enableAddLocation()
            case .UpdateLocationList(node: let node, picture: let picture, textNode: let textNode, poseId: let poseId):
                recordViewer?.updateLocationList(node: node, picture: picture, textNode: textNode, poseId: poseId)
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
        print(state)
        processCommands(commands: state.handleEvent(event: .StartRecordingRequested))
        print(state)
    }
    
    // RecordMap events
    func processNewARFrame(frame: ARFrame) {
        processCommands(commands: state.handleEvent(event: .NewARFrame(cameraFrame: frame)))
    }
    
    func processNewTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) {
        processCommands(commands: state.handleEvent(event: .NewTagFound(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)))
    }
    
    func saveLocationRequested(locationName: String) {
        processCommands(commands: state.handleEvent(event: .SaveLocationRequested(locationName: locationName)))
    }
    
    func cacheLocationRequested(node: SCNNode, picture: UIImage, textNode: SCNNode) {
        processCommands(commands: [AppState.Command.CacheLocation(node: node, picture: picture, textNode: textNode)])
    }
    
    func updateLocationListRequested(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int) {
        processCommands(commands: [AppState.Command.UpdateLocationList(node: node, picture: picture, textNode: textNode, poseId: poseId)])
    }
    
    func viewLocationsRequested() {
        processCommands(commands: state.handleEvent(event: .ViewLocationsRequested))
    }
    
    func dismissLocationsRequested() {
        processCommands(commands: state.handleEvent(event: .DismissLocationsRequested))
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
    func cacheLocation(node: SCNNode, picture: UIImage, textNode: SCNNode)
    func displayLocationsUI()
    func clearData()
    func saveMap()
}

protocol ARViewController {
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool)
    func pinLocation(locationName: String)
}

protocol RecordViewController {
    func enableAddLocation()
    func updateLocationList(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int)
}
