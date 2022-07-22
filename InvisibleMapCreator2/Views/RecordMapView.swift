//
//  RecordMapView.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/14/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import SwiftUI
import ARKit
import UIKit
import FirebaseAuth

// Describes all the instructions that will exist on-screen for the user
enum InstructionType: Equatable {
    case findTag(startTime: Double)
    case saveLocation(startTime: Double)
    case tagFound(startTime: Double)
    //case tagRecording(startTime: Double)
    case tagRecorded(startTime: Double)
    case findTagReminder(startTime: Double)
    case recordTagReminder(startTime: Double)
    case none
    //TODO: add feedback for when a location was marked (tell user to take a step back to see the white marked location & that they successfully marked a location of interest.)
    // TODO: add audio direction instructions (ex. "turn left" or clock directions)
    
    var text: String? {
        get {
            switch self {
            case .findTag: return "Pan camera to find a tag."  // displayed as initial instructions
            case .saveLocation: return "First tag detected! \nPress START RECORDING TAG and hold phone still then press STOP RECORDING TAG. /nTo add points of interests, press ADD LOCATIONS at any time."  // displayed when 1st tag is found
            case .tagFound: return "Tag detected! \nYou can now record the tag. \nRemember to hold phone still."  // displayed when tags other than 1st tag is found
            //case .tagRecording: return "Hold phone still." //displayed while tag is being recorded
            case .tagRecorded: return "Tag was recorded. Move onto the next tag."  // after user records the tag
            case .findTagReminder: return "WARNING: You must find a tag before you can save a location."
            case .recordTagReminder:  return "WARNING: You must first detect a tag to record the tag position."
            case .none: return nil
            }
        }
        set {
            switch self {
            case .findTag: self = .findTag(startTime: NSDate().timeIntervalSince1970)
            case .saveLocation: self = .saveLocation(startTime: NSDate().timeIntervalSince1970)
            case .tagFound: self = .tagFound(startTime: NSDate().timeIntervalSince1970)
            case .findTagReminder: self = .findTagReminder(startTime: NSDate().timeIntervalSince1970)
                    //case tagRecording: self = .tagRecording(startTime: <#T##Double#>)
            case .tagRecorded: self = .tagRecorded(startTime: NSDate().timeIntervalSince1970)
            case .recordTagReminder: self = .recordTagReminder(startTime: NSDate().timeIntervalSince1970)
            case .none: self = .none
            }
        }
    }
    
    func getStartTime() -> Double {
        switch self {
        case .findTag(let startTime), .saveLocation(let startTime), .tagFound(let startTime), .tagRecorded(startTime: let startTime), .findTagReminder(let startTime), .recordTagReminder(let startTime):
            return startTime
        default:
            return -1
        }
    }
    // Note: locationRequested -> when user tries to add a location of interest
    //Function to transition from one instruction text field to another
    // tagFound -> true if first tag was found, false otherwise
    mutating func transition(tagFound: Bool, locationRequested: Bool = false, markTagRequested: Bool = false) {
        let previousInstruction = self
        switch self {
        case .findTag:
          //  if InvisibleMapCreatorController.shared.mapRecorder.seesTag {
            if tagFound {
                self = .saveLocation(startTime: NSDate().timeIntervalSince1970)
            } else if locationRequested {
                self = .findTagReminder(startTime: NSDate().timeIntervalSince1970)
            } else if markTagRequested {
                self = .recordTagReminder(startTime: NSDate().timeIntervalSince1970)
            }
        case .saveLocation, .tagFound:
            if !InvisibleMapCreatorController.shared.mapRecorder.seesTag {
                self = .none
            }
            if InvisibleMapCreatorController.shared.mapRecorder.tagWasRecorded {
                self = .tagRecorded(startTime: NSDate().timeIntervalSince1970)
            }
        case .tagRecorded:
            // TODO: have a variable that keeps track of when a tag was marked
            if !InvisibleMapCreatorController.shared.mapRecorder.tagWasRecorded {
                self = .none
            }
        case .findTagReminder:
            if tagFound {
                self = .saveLocation(startTime: NSDate().timeIntervalSince1970)
            } else if markTagRequested {
                self = .recordTagReminder(startTime: NSDate().timeIntervalSince1970)
            }
        case .recordTagReminder:
            if InvisibleMapCreatorController.shared.mapRecorder.seesTag {
                self = .tagFound(startTime: NSDate().timeIntervalSince1970)
            }
            else if !tagFound && locationRequested {
                self = .findTagReminder(startTime: NSDate().timeIntervalSince1970)
            }
        case .none:
            if InvisibleMapCreatorController.shared.mapRecorder.seesTag {
                self = .tagFound(startTime: NSDate().timeIntervalSince1970)
            } else if markTagRequested {
                self = .recordTagReminder(startTime: NSDate().timeIntervalSince1970)
            } else if locationRequested && !tagFound {
                self = .findTagReminder(startTime: NSDate().timeIntervalSince1970)
            }
        }
        if self != previousInstruction {
            let instructions = self.text
            if locationRequested || markTagRequested {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    UIAccessibility.post(notification: .announcement, argument: instructions)
                }
            } else {
                UIAccessibility.post(notification: .announcement, argument: instructions)
            }
        } else {
            let currentTime = NSDate().timeIntervalSince1970
            // time that instructions stay on screen
            if currentTime - self.getStartTime() > 8 {
                self = .none
            }
        }
    }
}

