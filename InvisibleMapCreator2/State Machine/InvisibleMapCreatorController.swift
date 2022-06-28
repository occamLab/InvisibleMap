//
//  AppController.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation
import ARKit

class InvisibleMapCreatorController: AppController {
    public static var shared = InvisibleMapCreatorController()
    private var state = AppState.initialState
    
    // Various controllers for handling commands
    var mapRecorder = MapRecorder()
    var arViewer: ARViewController? // Initialized in ARView.swift
    var recordViewer: RecordViewController? // Initialized in RecordMapView.swift
    var mapDatabase = FirebaseManager.createMapDatabase()
    public var arView: ARView?
    
    private init() {
    }
    func initialize() {
        self.arViewer?.initialize()
    }

    func process(commands: [AppState.Command]) {
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
                arViewer?.resetArSession()
                arView?.endSound()
            case .SendToFirebase(let mapName):
                mapRecorder.sendToFirebase(mapName: mapName)
            // ARViewer commands
            case .DetectTag(let tag, let cameraTransform, let snapTagsToVertical):
                arViewer?.detectTag(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
            case .PinLocation(let locationName):
                arViewer?.pinLocation(locationName: locationName)
            // RecordViewer commands
            case .UpdateInstructionText:
                recordViewer?.updateInstructionText()
            case .UpdateLocationList(let node, let picture, let textNode, let poseId):
                recordViewer?.updateLocationList(node: node, picture: picture, textNode: textNode, poseId: poseId)
            // MapDatabase commands
            case .DeleteMap(let mapID):
                mapDatabase.deleteMap(mapID: mapID)
            }
        }
    }
    
    func process(event: AppState.Event) {
        process(commands: state.handle(event: event))
    }
}

extension InvisibleMapCreatorController {
    func cacheLocationRequested(node: SCNNode, picture: UIImage, textNode: SCNNode) {
        process(commands: [AppState.Command.CacheLocation(node: node, picture: picture, textNode: textNode)])
    }
    
    func updateLocationListRequested(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int) {
        process(commands: [AppState.Command.UpdateLocationList(node: node, picture: picture, textNode: textNode, poseId: poseId)])
    }
    
    func deleteMap(mapName: String) {
        process(commands: [.DeleteMap(mapID: mapName)])
    }
}

protocol MapRecorderController {
    // Commands that impact the map data being recorded
    func recordData(cameraFrame: ARFrame)
    func cacheLocation(node: SCNNode, picture: UIImage, textNode: SCNNode)
    func sendToFirebase(mapName: String)
    func clearData()
}

protocol RecordViewController {
    // Commands that impact the record map UI
    func updateInstructionText()
    func updateLocationList(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int)
}

protocol MapsController {
    func deleteMap(mapID: String)
}
