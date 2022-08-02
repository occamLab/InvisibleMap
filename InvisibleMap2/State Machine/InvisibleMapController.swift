//
//  InvisibleMapController.swift
//  InvisibleMap2
//
//  Created by tad on 9/22/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit

class InvisibleMapController: AppController {
    public static var shared = InvisibleMapController()
    private var state = InvisibleMapAppState.initialState
    
    //public var navigateGlobalState = NavigateGlobalState.shared

    // Various controllers for handling commands
    public var mapNavigator = MapNavigator()
    public var arViewer: ARView?
    var navigateViewer: NavigateViewController?
    
    // Variable for announcing commands
    /// When VoiceOver is not active, we use AVSpeechSynthesizer for speech feedback
    let synth = AVSpeechSynthesizer()
    
    /// The announcement that is currently being read.  If this is nil, that implies nothing is being read
    var currentAnnouncement: String?
    
    /// The announcement that should be read immediately after this one finishes
    var nextAnnouncement: String?
    
    // state of whether the current app is in the process of leaving the app
    public var exitingMap = false
    
    // counter incremented each time a graph is rendered in a new AR frame
    public var countFrame: Int = 0
    
    private init() {
        print("starting to init")
    }
    
    
    func initialize() {
        InvisibleMapController.shared.arViewer?.initialize()
        InvisibleMapController.shared.arViewer?.setupPing()
    }
    
    func process(commands: [InvisibleMapAppState.Command]) {
        for command in commands {
            //print("last command: \(command)")
            switch (command) {
                case .LoadMap(let mapFileName):
                print("loading select path view")
                    FirebaseManager.createMap(from: mapFileName) { newMap in
                         self.mapNavigator.map = newMap
                    }
                
                case .StartPath(let locationType, let Id):
                    // check: if ping was not invalidated, stop it before starting navigation?
                // Question: ping sound from previous navigation to a POI continues for navigation to another POI (navmap -> selectpath -> navmap (ping starts before detecting first tag)
                 //   self.arViewer?.session.run(ARWorldTrackingConfiguration())
                
                    // need to re-initialize NavigateGlobalState which is a property of NavigateGlobalStateSingleton to update instructions for new ARSessions
                    NavigateGlobalState.shared.reset()
                    arViewer?.initialize()
                    self.mapNavigator.locationType = locationType
                    if locationType == "tag" {
                        self.mapNavigator.endpointTagKey = Id
                        self.mapNavigator.scheduledPathPlanningTimer()
                        self.arViewer?.scheduledPingTimer()
                        self.mapNavigator.scheduledDirectionFeedbackTimer()
                    }
                    if locationType == "waypoint" {
                        self.mapNavigator.endpointWaypointKey = Id
                        self.mapNavigator.scheduledPathPlanningTimer()
                        self.arViewer?.scheduledPingTimer()
                        self.mapNavigator.scheduledDirectionFeedbackTimer()
                    }
                
                case .UpdatePoseVIO(let cameraFrame):
                    self.mapNavigator.updateTags(from: cameraFrame)
                
                case .UpdatePoseTag(let tag, let cameraTransform):
                    let mapToGlobal = self.mapNavigator.map?.computeMapPose(fromTag: Int(tag.number), withPosition: simd_float4x4(tag.poseData), relativeTo: cameraTransform)
                    if let mapToGlobal = mapToGlobal {
                        self.arViewer?.updateMapPose(to: mapToGlobal)
                    }
                
                case .FinishedNavigation:
                    self.arViewer?.arrivedSound()
                    self.arViewer?.stopPing()
                    self.mapNavigator.stopPathPlanning()
                    print("navigation finished")
                    //showFinishedAlert = true
                
                case .PrepareToLeaveMap(let mapFileName):
                    // stops processing frame in AR Session
                    self.exitingMap = true
                    // pauses the app for a split second
                    let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { (timer) in
                        InvisibleMapController.shared.process(event: .ReadyToLeaveMap(mapFileName: mapFileName))
                    }

                    //let secondsToDelay = 2.0
                    /*perform(#selector(mapNavigator.waitBeforeLeavingMap(mapFileName: mapFileName)), with: nil, afterDelay: secondsToDelay)*/
                    print("preparing to leave map - stop processing frame")
                
                case .LeaveMap(let mapFileName):
                    self.arViewer?.resetNavigatingSession()
                    self.mapNavigator.resetMap() // destroys the map
                    self.exitingMap = false
                    process(commands: [.LoadMap(mapFileName: mapFileName)])  // loads the map (with its tag locations and POIs) that the user just left
                    print("leave map")
                
                case .PlanPath:
                if let cameraNode = arViewer?.cameraNode {
                    let cameraPos = arViewer!.convertNodeOrigintoMapFrame(node: cameraNode)
                    let stops = self.mapNavigator.planPath(from: simd_float3(cameraPos!.x, cameraPos!.y, cameraPos!.z))
                        if let stops = stops {
                            self.arViewer!.renderGraph(fromStops: stops)
                            countFrame += 1
                        }
                    // set previous key
                    NavigateGlobalState.shared.previousBinaryDirectionKey = NavigateGlobalState.shared.binaryDirectionKey
                    var previousKey = binaryDirectionToDirectionText(dir: NavigateGlobalState.shared.previousBinaryDirectionKey)
                    print("previous key: \(NavigateGlobalState.shared.binaryDirectionKey)")
                    
                    // update key
                    NavigateGlobalState.shared.binaryDirectionKey = NavigateGlobalState.shared.navigation.getDirections().binaryDirectionKey
                    var currentKey = binaryDirectionToDirectionText(dir: NavigateGlobalState.shared.binaryDirectionKey)
                    print("current key: \(NavigateGlobalState.shared.binaryDirectionKey)")
                    if previousKey != currentKey {
                        process(commands: [.AnnounceDirectionText])
                    }
                }
                case .UpdateInstructionText:
                    navigateViewer?.updateInstructionText()
                    print("updated instruction text")
                    print("text state is now: \(NavigateGlobalState.shared.instructionWrapper)")
                
                // NavigateViewer commands
                case .AnnounceDirectionText:
                    //print("timer be timing")
                    setDirectionText()
    
                
                // TODO: Add functionality for these
                case .GetNewEndpoint:
                    continue
                case .EditMap:
                    continue
            }
        }
    }
    
