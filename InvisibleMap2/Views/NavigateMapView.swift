//
//  NavigateMapView.swift
//  InvisibleMap2
//
//  Created by tad on 11/12/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI
import FirebaseAuth
import MaterialComponents

// Describes all the instructions that will exist on-screen for the user
enum InstructionType: Equatable {
    case findTag(startTime: Double)  // initial instructions when navigate map screen is opened
    case tagFound(startTime: Double)  // pops up each time a tag is found during navigation
    case destinationReached(startTime: Double)  // feedback that user has reached their endpoint
    case none  // when there are no instructions/feedback to display

    var text: String? {
        get {
            switch self {
                case .findTag: return "Point your camera at a tag \nnearby and START TAG DETECTION to start navigation."
                case .tagFound: return "Tag detected!"
                case .destinationReached: return "You have arrived at your destination!"
                case .none: return nil
            }
        }
        // Set start times for each instruction text so that it shows on the screen for a set amount of time (set in transition func).
        set {
            switch self {
                case .findTag: self = .findTag(startTime: NSDate().timeIntervalSince1970)
                case .tagFound: self = .tagFound(startTime: NSDate().timeIntervalSince1970)
                case .destinationReached: self = .destinationReached(startTime: NSDate().timeIntervalSince1970)
                case .none: self = .none
            }
        }
    }
    
    // To get start time of when the instructions were displayed
    func getStartTime() -> Double {
        switch self {
            case .findTag(let startTime), .tagFound(let startTime), .destinationReached(let startTime):
                return startTime
        default:
            return -1
        }
    }
    
    // Function to transition from one instruction text field to another; when to display instructions/feedback text and to control how long it stays on screen
    //TODO: end point reached feedback - for both location and tag location
    mutating func transition(tagFound: Bool, endPointReached: Bool = false) {
        let previousInstruction = self
        switch self {
            case .findTag:
                // when first tag is found -> tagFound
                if tagFound {
                    print("switch instructions from findTag to tagFound after camera finds the first tag")
                    self = .tagFound(startTime: NSDate().timeIntervalSince1970)
                }
            case .tagFound:
                // case stays as .tagFound until frame is processed again when 'Start Tag Detection' is pressed again -> resets seesTag variable depending on reprocessed camera AR frame.
                if !InvisibleMapController.shared.mapNavigator.seesTag {
                    print("tag found and camera doesn't see tag so get rid of instruction text field")
                    self = .none
                }
            case .none:
                // seesTag is not reset until tag detection starts again
                if InvisibleMapController.shared.mapNavigator.seesTag {
                    self = .tagFound(startTime: NSDate().timeIntervalSince1970)
                } else if endPointReached {
                    self = .destinationReached(startTime: NSDate().timeIntervalSince1970)
                }
            case .destinationReached:
                break
                //self = .none
            }
        
        if self != previousInstruction {
            let instructions = self.text
            if endPointReached {
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



// Provides persistent storage for on-screen instructions and state variables outside of the view struct
class NavigateGlobalState: ObservableObject, NavigateViewController {
    @Published var tagFound: Bool
    @Published var endPointReached: Bool
    @Published var instructionWrapper: InstructionType
    
    init() {
        tagFound = false
        endPointReached = false 
        instructionWrapper = .findTag(startTime: NSDate().timeIntervalSince1970)
        InvisibleMapController.shared.navigateViewer = self
    }
    
    // Navigate view controller commands
    func updateInstructionText() {
        DispatchQueue.main.async {
            if let map = InvisibleMapController.shared.mapNavigator.map {
                if !map.firstTagFound == true {
                    self.tagFound = false
                } else {
                    print("first tag was found!")
                    self.tagFound = true
                }
                print("Instruction wrapper: \(self.instructionWrapper)")
                self.instructionWrapper.transition(tagFound: self.tagFound, endPointReached: self.endPointReached)
                print("Instruction wrapper: \(self.instructionWrapper)")
            }
        }
    }
}

struct NavigateMapView: View {
    @StateObject var navigateGlobalState = NavigateGlobalState()
    var mapFileName: String
    
    init(mapFileName: String = "") {
        print("currentUser is \(Auth.auth().currentUser!.uid)")
        self.mapFileName = mapFileName
    }
    
    var body : some View {
        ZStack {
            BaseNavigationView()
                // Toolbar buttons
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading) {
                        MapNavigateExitButton(mapFileName: mapFileName)
                    }
                })
            VStack{
                // Show instructions if there are any
                if navigateGlobalState.instructionWrapper.text != nil {
                    InstructionOverlay(instruction: $navigateGlobalState.instructionWrapper.text)
                        .animation(.easeInOut)
                }
                TagDetectionButton(navigateGlobalState: navigateGlobalState)
                    .environmentObject(InvisibleMapController.shared.mapNavigator)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .padding()
        }
        .ignoresSafeArea(.keyboard)
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
      //  self.navigationItem.hidesBackButton = true
        // Creates a translucent toolbar
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
    }
}

/*
struct NavigateMapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigateMapView()
    }
}
*/
