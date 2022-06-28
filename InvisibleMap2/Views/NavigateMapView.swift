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
    case findTag(startTime: Double)
    case tagFound(startTime: Double)
    case destinationReached(startTime: Double)
    case findTagReminder(startTime: Double)
    case none
}
/*
var text: String? {
    get {
        switch self {
            
        }
    }
}
*/
// Provides persistent storage for on-screen instructions and state variables outside of the view struct
class NavigateGlobalState: ObservableObject {
    init() {
    }
}

struct NavigateMapView: View {
    @StateObject var navigateGlobalState = NavigateGlobalState()
    var mapName: String
    
    init() {
        print("currentUser is \(Auth.auth().currentUser!.uid)")
        mapName = ""
    }
    
    var body : some View {
        ZStack {
            BaseNavigationView()
                // Toolbar buttons
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ExitButton(mapName: mapName)
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

struct NavigateMapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigateMapView()
    }
}
