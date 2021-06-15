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
    
    // Various controllers for handling commands
    let mapRecorder = MapRecorder() // Initialized in MapRecorder.swift
    var arViewer: ARViewController? // Initialized in ARView.swift
    var recordViewer: RecordViewController? // Initialized in RecordMapView.swift
    
    private init() {
    }

    private func processCommands(commands: [AppState.Command]) {
        for command in commands {
            switch command {
            // MapRecorder commands
            case .RecordData(let cameraFrame):
                mapRecorder.recordData(cameraFrame: cameraFrame)
            case .UpdatePlanes(let planes):
                mapRecorder.updatePlanes(planes: planes)
            case .CacheLocation(let node, let picture, let textNode):
                mapRecorder.cacheLocation(node: node, picture: picture, textNode: textNode)
            case .ClearData:
                mapRecorder.clearData()
            case .SendToFirebase(let mapName):
                mapRecorder.sendToFirebase(mapName: mapName)
            // ARViewer commands
            case .DetectTag(let tag, let cameraTransform, let snapTagsToVertical):
                arViewer?.detectTag(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
            case .PinLocation(let locationName):
                arViewer?.pinLocation(locationName: locationName)
            // RecordViewer commands
            case .EnableAddLocation:
                recordViewer?.enableAddLocation()
            case .UpdateLocationList(let node, let picture, let textNode, let poseId):
                recordViewer?.updateLocationList(node: node, picture: picture, textNode: textNode, poseId: poseId)
            }
        }
    }
}

extension AppController {
    // MainScreen events
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
    
    func processPlanesUpdated(planes: [ARPlaneAnchor]) {
        processCommands(commands: state.handleEvent(event: .PlanesUpdated(planes: planes)))
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
    
    func saveMapRequested(mapName: String) {
        processCommands(commands: state.handleEvent(event: .SaveMapRequested(mapName: mapName)))
        print(state)
    }
}

protocol MapRecorderController {
    // Commands that impact the map data being recorded
    func recordData(cameraFrame: ARFrame)
    func cacheLocation(node: SCNNode, picture: UIImage, textNode: SCNNode)
    func sendToFirebase(mapName: String)
    func clearData()
}

protocol ARViewController {
    // Commands that interact with the ARView
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool)
    func pinLocation(locationName: String)
}

protocol RecordViewController {
    // Commands that impact the record map UI
    func enableAddLocation()
    func updateLocationList(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int)
}
