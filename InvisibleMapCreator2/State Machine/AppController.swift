//
//  AppController.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation
import ARKit
import ARCoreCloudAnchors

class AppController {
    public static var shared = AppController()
    private var state = AppState.initialState
    
    // Various controllers for handling commands
    var mapRecorder = MapRecorder() // Initialized in MapRecorder.swift
    var arViewer: ARViewController? // Initialized in ARView.swift
    var recordViewer: RecordViewController? // Initialized in RecordMapView.swift
    var mapsController = MapDatabase()  // Initialized in ContentView.swift
    var announcementManager = AnnouncementManager()
    
    private init() {
    }

    private func processCommands(commands: [AppState.Command]) {
        for command in commands {
            switch command {
            // MapRecorder commands
            case .RecordData(let cameraFrame, let garFrame):
                mapRecorder.recordData(cameraFrame: cameraFrame, garFrame: garFrame)
            case .UpdatePlanes(let planes):
                mapRecorder.updatePlanes(planes: planes)
            case .CacheLocation(let node, let picture, let textNode):
                mapRecorder.cacheLocation(node: node, picture: picture, textNode: textNode)
            case .ClearData:
                mapRecorder.clearData()
                arViewer?.resetArSession()
            case .SendToFirebase(let mapName):
                mapRecorder.sendToFirebase(mapName: mapName)
            // ARViewer commands
            case .DetectTag(let tag, let cameraTransform, let snapTagsToVertical):
                arViewer?.detectTag(tag: tag, cameraTransform: cameraTransform, snapTagsToVertical: snapTagsToVertical)
            case .PinLocation(let locationName):
                arViewer?.pinLocation(locationName: locationName)
            case .MakeAnnouncement(let announcement):
                announcementManager.announce(announcement: announcement)
            // RecordViewer commands
            case .UpdateInstructionText:
                recordViewer?.updateInstructionText()
            case .UpdateLocationList(let node, let picture, let textNode, let poseId):
                recordViewer?.updateLocationList(node: node, picture: picture, textNode: textNode, poseId: poseId)
            // MapsController commands
            case .DeleteMap(let mapID):
                mapsController.deleteMap(mapID: mapID)
            case .HostCloudAnchor:
                arViewer?.hostCloudAnchor()
            }
        }
    }
}

extension AppController {
    // MainScreen events
    func createMapRequested() {
        print(state)
        processCommands(commands: state.handleEvent(event: .CreateMapRequested))
        print(state)
    }
    
    // RecordMap events
    func processNewARFrame(frame: ARFrame, garFrame: GARFrame) {
        processCommands(commands: state.handleEvent(event: .NewARFrame(cameraFrame: frame, garFrame: garFrame)))
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
    
    func hostCloudAnchor() {
        processCommands(commands: [.HostCloudAnchor])
    }
    
    func updateLocationListRequested(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int) {
        processCommands(commands: [AppState.Command.UpdateLocationList(node: node, picture: picture, textNode: textNode, poseId: poseId)])
    }
    
    func announce(_ announcement: String) {
        processCommands(commands: [.MakeAnnouncement(announcement: announcement)])
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
    
    // EditMapScreen events
    // when function doesn't change states but just emits a command writing it like this is ok (with no state.handleEvent)
    func deleteMap(mapName: String) {
        processCommands(commands: [.DeleteMap(mapID: mapName)])
    }
}

protocol MapRecorderController {
    // Commands that impact the map data being recorded
    func recordData(cameraFrame: ARFrame, garFrame: GARFrame)
    func cacheLocation(node: SCNNode, picture: UIImage, textNode: SCNNode)
    func sendToFirebase(mapName: String)
    func clearData()
}

protocol ARViewController {
    // Commands that interact with the ARView
    var supportsLidar: Bool { get }
    func detectTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool)
    func raycastTag(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) -> simd_float4x4?
    func pinLocation(locationName: String)
    func hostCloudAnchor()
    func resetArSession()
}

protocol RecordViewController {
    // Commands that impact the record map UI
    func updateInstructionText()
    func updateLocationList(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int)
}

protocol MapsController {
    func deleteMap(mapID: String)
}
