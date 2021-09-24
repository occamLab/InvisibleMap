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

// Stores the ARView
struct NavigationIndicator: UIViewControllerRepresentable {
   typealias UIViewControllerType = ARView
    func makeUIViewController(context: Context) -> ARView {
        return ARView()
   }
   func updateUIViewController(_ uiViewController:
   NavigationIndicator.UIViewControllerType, context:
   UIViewControllerRepresentableContext<NavigationIndicator>) { }
}

// Describes all the instructions that will exist on-screen for the user
enum InstructionType: Equatable {
    case findTag(startTime: Double)
    case saveLocation(startTime: Double)
    case tagFound(startTime: Double)
    case findTagReminder(startTime: Double)
    case recordTagReminder(startTime: Double)
    case none
    
    var text: String? {
        get {
            switch self {
            case .findTag: return "Point your camera at a tag"
            case .saveLocation: return "First tag found! \nYou can now save a location"
            case .tagFound: return "Tag detected. \nYou can now start recording a tag"
            case .findTagReminder: return "You must find a tag before you can save a location"
            case .recordTagReminder:  return "You must be detecting a tag to start recording tag position"
            case .none: return nil
            }
        }
        set {
            switch self {
            case .findTag: self = .findTag(startTime: NSDate().timeIntervalSince1970)
            case .saveLocation: self = .saveLocation(startTime: NSDate().timeIntervalSince1970)
            case .tagFound: self = .tagFound(startTime: NSDate().timeIntervalSince1970)
            case .findTagReminder: self = .findTagReminder(startTime: NSDate().timeIntervalSince1970)
            case .recordTagReminder: self = .recordTagReminder(startTime: NSDate().timeIntervalSince1970)
            case .none: self = .none
            }
        }
    }
    
    func getStartTime() -> Double {
        switch self {
        case .findTag(let startTime), .saveLocation(let startTime), .tagFound(let startTime), .findTagReminder(let startTime), .recordTagReminder(let startTime):
            return startTime
        default:
            return -1
        }
    }
    
    mutating func transition(tagFound: Bool, locationRequested: Bool = false, recordTagRequested: Bool = false) {
        let previousInstruction = self
        switch self {
        case .findTag:
            if InvisibleMapCreatorController.shared.mapRecorder.seesTag {
                self = .saveLocation(startTime: NSDate().timeIntervalSince1970)
            } else if locationRequested {
                self = .findTagReminder(startTime: NSDate().timeIntervalSince1970)
            } else if recordTagRequested {
                self = .recordTagReminder(startTime: NSDate().timeIntervalSince1970)
            }
        case .saveLocation, .tagFound:
            if !InvisibleMapCreatorController.shared.mapRecorder.seesTag {
                self = .none
            }
        case .findTagReminder:
            if tagFound {
                self = .saveLocation(startTime: NSDate().timeIntervalSince1970)
            } else if recordTagRequested {
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
            } else if recordTagRequested {
                self = .recordTagReminder(startTime: NSDate().timeIntervalSince1970)
            } else if locationRequested && !tagFound {
                self = .findTagReminder(startTime: NSDate().timeIntervalSince1970)
            }
        }
        if self != previousInstruction {
            let instructions = self.text
            if locationRequested || recordTagRequested {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    UIAccessibility.post(notification: .announcement, argument: instructions)
                }
            } else {
                UIAccessibility.post(notification: .announcement, argument: instructions)
            }
        } else {
            let currentTime = NSDate().timeIntervalSince1970
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
}

struct RecordMapView: View {
    @StateObject var recordGlobalState = RecordGlobalState()
    
    init() {
        print("currentUser is \(Auth.auth().currentUser!.uid)")
    }
    
    var body : some View {
        ZStack {
            NavigationIndicator().edgesIgnoringSafeArea(.all)
                // Hides the default navigation bar so that we can replace it with custom exit and save buttons
                // .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true)
                // Toolbar buttons
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ExitButton()
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
                RecordTagButton(recordGlobalState: recordGlobalState)
                    .environmentObject(InvisibleMapCreatorController.shared.mapRecorder)
                    .frame(maxHeight: .infinity, alignment: .bottom)
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