    func process(event: InvisibleMapAppState.Event) {
        process(commands: state.handle(event: event))
    }
   
    
    /// Set the direction text based on the current location and direction info.
    ///
    /// - Parameters:
    ///   - currentLocation: the current location of the device
    ///   - direction: the direction info struct (e.g., as computed by the `Navigation` class)
    ///   - displayDistance: a Boolean that indicates whether the distance to the net keypoint should be displayed (true if it should be displayed, false otherwise)
    func setDirectionText() {
        if self.mapNavigator.map?.firstTagFound != true {
                //don't play ping sound if first tag isn't detected
                return
            }
        // Set direction text for text label and VoiceOver
        // let xzNorm = sqrtf(powf(currentLocation.x - nextKeypoint.location.x, 2) + powf(currentLocation.z - nextKeypoint.location.z, 2))
        // let slope = (nextKeypoint.location.y - prevKeypointPosition.y) / xzNorm
        // let yDistance = abs(nextKeypoint.location.y - prevKeypointPosition.y)
        var dir = ""
        
        // normal directions
        let hapticFeedback = true
        if(hapticFeedback) {
            dir += binaryDirectionToDirectionText(dir: NavigateGlobalState.shared.binaryDirectionKey)
        } else {
            dir += binaryDirectionToDirectionText(dir: NavigateGlobalState.shared.binaryDirectionKey)
        }
        updateDirectionText(dir)
    } //end of setDirectiontext method
    
    
    /// Announce the direction (both in text and using speech if appropriate).  The function will automatically use the appropriate units based on settings to convert `distance` from meters to the appropriate unit.
    ///
    /// - Parameters:
    ///   - description: the direction text to display (e.g., may include the direction to turn)
    ///   - distance: the distance (expressed in meters)
    ///   - displayDistance: a Boolean that indicates whether to display the distance (true means display distance)
    func updateDirectionText(_ description: String) {
        
        let altText = description
        /*
        if (displayDistance) {
            if defaultUnit == 0 || distanceToDisplay >= 10 {
                // don't use fractional feet or for higher numbers of meters (round instead)
                // Related to higher number of meters, there is a somewhat strange behavior in VoiceOver where numbers greater than 10 will be read as, for instance, 11 dot 4 meters (instead of 11 point 4 meters).
                altText += " " + NSLocalizedString("and walk", comment: "this text is presented when getting directions.  It is placed between a direction of how to turn and a distance to travel") + " \(Int(distanceToDisplay))" + unitText[defaultUnit]!
            } else {
                altText += " " + NSLocalizedString("and walk", comment: "this text is presented when getting directions.  It is placed between a direction of how to turn and a distance to travel") + " \(distanceToDisplay)" + unitText[defaultUnit]!
            }
        }
         
        if !remindedUserOfOffsetAdjustment && adjustOffset {
            altText += ". " + NSLocalizedString("adjustOffsetReminderAnnouncement", comment: "This is the announcement which is spoken after starting navigation if the user has enabled the Correct Offset of Phone / Body option.")
            remindedUserOfOffsetAdjustment = true
        }
        if case .navigatingRoute = state {
            logger.logSpeech(utterance: altText)
        } */
        if !description.isEmpty {
            print("about to try announcement \(altText)")
            AnnouncementManager.shared.announce(announcement: altText)
        }
    } //end of updateDirectionText method
     

  
} // end of Controller class

protocol NavigateViewController {
    // Commands that impact the navigate map view UI
    func updateInstructionText()
}