struct NodeData: Identifiable {
    let id = UUID()
    var node: SCNNode
    var picture: UIImage
    var textNode: SCNNode
    var poseId: Int
}

// Provides persistent storage for on-screen instructions and state variables outside of the view struct
class RecordGlobalState: ObservableObject, RecordViewController {
    @Published var tagFound: Bool
    @Published var instructionWrapper: InstructionType
    @Published var nodeList: [NodeData]
    //@Published var TagRecordingStateTimer: Double

    init() {
        tagFound = false
        instructionWrapper = .findTag(startTime: NSDate().timeIntervalSince1970)
        nodeList = []
        InvisibleMapCreatorController.shared.recordViewer = self
    }
    
    // Record view controller commands
    func updateInstructionText() {
        DispatchQueue.main.async {
            if !InvisibleMapCreatorController.shared.mapRecorder.firstTagFound {
                self.tagFound = false
            } else {
                self.tagFound = true
            }
            self.instructionWrapper.transition(tagFound: self.tagFound)
        }
    }
    
    func updateLocationList(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int) {
        self.nodeList.append(NodeData(node: node, picture: picture, textNode: textNode, poseId: poseId))
    }
    
    /*func tagRecordinginProgress() {
        
    }*/
}

struct RecordMapView: View {
    @StateObject var recordGlobalState = RecordGlobalState()
    //@StateObject var progress = (InvisibleMapCreatorController.shared.mapRecorder.tagRecordingInterval) * (1.0 / 3.0)
    
    init() {
        //print("currentUser is \(Auth.auth().currentUser!.uid)")
        print("Initializing Record Map View!")
    }
    
    var body : some View {
        ZStack {
            BaseNavigationView()
                // Toolbar buttons
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading) {
                        CreatorExitButton()
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        SaveButton()
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack {
                            AddLocationButton(recordGlobalState: recordGlobalState)
                            ManageLocationsButton(recordGlobalState: recordGlobalState)
                        }
                    }
                })
            VStack {
                // Shows instructions if there are any
                if recordGlobalState.instructionWrapper.text != nil {
                    InstructionOverlay(instruction: $recordGlobalState.instructionWrapper.text)
                        .animation(.easeInOut)
                }
                if InvisibleMapCreatorController.shared.mapRecorder.tagRecordingState {
                    let progress = (InvisibleMapCreatorController.shared.mapRecorder.tagRecordingInterval) * (1.0 / 3.0)
                    CircularProgressView(progress: progress)
                        .frame(width: 200, height: 200)
                } else {
                    RecordTagButton(recordGlobalState: recordGlobalState)
                        .environmentObject(InvisibleMapCreatorController.shared.mapRecorder)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .padding()
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            InvisibleMapCreatorController.shared.process(event: .StartRecordingRequested)
        }
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
      
        // Creates a translucent toolbar
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
    }
}

struct RecordMapView_Previews: PreviewProvider {
    static var previews: some View {
        RecordMapView()
    }
}
