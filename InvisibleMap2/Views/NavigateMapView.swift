//
//  NavigateMapView.swift
//  InvisibleMap2
//
//  Created by tad on 11/12/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI
import FirebaseAuth

struct ExitButton: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>

    var body: some View {
        Button(action: {
            self.mode.wrappedValue.dismiss()
            InvisibleMapController.shared.process(event: .LeaveMapRequested)
        }){
            Image(systemName: "xmark")
                .accessibility(label: Text("Exit Navigation"))
        }
        .buttonStyle(RectangleButtonStyle())
    }
}

// Provides persistent storage for on-screen instructions and state variables outside of the view struct
class NavigateGlobalState: ObservableObject {
    init() {
    }
}

struct NavigateMapView: View {
    @StateObject var navigateGlobalState = NavigateGlobalState()
    
    init() {
        print("currentUser is \(Auth.auth().currentUser!.uid)")
    }
    
    var body : some View {
        ZStack {
            BaseNavigationView()
                // Toolbar buttons
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ExitButton()
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
