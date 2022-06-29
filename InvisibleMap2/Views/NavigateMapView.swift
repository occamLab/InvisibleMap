//
//  NavigateMapView.swift
//  InvisibleMap2
//
//  Created by tad on 11/12/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI
import FirebaseAuth

// Describes all the instructions that will exist on-screen for the user
enum InstructionType: Equatable {
    case findTag(startTime: Double)  // initial instructions when navigate map screen is opened
    case tagFound(startTime: Double)  // pops up each time a tag is found during navigation
    case destinationReached(startTime: Double)  // feedback that user has reached their endpoint
    case none  // when there are no instructions/feedback to display

    var text: String? {
        get {
            switch self {
            case .findTag: return ""
            case .tagFound: return ""
            case .destinationReached: return ""
            case .none: return nil
            }
        }
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
    
    // when to display instructions/feedback text and to control how long it stays on screen
  /*  mutating func transition(tagFound: Bool, locationRequested: Bool = false, recordTagRequested: Bool = false) {
        let previousInstruction = self
        switch self {
            
        case .findTag:
            
        case .tagFound:
            
        case .destinationReached:
            
        case .none:
            
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
            // time that instructions stay on screen
            if currentTime - self.getStartTime() > 8 {
                self = .none
            }
        }
    } */
}



// Provides persistent storage for on-screen instructions and state variables outside of the view struct
class NavigateGlobalState: ObservableObject {
    init() {
    }
}

struct NavigateMapView: View {
    @StateObject var navigateGlobalState = NavigateGlobalState()
    var mapFileName: String
    
 /*   init() {
        print("currentUser is \(Auth.auth().currentUser!.uid)")
        //mapName = ""
        //mapFileName = ""
    } */
    
    var body : some View {
        ZStack {
            BaseNavigationView()
                // Toolbar buttons
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading) {
                        MapNavigateExitButton(mapFileName: mapFileName)
                    }
                })
            .ignoresSafeArea(.keyboard)
            TagDetectionButton(navigateGlobalState: navigateGlobalState)
                .environmentObject(InvisibleMapController.shared.mapNavigator)
                .frame(maxHeight: .infinity, alignment: .bottom)
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

/*
struct NavigateMapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigateMapView()
    }
}
*/
